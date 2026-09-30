package reels.spine;

import openfl.display.Sprite;
import reels.config.CellTypes.ReelCellQuad;
import reels.spine.SpineTypes.SpineAnimRole;
import reels.spine.SpineTypes.SpineReelSymbolOptions;
import reels.spine.SpineTypes.SpineSymbolSource;
import reels.spine.SpineTypes.SymbolAnimOverrides;
import reels.symbols.AffineCellFit;
import reels.symbols.OpenFlSymbolView;
import reels.symbols.ReelSymbol;

/**
 * ReelSymbol adapter over an injected Spine runtime (consumer supplies
 * ISpineFactory). Core haxe-reels never depends on a Spine library.
 *
 * Vocabulary (ADR 011): idle / landing / win / disintegration / blur.
 * Missing animations are silent no-ops.
 *
 * On {@code curveMode('symbol')}, uses affine contain-fit (nested `_fit`
 * under reel-positioned `_slot`) — Spine cannot draw a real keystone without
 * render-to-texture. Under {@code curveMode('warp')} the reel mesh warps the
 * whole strip; per-symbol quads are skipped by the engine.
 *
 * ```haxe
 * r.register("WILD", function() return new SpineReelSymbol({
 *   factory: myOpenFlSpineFactory,
 *   spineMap: ["WILD" => { skeleton: "wild", atlas: "wild" }],
 * }));
 * ```
 */
class SpineReelSymbol extends ReelSymbol {
	/** Reel positions this sprite (slot). */
	var _slot:Sprite = new Sprite();
	/** Affine curve fit layer — never move `_slot` from applyCellQuad. */
	var _fit:Sprite = new Sprite();
	var _factory:ISpineFactory;
	var _spineMap:Map<String, SpineSymbolSource>;
	var _defaults:{idle:String, win:String, landing:String, out:String, blur:String};
	var _overrides:SymbolAnimOverrides;
	var _scale:Float;
	var _spines:Map<String, ISpineInstance> = new Map();
	var _current:Null<ISpineInstance> = null;
	var _oneShotComplete:Null<() -> Void> = null;
	var _completeListener:Null<Int->Void> = null;

	public function new(options:SpineReelSymbolOptions) {
		_slot.addChild(_fit);
		super(new OpenFlSymbolView(_slot));
		_factory = options.factory;
		_spineMap = options.spineMap;
		_defaults = {
			idle: options.idleAnimation != null ? options.idleAnimation : "idle",
			win: options.winAnimation != null ? options.winAnimation : "win",
			landing: options.landingAnimation != null ? options.landingAnimation : "landing",
			out: options.outAnimation != null ? options.outAnimation : "disintegration",
			blur: options.blurAnimation != null ? options.blurAnimation : "blur"
		};
		_overrides = options.animations != null ? options.animations : new Map();
		_scale = options.scale != null ? options.scale : 1.;
	}

	/** Underlying instance for the active symbolId (advanced / reactions). */
	public var spine(get, never):Null<ISpineInstance>;

	function get_spine():Null<ISpineInstance> {
		return _current;
	}

	/** Affine fit layer scale (tests / diagnostics). */
	public var curveFitScale(get, never):Float;

	function get_curveFitScale():Float {
		return _fit.scaleX;
	}

	function animNameFor(role:SpineAnimRole):String {
		var per = _overrides.get(symbolId);
		if (per != null) {
			var over = per.get(role);
			if (over != null) return over;
		}
		return switch (role) {
			case Idle: _defaults.idle;
			case Landing: _defaults.landing;
			case Win: _defaults.win;
			case Out: _defaults.out;
			case Blur: _defaults.blur;
		};
	}

	override function onActivate(symbolId:String):Void {
		if (_current != null) _current.setVisible(false);

		var inst = _spines.get(symbolId);
		if (inst == null) {
			var cfg = _spineMap.get(symbolId);
			if (cfg == null) return;
			inst = _factory.create(cfg);
			if (cfg.skin != null) inst.setSkinByName(cfg.skin);
			inst.setScale(_scale);
			_fit.addChild(inst.displayObject);
			_spines.set(symbolId, inst);
		}

		positionSpine(inst);
		inst.setVisible(true);
		_current = inst;
		resolveOneShot();

		var idleName = animNameFor(Idle);
		if (inst.hasAnimation(idleName)) {
			inst.setAnimation(0, idleName, true);
		}
		inst.update(0);
	}

	override function onDeactivate():Void {
		if (_current != null) {
			_current.clearTracks();
			detachCompleteListener(_current);
			_current.setToSetupPose();
			_current.setVisible(false);
			_current = null;
		}
		resolveOneShot();
		AffineCellFit.clear(_fit);
	}

