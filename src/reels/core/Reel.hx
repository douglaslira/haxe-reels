package reels.core;

import openfl.display.Sprite;
import reels.events.EventEmitter;
import reels.frame.ColumnTarget;
import reels.frame.ColumnTargets;
import reels.frame.FrameBuilder;
import reels.symbols.BigSymbolCoord;
import reels.symbols.OccupiedStub;
import reels.symbols.ReelSymbol;
import reels.symbols.SymbolFactory;
import reels.tween.TweenDriver;
import reels.util.IDisposable;

/**
 * One strip of symbols. Owns motion, strip placement, and display host.
 */
class Reel implements IDisposable {
	public final index:Int;
	public final events:EventEmitter = new EventEmitter();
	public final host:Sprite = new Sprite();

	var _cfg:ReelConfig;
	var _factory:SymbolFactory;
	var _frame:FrameBuilder;
	var _symbols:Array<ReelSymbol> = [];
	var _motion:ReelMotion;
	var _axis:ReelAxis;
	var _destroyed:Bool = false;
	var _pendingTarget:Null<ColumnTarget>;
	var _stopQueue:StopFrameQueue = new StopFrameQueue();
	var _isStopping:Bool = false;
	var _curve:Null<ReelCurve> = null;
	var _warping:Bool = false;
	var _warp:Null<ReelWarp> = null;
	var _curveBleed:Float = 0;
	/**
	 * Resting host main (layout / mainOffset). Start/Stop bounce tugs
	 * `host` away from this — sticky pin overlays must stay on rest so
	 * bottom-cell pins do not leak past the unmasked layer during bounce.
	 */
	var _restHostMain:Float = 0;
	var _isNudging:Bool = false;
	var _nudgeQueue:Null<Array<String>> = null;
	var _nudgeTween:Null<reels.tween.TweenHandle> = null;
	var _nudgeTweens:TweenDriver = null;
	var _nudgeFinalize:Null<() -> Void> = null;
	var _nudgeAbortUnsub:Null<() -> Void> = null;
	var _nudgeOnComplete:Null<(symbols:Array<String>) -> Void> = null;
	var _nudgeOnCancelled:Null<(reason:String) -> Void> = null;
	/** Visible-cell → anchor cell within this reel (big symbols). */
	var _anchorOfCell:Array<Int> = [];

	public function new(cfg:ReelConfig, factory:SymbolFactory, frame:FrameBuilder) {
		_cfg = cfg;
		index = cfg.index;
		_factory = factory;
		_frame = frame;
		_axis = cfg.axis;
		_curveBleed = cfg.curveBleed != null && cfg.curveBleed > 0 ? cfg.curveBleed : 0;

		var strip = _frame.buildRandom();
		rebuildStrip(strip);

		var cellMain = _axis.orientation == Vertical ? cfg.symbolHeight : cfg.symbolWidth;
		var mainGap = _axis.orientation == Vertical ? cfg.symbolGapY : cfg.symbolGapX;
		_motion = new ReelMotion(
			_symbols,
			cellMain,
			mainGap,
			cfg.bufferStart,
			cfg.visibleCells,
			cfg.bufferEnd,
			recycleWrapped,
			cfg.axis
		);
		_curve = buildCurve(cfg.curve);
		// Warp bends the whole strip once — motion must NOT also hand each
		// symbol a quad (would curve twice / shrink into the texture).
		_warping = cfg.warping == true && _curve != null;
		if (_curve != null && !_warping) _motion.setCurve(_curve);
		if (_warping) ensureWarp();
	}

	function buildCurve(input:Null<ReelCurveInput>):Null<ReelCurve> {
		if (input == null) return null;
		var curve = new ReelCurve(ReelCurve.resolveCurveConfig(input), _axis);
		if (curve.isFlat) return null;
		var cellMain = _axis.orientation == Vertical ? _cfg.symbolHeight : _cfg.symbolWidth;
		var cellCross = _axis.orientation == Vertical ? _cfg.symbolWidth : _cfg.symbolHeight;
		var mainGap = _axis.orientation == Vertical ? _cfg.symbolGapY : _cfg.symbolGapX;
		curve.setGeometry(cellMain, cellCross, cellMain + mainGap, _cfg.visibleCells);
		if (_cfg.curveFocusCross != null) {
			curve.setFocus(_cfg.curveFocusCross);
		}
		return curve;
	}

	public var curve(get, never):Null<ReelCurve>;

	function get_curve():Null<ReelCurve> {
		return _curve;
	}

