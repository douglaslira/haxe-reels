package reels.symbols;

import reels.config.CellTypes.ReelCellInset;
import reels.config.CellTypes.ReelCellQuad;
import reels.core.IPositionable;
import reels.util.IDisposable;

/**
 * Abstract reel cell. Subclass for Bitmap / Headless / custom renderers.
 * Pooled aggressively — never assume "I was just created".
 */
class ReelSymbol implements IDisposable implements IPositionable {
	public var view(get, never):IPositionable;

	var _view:ISymbolView;
	var _symbolId:String = "";
	var _destroyed:Bool = false;
	var _mainAxis:String = "y";
	var _cellWidth:Float = 0;
	var _cellHeight:Float = 0;

	public function new(?view:ISymbolView) {
		_view = view != null ? view : new HeadlessView();
	}

	function get_view():IPositionable {
		return _view;
	}

	function get_x():Float {
		return _view.x;
	}

	function set_x(v:Float):Float {
		return _view.x = v;
	}

	function get_y():Float {
		return _view.y;
	}

	function set_y(v:Float):Float {
		return _view.y = v;
	}

	public var x(get, set):Float;
	public var y(get, set):Float;

	public var symbolId(get, never):String;

	function get_symbolId():String {
		return _symbolId;
	}

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	public var isDestroyed(get, never):Bool;

	public var displayObject(get, never):Null<openfl.display.DisplayObject>;

	function get_displayObject():Null<openfl.display.DisplayObject> {
		return _view.getDisplayObject();
	}

	/**
	 * Art rect as fractions of the flat cell, or null for full cell.
	 */
	public var cellInset(get, never):Null<ReelCellInset>;

	function get_cellInset():Null<ReelCellInset> {
		return null;
	}

	/**
	 * Apply a view-local projected quad, or null to flatten.
	 * Do NOT move view.x/y — Reel recovers slot index from position.
	 * Default no-op (headless). BitmapReelSymbol draws a keystone mesh.
	 */
	public function applyCellQuad(quad:Null<ReelCellQuad>):Void {}

	public function bindMainAxis(prop:String):Void {
		_mainAxis = prop;
	}

	public function activate(symbolId:String):Void {
		_symbolId = symbolId;
		_view.visible = true;
		_view.alpha = 1;
		// Pin overlays bake absolute viewport coords into x/y; pooled reuse on
		// the strip must not keep host.x as a local offset (invisible cells).
		_view.x = 0;
		_view.y = 0;
		onActivate(symbolId);
	}

	public function deactivate():Void {
		stopAnimation();
		applyCellQuad(null);
		onDeactivate();
		_view.visible = false;
		_view.x = 0;
		_view.y = 0;
		_symbolId = "";
	}

	public function resize(width:Float, height:Float):Void {
		_cellWidth = width;
		_cellHeight = height;
		onResize(width, height);
	}

	public var cellWidth(get, never):Float;
	public var cellHeight(get, never):Float;

	function get_cellWidth():Float {
		return _cellWidth;
	}

	function get_cellHeight():Float {
		return _cellHeight;
	}

	public function playWin(onComplete:() -> Void):Void {
		onComplete();
	}

	/**
	 * Default tumble destroy: alpha → 0 (optional delay/duration via TweenDriver).
	 * Subclasses may override for Spine / custom VFX; must call onComplete.
	 */
	public function playDestroy(
		?opts:{?delay:Float, ?duration:Float},
		onComplete:() -> Void,
		?tweens:reels.tween.TweenDriver
	):Void {
		var delay = opts != null && opts.delay != null ? opts.delay : 0.;
		var duration = opts != null && opts.duration != null ? opts.duration : 200.;
		if (tweens == null || (delay <= 0 && duration <= 0)) {
			snapDestroyed();
			onComplete();
			return;
		}
		function collapse():Void {
			if (duration <= 0) {
				snapDestroyed();
				onComplete();
				return;
			}
			tweens.to(function() return alpha, function(v) alpha = v, 0, duration, reels.tween.Easing.quadIn, function() {
				snapDestroyed();
				onComplete();
			});
		}
		if (delay <= 0) {
			collapse();
		} else {
			tweens.to(function() return 0., function(_) {}, 1, delay, reels.tween.Easing.linear, collapse);
		}
	}

	/** Instant destroyed pose (alpha 0). Pool reuse restores via activate(). */
	public function snapDestroyed():Void {
		_view.alpha = 0;
	}

	public function stopAnimation():Void {}

	public var alpha(get, set):Float;

	function get_alpha():Float {
		return _view.alpha;
	}

	function set_alpha(v:Float):Float {
		return _view.alpha = v;
	}

	public var visible(get, set):Bool;

	function get_visible():Bool {
		return _view.visible;
	}

	function set_visible(v:Bool):Bool {
		return _view.visible = v;
	}

	function onActivate(symbolId:String):Void {}

	function onDeactivate():Void {}

	function onResize(width:Float, height:Float):Void {}

	function onDestroy():Void {}

	public function destroy():Void {
		if (_destroyed) return;
		_destroyed = true;
		deactivate();
		onDestroy();
		_view.destroy();
	}
}