	override function onResize(width:Float, height:Float):Void {
		for (inst in _spines) positionSpine(inst);
	}

	override public function applyCellQuad(quad:Null<ReelCellQuad>):Void {
		if (quad == null) {
			AffineCellFit.clear(_fit);
			return;
		}
		AffineCellFit.apply(_fit, quad, _cellWidth, _cellHeight);
	}

	function positionSpine(inst:ISpineInstance):Void {
		inst.setPosition(_cellWidth * 0.5, _cellHeight * 0.5);
	}

	override public function playWin(onComplete:() -> Void):Void {
		playOneShot(animNameFor(Win), 0, true, onComplete);
	}

	/** Landing one-shot — wire from spin:reelLanded if desired. */
	public function playLanding(onComplete:() -> Void):Void {
		playOneShot(animNameFor(Landing), 0, true, onComplete);
	}

	/** Exit / disintegrate one-shot (cascade pop). */
	public function playOut(onComplete:() -> Void):Void {
		playOneShot(animNameFor(Out), 0, false, onComplete);
	}

	/**
	 * Prefer disintegration when present; otherwise alpha tween fallback.
	 */
	override public function playDestroy(
		?opts:{?delay:Float, ?duration:Float},
		onComplete:() -> Void,
		?tweens:reels.tween.TweenDriver
	):Void {
		var outName = animNameFor(Out);
		if (_current != null && _current.hasAnimation(outName)) {
			var delay = opts != null && opts.delay != null ? opts.delay : 0.;
			function go():Void {
				playOut(function() {
					snapDestroyed();
					onComplete();
				});
			}
			if (delay <= 0 || tweens == null) {
				go();
			} else {
				tweens.to(
					function() return 0.,
					function(_) {},
					1,
					delay,
					reels.tween.Easing.linear,
					go
				);
			}
			return;
		}
		super.playDestroy(opts, onComplete, tweens);
	}

	/** Loop blur on track 0 (fast spin). Missing anim = no-op. */
	public function playBlur():Void {
		if (_current == null) return;
		var name = animNameFor(Blur);
		if (!_current.hasAnimation(name)) return;
		resolveOneShot();
		_current.setAnimation(0, name, true);
	}

	/** Non-blocking arbitrary track. Missing anim = no-op. */
	public function playOnTrack(track:Int, animName:String, loop:Bool = false):Void {
		if (_current == null) return;
		if (!_current.hasAnimation(animName)) return;
		_current.setAnimation(track, animName, loop);
	}

	override public function stopAnimation():Void {
		if (_current == null) return;
		resolveOneShot();
		var idleName = animNameFor(Idle);
		if (_current.hasAnimation(idleName)) {
			_current.setAnimation(0, idleName, true);
		}
	}

	function playOneShot(
		animName:String,
		track:Int,
		returnToIdle:Bool,
		onComplete:() -> Void
	):Void {
		if (_current == null || !_current.hasAnimation(animName)) {
			onComplete();
			return;
		}
		var spine = _current;
		resolveOneShot();
		_oneShotComplete = onComplete;

		var listener:Int->Void = null;
		listener = function(doneTrack:Int) {
			if (doneTrack != track) return;
			detachCompleteListener(spine);
			_completeListener = null;
			if (returnToIdle) {
				var idleName = animNameFor(Idle);
				if (spine.hasAnimation(idleName)) {
					spine.setAnimation(track, idleName, true);
				}
			}
			if (_oneShotComplete != null) {
				var fn = _oneShotComplete;
				_oneShotComplete = null;
				fn();
			}
		};
		_completeListener = listener;
		spine.addCompleteListener(listener);
		spine.setAnimation(track, animName, false);
		// Flush mock (and apply real pose) so FakeClock tests settle sync.
		spine.update(0);
	}

	function resolveOneShot():Void {
		if (_current != null) detachCompleteListener(_current);
		_completeListener = null;
		if (_oneShotComplete != null) {
			var fn = _oneShotComplete;
			_oneShotComplete = null;
			fn();
		}
	}

	function detachCompleteListener(inst:ISpineInstance):Void {
		if (_completeListener != null) {
			inst.removeCompleteListener(_completeListener);
		}
	}

	override function onDestroy():Void {
		resolveOneShot();
		for (inst in _spines) {
			if (inst.displayObject.parent != null) {
				inst.displayObject.parent.removeChild(inst.displayObject);
			}
			inst.destroy();
		}
		_spines.clear();
		_current = null;
		AffineCellFit.clear(_fit);
		_fit.removeChildren();
		_slot.removeChildren();
	}
}