	/** Re-curve at runtime (same as builder.curve). null / 0 flattens. */
	public function setCurve(input:Null<ReelCurveInput>):Void {
		_curve = buildCurve(input);
		if (_warping) {
			_motion.setCurve(null);
			if (_curve != null) {
				ensureWarp();
				if (_warp != null) _warp.setCurve(_curve);
			}
		} else {
			_motion.setCurve(_curve);
		}
	}

	/**
	 * Toggle per-symbol curve drawing. Prefer leaving this on during tumble —
	 * `setVisibleMain` re-projects as cells move. Callers may still force
	 * false for a local effect, then restore true on settle / slam.
	 * No-op under `curveMode('warp')` — the drum mesh always bends.
	 */
	public function setCurveVisuals(on:Bool):Void {
		if (_warping) return;
		_motion.setCurveProjection(on);
	}

	/**
	 * Whether curve drawing is active (symbol quads, or warp drum).
	 * False = flat cells in symbol mode.
	 */
	public var curveVisuals(get, never):Bool;

	function get_curveVisuals():Bool {
		if (_warping) return _warp != null;
		return _motion.curveProjection;
	}

	/** True when this reel was built with `curveMode('warp')` and a non-flat curve. */
	public var warping(get, never):Bool;

	function get_warping():Bool {
		return _warping;
	}

	public var warp(get, never):Null<ReelWarp>;

	function get_warp():Null<ReelWarp> {
		return _warp;
	}

	public var curveBleed(get, never):Float;

	function get_curveBleed():Float {
		return _curveBleed;
	}

	/** Redraw warp texture (no-op when not warping). */
	public function updateWarp():Void {
		if (_warp == null) return;
		// Bounce/tug on host rides inside the texture; mesh stays at rest.
		_warp.update(getHostMain() - _restHostMain);
	}

	/**
	 * Match warp view to resting layout (cross + rest main).
	 * Bounce must NOT move the mesh — it is baked into the capture instead.
	 */
	public function syncWarpViewPosition():Void {
		if (_warp == null) return;
		if (_axis.mainProp == "y") {
			_warp.view.x = host.x;
			_warp.view.y = _restHostMain;
		} else {
			_warp.view.y = host.y;
			_warp.view.x = _restHostMain;
		}
	}

	function windowScreenSize():{width:Float, height:Float} {
		var cellMain = _axis.orientation == Vertical ? _cfg.symbolHeight : _cfg.symbolWidth;
		var cellCross = _axis.orientation == Vertical ? _cfg.symbolWidth : _cfg.symbolHeight;
		var mainGap = _axis.orientation == Vertical ? _cfg.symbolGapY : _cfg.symbolGapX;
		var mainExtent = _cfg.visibleCells * (cellMain + mainGap) - mainGap;
		var screen = _axis.toScreen(cellCross, mainExtent);
		return {width: Math.abs(screen.x), height: Math.abs(screen.y)};
	}

	function ensureWarp():Void {
		if (!_warping || _curve == null) return;
		var box = windowScreenSize();
		if (_warp == null) {
			_warp = new ReelWarp(
				host,
				_curve,
				_axis,
				box.width,
				box.height,
				_motion.slotPitch,
				_curveBleed
			);
		} else {
			_warp.setCurve(_curve);
			_warp.resize(box.width, box.height);
		}
	}

	public var isStopping(get, set):Bool;

	function get_isStopping():Bool {
		return _isStopping;
	}

	function set_isStopping(v:Bool):Bool {
		_isStopping = v;
		if (!v) _stopQueue.reset();
		return v;
	}

	public var stopQueueHasRemaining(get, never):Bool;

	function get_stopQueueHasRemaining():Bool {
		return _stopQueue.hasRemaining;
	}

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	public var isDestroyed(get, never):Bool;

	public var slotPitch(get, never):Float;

	function get_slotPitch():Float {
		return _motion.slotPitch;
	}

	public var visibleCells(get, never):Int;

	function get_visibleCells():Int {
		return _cfg.visibleCells;
	}

	public var symbolWidth(get, never):Float;

	function get_symbolWidth():Float {
		return _cfg.symbolWidth;
	}

	public var symbolHeight(get, never):Float;

	function get_symbolHeight():Float {
		return _cfg.symbolHeight;
	}

	public var bufferStart(get, never):Int;

	function get_bufferStart():Int {
		return _cfg.bufferStart;
	}

	public var bufferEnd(get, never):Int;

	function get_bufferEnd():Int {
		return _cfg.bufferEnd;
	}

	public function advance(delta:Float):Void {
		_motion.advance(delta);
	}

	public var isNudging(get, never):Bool;

	function get_isNudging():Bool {
		return _isNudging;
	}

	public var stripLength(get, never):Int;

	function get_stripLength():Int {
		return _symbols.length;
	}

	/**
	 * Shift the strip by `distance` positions while at rest. Callback style
	 * (pixi returns a Promise). See {@link reels.config.NudgeOptions}.
	 */
	public function nudge(
		options:reels.config.NudgeOptions,
		tweens:TweenDriver,
		?onPrepared:() -> Void,
		?onComplete:(symbols:Array<String>) -> Void,
		?onCancelled:(reason:String) -> Void
	):Void {
		if (_destroyed) throw "nudge: reel has been destroyed.";
		if (_isStopping || _isNudging) {
			throw 'nudge: cannot nudge a reel in motion (isStopping=$_isStopping, isNudging=$_isNudging).';
		}
		if (options == null) throw "nudge: options required";
		var distance = options.distance;
		if (distance < 1) throw 'nudge: distance must be a positive integer, got $distance.';
		var total = _symbols.length;
		if (distance >= total) {
			throw 'nudge: distance $distance must be strictly less than total strip capacity ($total).';
		}
		var direction = options.direction;
		if (direction != "forward" && direction != "reverse") {
			throw 'nudge: direction must be \'forward\' or \'reverse\', got $direction.';
		}
		var incoming = options.incoming;
		if (incoming == null || incoming.length != distance) {
			throw 'nudge: incoming must be an array of exactly $distance symbol id(s), got length '
				+ (incoming == null ? "null" : Std.string(incoming.length)) + ".";
		}
		for (id in incoming) {
			if (!_factory.has(id)) {
				throw 'nudge: incoming symbol \'$id\' is not registered. Register it via builder.symbols(...).';
			}
			var incSize = _factory.getSize(id);
			if (BigSymbolCoord.isBig(incSize)) {
				throw 'nudge: incoming symbol \'$id\' is a big symbol (${incSize.reels}x${incSize.cells}). '
					+ "Big symbols are not supported as incoming items.";
			}
		}

		var travelSign = direction == "forward" ? 1. : -1.;
		var wrapsIntoStart = travelSign * _axis.polarity > 0;

		// Pre-existing big blocks must survive the rotation (1×H only; w>1 forbidden).
		for (i in 0...total) {
			var sym = _symbols[i];
			if (Std.isOfType(sym, OccupiedStub)) continue;
			var meta = _factory.getSize(sym.symbolId);
			if (!BigSymbolCoord.isBig(meta)) continue;
			if (meta.reels > 1) {
				throw 'nudge: reel $index carries cross-reel big symbol \'${sym.symbolId}\' '
					+ '(${meta.reels}x${meta.cells}) at strip[$i]. Cross-reel blocks can\'t be nudged.';
			}
			if (meta.cells > 1) {
				var survives = wrapsIntoStart
					? i + meta.cells - 1 + distance < total
					: i - distance >= 0;
				if (!survives) {
					throw 'nudge: block \'${sym.symbolId}\' (1x${meta.cells}) at strip[$i] '
						+ 'wouldn\'t survive a distance=$distance $direction nudge.';
				}
			}
		}

		var abort = options.abort;
		if (abort != null && abort.aborted) {
			if (_nudgeOnCancelled != null) _nudgeOnCancelled("nudge: aborted before start.");
			else if (onCancelled != null) onCancelled("nudge: aborted before start.");
			return;
		}

		var startDelay = options.startDelay != null ? options.startDelay : 0.;
		var duration = options.duration != null ? options.duration : 200. * distance;
		var easeName = options.ease != null ? options.ease : "power2.out";
		var easeFn = reels.tween.Easing.resolve(easeName);
		_nudgeTweens = tweens;
		_nudgeOnComplete = onComplete;
		_nudgeOnCancelled = onCancelled;

		function isProtectedSlot(stripIdx:Int):Bool {
			var s = _symbols[stripIdx];
			if (Std.isOfType(s, OccupiedStub)) return true;
			return BigSymbolCoord.isBig(_factory.getSize(s.symbolId));
		}

		function beginMotion():Void {
			if (_destroyed) {
				if (_nudgeOnCancelled != null) _nudgeOnCancelled("nudge: reel destroyed during startDelay.");
				return;
			}
			if (abort != null && abort.aborted) {
				if (_nudgeOnCancelled != null) _nudgeOnCancelled("nudge: aborted during startDelay.");
				return;
			}

			var bufferStart = _cfg.bufferStart;
			var bufferEnd = _cfg.bufferEnd;
			if (wrapsIntoStart) {
				var bufferSet = distance < bufferStart ? distance : bufferStart;
				for (i in 0...bufferSet) {
					var stripIdx = bufferStart - bufferSet + i;
					var incIdx = distance - bufferSet + i;
					if (!isProtectedSlot(stripIdx)) replaceStripAt(stripIdx, incoming[incIdx]);
				}
				var queue:Array<String> = [];
				var wrapsToVisible = distance - bufferStart;
				for (k in 1...(distance + 1)) {
					if (k <= wrapsToVisible) {
						queue.push(incoming[wrapsToVisible - k]);
					} else {
						queue.push(_frame.nextRandom());
					}
				}
				_nudgeQueue = queue;
			} else {
				var bufferSet = distance < bufferEnd ? distance : bufferEnd;
				for (i in 0...bufferSet) {
					var stripIdx = bufferStart + _cfg.visibleCells + i;
					if (!isProtectedSlot(stripIdx)) replaceStripAt(stripIdx, incoming[i]);
				}
				var queue:Array<String> = [];
				var wrapsToVisible = distance - bufferEnd;
				for (k in 1...(distance + 1)) {
					if (k <= wrapsToVisible) {
						queue.push(incoming[bufferEnd + k - 1]);
					} else {
						queue.push(_frame.nextRandom());
					}
				}
				_nudgeQueue = queue;
			}

			_motion.snapToGrid();
			_isNudging = true;
			events.emit("phase:enter", ["nudge"]);
			if (onPrepared != null) onPrepared();

			var slotH = _motion.slotPitch;
			var totalDelta = travelSign * distance * slotH;
			var stepLimit = slotH * 0.45;
			var lastDisplaced = 0.;
			var stateP = 0.;
			var completedNormally = false;

			function finalize(cancelled:Bool, reason:String):Void {
				if (!_isNudging && _nudgeFinalize == null) return;
				var remainingQueue = _nudgeQueue != null ? _nudgeQueue.length : 0;
				if (remainingQueue > 0) {
					var stepDir = travelSign * stepLimit;
					var i = 0;
					while (i < remainingQueue * 3 && _nudgeQueue != null && _nudgeQueue.length > 0) {
						_motion.advance(stepDir);
						i++;
					}
				}
				_motion.snapToGrid();
				_isNudging = false;
				_nudgeQueue = null;
				if (_nudgeTween != null && _nudgeTweens != null) {
					_nudgeTweens.kill(_nudgeTween);
				}
				_nudgeTween = null;
				_nudgeFinalize = null;
				events.emit("phase:exit", ["nudge"]);
				var done = _nudgeOnComplete;
				var cancel = _nudgeOnCancelled;
				_nudgeOnComplete = null;
				_nudgeOnCancelled = null;
				if (cancelled) {
					if (cancel != null) cancel(reason);
				} else if (done != null) {
					done(getVisibleIds());
				}
			}
			_nudgeFinalize = function() finalize(false, "");

			if (abort != null) {
				abort.onAbort(function() {
					if (!_isNudging) return;
					finalize(true, "nudge: aborted.");
				});
			}

			_nudgeTween = tweens.to(
				function() return stateP,
				function(p) {
					stateP = p;
					var eased = p * totalDelta;
					var target = totalDelta > 0
						? (eased < totalDelta ? eased : totalDelta)
						: (eased > totalDelta ? eased : totalDelta);
					var remaining = target - lastDisplaced;
					while (Math.abs(remaining) > stepLimit) {
						var step = remaining > 0 ? stepLimit : -stepLimit;
						_motion.advance(step);
						remaining -= step;
					}
					if (remaining != 0) _motion.advance(remaining);
					lastDisplaced = target;
				},
				1,
				duration,
				easeFn,
				function() {
					completedNormally = true;
					finalize(false, "");
				}
			);
		}

		if (startDelay > 0) {
			var delayP = 0.;
			tweens.to(
				function() return delayP,
				function(v) delayP = v,
				1,
				startDelay,
				reels.tween.Easing.linear,
				beginMotion
			);
		} else {
			beginMotion();
		}
	}

	/** Fast-forward an in-flight nudge to its landed state. */
	public function skipNudge():Void {
		if (!_isNudging) return;
		if (_nudgeFinalize != null) {
			var fin = _nudgeFinalize;
			_nudgeFinalize = null;
			fin();
		}
	}

	function replaceStripAt(index:Int, symbolId:String):Void {
		if (index < 0 || index >= _symbols.length) return;
		var cur = _symbols[index];
		if (cur.symbolId == symbolId) {
			cur.applyCellQuad(null);
			adoptSymbolSize(cur);
			return;
		}
		var main = _axis.getMain(cur.view);
		detach(cur);
		releaseStripSymbol(cur);
		var fresh = acquireStripSymbol(symbolId);
		adoptSymbolSize(fresh);
		_symbols[index] = fresh;
		attachAt(fresh, index);
		_axis.setMain(fresh.view, main);
		refreshDisplayOrder();
		rebuildAnchors();
	}

	/** Reel-strip host main coordinate (used for bounce / start tug). */
	public function getHostMain():Float {
		return _axis.mainProp == "y" ? host.y : host.x;
	}

	public function setHostMain(v:Float):Void {
		// Warp mesh stays at restHostMain — bounce is captured into the texture.
		if (_axis.mainProp == "y") host.y = v;
		else host.x = v;
	}

	/**
	 * Resting host main used by sticky pin overlays (ignores bounce/tug).
	 * Call `captureRestHostMain()` after layout or permanent host moves.
	 */
	public var restHostMain(get, never):Float;

	function get_restHostMain():Float {
		return _restHostMain;
	}

	public function captureRestHostMain():Void {
		_restHostMain = getHostMain();
	}

	public function snapToGrid():Void {
		_motion.snapToGrid();
	}

	/**
	 * MultiWays reshape: change visible cell count and cell main size.
	 * Grows/shrinks the strip; snaps to grid. Caller owns viewport sizing.
	 */
	public function reshape(
		newVisibleCells:Int,
		newCellMain:Float,
		bufferStart:Int,
		bufferEnd:Int
	):Void {
		if (newVisibleCells < 1) throw "Reel.reshape: newVisibleCells must be >= 1";
		if (newCellMain <= 0) throw "Reel.reshape: newCellMain must be > 0";

		var vertical = _axis.orientation == Vertical;
		var oldVisible = _cfg.visibleCells;
		var oldMain = vertical ? _cfg.symbolHeight : _cfg.symbolWidth;
		if (
			newVisibleCells == oldVisible
			&& Math.abs(newCellMain - oldMain) < 1e-9
			&& bufferStart == _cfg.bufferStart
			&& bufferEnd == _cfg.bufferEnd
		) {
			return;
		}

		_cfg.visibleCells = newVisibleCells;
		_cfg.bufferStart = bufferStart;
		_cfg.bufferEnd = bufferEnd;
		if (vertical) _cfg.symbolHeight = newCellMain;
		else _cfg.symbolWidth = newCellMain;

		_frame.setVisibleCells(newVisibleCells);
		// FrameBuilder buffers are fixed at construction; keep cfg in sync for strip len.
		var targetLen = bufferStart + newVisibleCells + bufferEnd;
		while (_symbols.length > targetLen) {
			var extra = _symbols.pop();
			detach(extra);
			releaseStripSymbol(extra);
		}
		while (_symbols.length < targetLen) {
			var id = _frame.buildRandom()[0];
			var s = acquireStripSymbol(id);
			adoptSymbolSize(s);
			var i = _symbols.length;
			_symbols.push(s);
			attachAt(s, i);
		}

		var cellCross = vertical ? _cfg.symbolWidth : _cfg.symbolHeight;
		var mainGap = vertical ? _cfg.symbolGapY : _cfg.symbolGapX;
		for (s in _symbols) {
			adoptSymbolSize(s);
		}

		_motion.reshape(newCellMain, mainGap, bufferStart);
		if (_curve != null) {
			_curve.setGeometry(newCellMain, cellCross, newCellMain + mainGap, newVisibleCells);
			if (_cfg.curveFocusCross != null) {
				_curve.setFocus(_cfg.curveFocusCross);
			}
		}
		_motion.snapToGrid();
		_motion.refreshPositions();
		refreshDisplayOrder();
		if (_warping) ensureWarp();
	}

	public function beginBlur():Void {}

	public function endBlur():Void {}

	public function setPendingResult(target:ColumnTarget):Void {
		_pendingTarget = ColumnTargets.cloneColumnTarget(target);
	}

	/**
	 * Load pending target into the stop-frame queue. Symbols scroll in via
	 * wraps during StopPhase — no instant strip swap (matches pixi-reels).
	 */
	public function armStopFromPending():Void {
		if (_pendingTarget == null) return;
		var strip = _frame.buildFromTarget(_pendingTarget);
		_stopQueue.setFrame(strip, _axis.feedEdge);
		_isStopping = true;
	}

	/** Instant place for slam / skip. Clears stop queue. */
	public function forceResult(target:ColumnTarget):Void {
		_isStopping = false;
		_stopQueue.reset();
		_pendingTarget = ColumnTargets.cloneColumnTarget(target);
		var strip = _frame.buildFromTarget(_pendingTarget);
		_pendingTarget = null;
		replaceStripInPlace(strip);
		_motion.snapToGrid();
	}

	/** Slam from whatever is still pending (StopPhase skip / abort). */
	public function forcePendingResult():Void {
		if (_pendingTarget == null) {
			_isStopping = false;
			_stopQueue.reset();
			_motion.snapToGrid();
			return;
		}
		forceResult(_pendingTarget);
	}

	/** Clear pending after a natural land (queue already emptied via wraps). */
	public function clearPendingResult():Void {
		_pendingTarget = null;
		_isStopping = false;
		_stopQueue.reset();
	}

	public function getSubSlotOffset():Float {
		return _motion.subSlotOffset;
	}

	public function axisPolarity():Int {
		return _axis.polarity;
	}

	public var axis(get, never):ReelAxis;

	function get_axis():ReelAxis {
		return _axis;
	}

	public function getVisibleSymbol(cell:Int):ReelSymbol {
		return _symbols[_cfg.bufferStart + cell];
	}

	/** Pixi alias of getVisibleSymbol. */
	public function getSymbolAt(cell:Int):ReelSymbol {
		return getVisibleSymbol(cell);
	}

	/**
	 * Anchor cell for a visible index (big-symbol blocks). Without big
	 * symbols this is identity — still used by spotlight dedupe.
	 */
	public function getAnchorCell(cell:Int):Int {
		if (cell < 0 || cell >= _cfg.visibleCells) return cell;
		var stripIdx = _cfg.bufferStart + cell;
		var j = stripIdx;
		while (j > 0 && _symbols[j].symbolId == OccupiedStub.SENTINEL) j--;
		var vis = j - _cfg.bufferStart;
		return vis < 0 ? 0 : vis;
	}

	/** Random symbol id from this reel's frame weights (movePin backfill). */
	public function randomFillerId():String {
		return _frame.nextRandom();
	}

	public function setVisibleMain(cell:Int, main:Float):Void {
		var symbol = _symbols[_cfg.bufferStart + cell];
		_axis.setMain(symbol.view, main);
		// Warp owns the bend — never hand per-symbol quads while warping.
		if (!_warping && _curve != null && _motion.curveProjection) {
			symbol.applyCellQuad(_curve.quadFor(main, symbol.cellInset));
		}
	}

	public function getVisibleMain(cell:Int):Float {
		return _axis.getMain(_symbols[_cfg.bufferStart + cell].view);
	}

	public function setVisibleAlpha(cell:Int, alpha:Float):Void {
		_symbols[_cfg.bufferStart + cell].alpha = alpha;
	}

	public function revealAllVisible():Void {
		for (i in 0..._cfg.visibleCells) {
			_symbols[_cfg.bufferStart + i].alpha = 1;
			_symbols[_cfg.bufferStart + i].visible = true;
		}
	}

	/**
	 * Cascade place: swap identities from target, snap to grid.
	 * @param moverCells if set, those visible indices get alpha 0 (drop-in movers).
	 */
	public function placeVisible(target:ColumnTarget, ?moverCells:Array<Int>):Void {
		_isStopping = false;
		_stopQueue.reset();
		_pendingTarget = null;
		var strip = _frame.buildFromTarget(target);
		replaceStripInPlace(strip);
		_motion.snapToGrid();
		revealAllVisible();
		if (moverCells != null) {
			for (c in moverCells) {
				if (c >= 0 && c < _cfg.visibleCells) {
					_symbols[_cfg.bufferStart + c].alpha = 0;
				}
			}
		}
	}

	public function getVisibleIds():Array<String> {
		var out:Array<String> = [];
		var start = _cfg.bufferStart;
		for (i in 0..._cfg.visibleCells) {
			var s = _symbols[start + i];
			if (s.symbolId == OccupiedStub.SENTINEL) {
				var j = start + i;
				while (j > 0 && _symbols[j].symbolId == OccupiedStub.SENTINEL) j--;
				out.push(_symbols[j].symbolId);
			} else {
				out.push(s.symbolId);
			}
		}
		return out;
	}

	/**
	 * Main-axis positions of visible cells (for tests / debug).
	 * After a correct land+snap these are 0, pitch, 2*pitch, ...
	 */
	public function getVisibleMains():Array<Float> {
		var out:Array<Float> = [];
		var start = _cfg.bufferStart;
		for (i in 0..._cfg.visibleCells) {
			out.push(_axis.getMain(_symbols[start + i].view));
		}
		return out;
	}

	function rebuildStrip(ids:Array<String>):Void {
		clearSymbols();
		for (i in 0...ids.length) {
			var s = acquireStripSymbol(ids[i]);
			adoptSymbolSize(s);
			attachAt(s, i);
			_symbols.push(s);
		}
		refreshDisplayOrder();
		rebuildAnchors();
	}

	/** Factory pools at build-time cell size; MultiWays reshape changes per-reel size. */
	function adoptSymbolSize(s:ReelSymbol):Void {
		if (Std.isOfType(s, OccupiedStub)) {
			s.resize(_cfg.symbolWidth, _cfg.symbolHeight);
			s.visible = false;
			s.alpha = 0;
			return;
		}
		var size = _factory.getSize(s.symbolId);
		var w = size.reels;
		var h = size.cells;
		if (w > 1 || h > 1) {
			// size.reels = CROSS axis, size.cells = MAIN (ADR 016 / pixi parity).
			var vertical = _axis.orientation == Vertical;
			var mainGap = vertical ? _cfg.symbolGapY : _cfg.symbolGapX;
			var crossGap = vertical ? _cfg.symbolGapX : _cfg.symbolGapY;
			var cellMain = vertical ? _cfg.symbolHeight : _cfg.symbolWidth;
			var cellCross = vertical ? _cfg.symbolWidth : _cfg.symbolHeight;
			var blockMain = h * cellMain + (h - 1) * mainGap;
			var blockCross = w * cellCross + (w - 1) * crossGap;
			if (vertical) s.resize(blockCross, blockMain);
			else s.resize(blockMain, blockCross);
			return;
		}
		s.resize(_cfg.symbolWidth, _cfg.symbolHeight);
	}

	function acquireStripSymbol(id:String):ReelSymbol {
		if (id == OccupiedStub.SENTINEL) {
			var stub = new OccupiedStub();
			stub.activate(OccupiedStub.SENTINEL);
			return stub;
		}
		return _factory.acquire(id);
	}

	function releaseStripSymbol(s:ReelSymbol):Void {
		if (Std.isOfType(s, OccupiedStub)) {
			detach(s);
			s.destroy();
			return;
		}
		_factory.release(s);
	}

	function rebuildAnchors():Void {
		_anchorOfCell = [];
		for (i in 0..._cfg.visibleCells) _anchorOfCell.push(i);
		var start = _cfg.bufferStart;
		for (i in 0..._cfg.visibleCells) {
			var id = _symbols[start + i].symbolId;
			if (id == OccupiedStub.SENTINEL) continue;
			var size = _factory.getSize(id);
			if (size.cells <= 1) continue;
			for (dy in 0...size.cells) {
				var c = i + dy;
				if (c < _cfg.visibleCells) _anchorOfCell[c] = i;
			}
		}
	}

	/**
	 * Swap identities without wiping the strip — preserves positions so
	 * arrive can ease instead of popping.
	 */
	function replaceStripInPlace(ids:Array<String>):Void {
		var n = ids.length;
		while (_symbols.length > n) {
			var extra = _symbols.pop();
			detach(extra);
			releaseStripSymbol(extra);
		}
		for (i in 0...n) {
			var id = ids[i];
			if (i < _symbols.length) {
				var cur = _symbols[i];
				if (cur.symbolId == id) {
					cur.applyCellQuad(null);
					adoptSymbolSize(cur);
					continue;
				}
				var main = _axis.getMain(cur.view);
				detach(cur);
				releaseStripSymbol(cur);
				var fresh = acquireStripSymbol(id);
				adoptSymbolSize(fresh);
				_symbols[i] = fresh;
				attachAt(fresh, i);
				_axis.setMain(fresh.view, main);
			} else {
				var s = acquireStripSymbol(id);
				adoptSymbolSize(s);
				attachAt(s, i);
				_symbols.push(s);
				_axis.setMain(s.view, _motion.getCellMain(i));
			}
		}
		refreshDisplayOrder();
		rebuildAnchors();
	}

	/**
	 * Replace one visible cell's symbol without rebuilding the whole strip.
	 * Used by CellPin so MultiWays neighbors keep the correct cell size.
	 */
	public function setVisibleSymbol(cell:Int, symbolId:String):Void {
		if (cell < 0 || cell >= _cfg.visibleCells) {
			throw 'Reel.setVisibleSymbol: cell $cell out of range [0, ${_cfg.visibleCells})';
		}
		var idx = _cfg.bufferStart + cell;
		var cur = _symbols[idx];
		if (cur.symbolId == symbolId) {
			cur.applyCellQuad(null);
			// Pin overlay may have stolen this DO (addChild) or left it
			// deactivated after release — always re-seat on the strip host.
			ensureSymbolOnHost(cur, idx);
			adoptSymbolSize(cur);
			cur.alpha = 1;
			cur.visible = true;
			refreshDisplayOrder();
			_motion.refreshPositions();
			return;
		}
		var main = _axis.getMain(cur.view);
		detach(cur);
		releaseStripSymbol(cur);
		var fresh = acquireStripSymbol(symbolId);
		adoptSymbolSize(fresh);
		_symbols[idx] = fresh;
		attachAt(fresh, idx);
		_axis.setMain(fresh.view, main);
		refreshDisplayOrder();
		_motion.refreshPositions();
		rebuildAnchors();
	}

	/**
	 * After pin-overlay hand-off / MultiWays reshape: every strip symbol must
	 * be on `host`, sized to the current cell, and fully visible.
	 */
	public function repairStripDisplay():Void {
		reseatStripDisplay();
		_motion.snapToGrid();
		revealAllVisible();
	}

	/**
	 * Re-parent + resize strip symbols without snapping. Use on spin land so
	 * sticky MultiWays hand-off does not leave black holes (orphaned DOs) or
	 * pop the settled bounce/stop pose.
	 */
	public function reseatStripDisplay():Void {
		for (i in 0..._symbols.length) {
			var s = _symbols[i];
			ensureSymbolOnHost(s, i);
			adoptSymbolSize(s);
			s.applyCellQuad(null);
			if (Std.isOfType(s, OccupiedStub)) {
				s.alpha = 0;
				s.visible = false;
			} else {
				s.alpha = 1;
				s.visible = true;
			}
		}
		refreshDisplayOrder();
		_motion.refreshPositions();
		rebuildAnchors();
	}

	function ensureSymbolOnHost(s:ReelSymbol, index:Int):Void {
		var d = s.displayObject;
		if (d == null) return;
		if (d.parent != host) {
			var at = index < host.numChildren ? index : host.numChildren;
			host.addChildAt(d, at);
		}
	}

	/**
	 * Symbol scrolled off-strip: release and replace.
	 * During stop, feed from StopFrameQueue; otherwise random filler.
	 */
	function recycleWrapped(symbol:ReelSymbol):Void {
		var idx = _symbols.indexOf(symbol);
		if (idx < 0) return;
		var nextId:String;
		if (_nudgeQueue != null && _nudgeQueue.length > 0) {
			nextId = _nudgeQueue.shift();
		} else if (_isStopping && _stopQueue.hasRemaining) {
			nextId = _stopQueue.next();
		} else {
			nextId = _frame.buildRandom()[0];
		}
		detach(symbol);
		releaseStripSymbol(symbol);
		var fresh = acquireStripSymbol(nextId);
		adoptSymbolSize(fresh);
		_symbols[idx] = fresh;
		attachAt(fresh, idx);
		_axis.setMain(fresh.view, _motion.getCellMain(idx));
		refreshDisplayOrder();
		rebuildAnchors();
	}

	/**
	 * Strip index → display order: low index (top of vertical strip) behind,
	 * high index (bottom) in front — matches pixi-reels cell stacking.
	 */
	function refreshDisplayOrder():Void {
		var n = _symbols.length;
		for (i in 0...n) {
			var d = _symbols[i].displayObject;
			if (d == null) continue;
			// Re-adopt orphans (e.g. stolen by unmasked overlay addChild).
			if (d.parent != host) {
				var at = i < host.numChildren ? i : host.numChildren;
				host.addChildAt(d, at);
			}
			var target = i < host.numChildren ? i : host.numChildren - 1;
			if (target < 0) continue;
			host.setChildIndex(d, target);
		}
	}

	function attachAt(s:ReelSymbol, index:Int):Void {
		var d = s.displayObject;
		if (d == null) return;
		var at = index;
		if (at < 0) at = 0;
		if (at > host.numChildren) at = host.numChildren;
		host.addChildAt(d, at);
	}

	function attach(s:ReelSymbol):Void {
		attachAt(s, host.numChildren);
	}

	function detach(s:ReelSymbol):Void {
		var d = s.displayObject;
		if (d != null && d.parent != null) d.parent.removeChild(d);
	}

	function clearSymbols():Void {
		for (s in _symbols) {
			detach(s);
			releaseStripSymbol(s);
		}
		// Keep the same Array instance — ReelMotion holds this reference.
		// Replacing with `_symbols = []` orphans motion and leaves new
		// views unpositioned (empty holes on the grid after setResult).
		_symbols.resize(0);
	}

	public function destroy():Void {
		if (_destroyed) return;
		if (_isNudging) skipNudge();
		_destroyed = true;
		if (_warp != null) {
			_warp.destroy();
			_warp = null;
		}
		clearSymbols();
		events.removeAllListeners();
		if (host.parent != null) host.parent.removeChild(host);
	}
}
