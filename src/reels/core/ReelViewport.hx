package reels.core;

import openfl.display.Shape;
import openfl.display.Sprite;

/**
 * Viewport host with a hard clip mask for the reel strip area.
 * Shape mask is more reliable than scrollRect for Graphics/WebGL content
 * (scrollRect also shifts the registration point — bad for a centered board).
 *
 * Layering (bottom → top):
 *   - masked content (reel hosts)
 *   - unmasked (pin overlays / flights)
 *   - dim overlay (spotlight)
 *   - spotlight (promoted win symbols)
 *
 * Clip shape comes from a {@link MaskStrategy} (default {@link RectMaskStrategy}).
 */
class ReelViewport {
	public final view:Sprite = new Sprite();
	var _maskHost:Sprite = new Sprite();
	var _content:Sprite = new Sprite();
	var _unmasked:Sprite = new Sprite();
	var _dim:Shape = new Shape();
	var _spotlight:Sprite = new Sprite();
	var _clip:Shape;
	var _maskStrategy:MaskStrategy;
	var _maskRects:Array<ReelMaskRect> = [];
	var _width:Float;
	var _height:Float;
	var _mainInset:Float = 0;
	var _crossBleed:Float = 0;
	var _verticalMain:Bool = true;
	var _dimCount:Int = 0;

	public function new(width:Float, height:Float, ?maskStrategy:MaskStrategy) {
		_width = width;
		_height = height;
		_maskStrategy = maskStrategy != null ? maskStrategy : new RectMaskStrategy();
		_clip = _maskStrategy.build(maskContext());
		view.addChild(_maskHost);
		_maskHost.addChild(_content);
		_maskHost.addChild(_clip);
		_maskHost.mask = _clip;
		view.addChild(_unmasked);
		_dim.visible = false;
		view.addChild(_dim);
		view.addChild(_spotlight);
		applyMask();
		redrawDim();
	}

	public var content(get, never):Sprite;

	function get_content():Sprite {
		return _content;
	}

	/** Sibling above the mask — pin overlays, flights, etc. */
	public var unmasked(get, never):Sprite;

	function get_unmasked():Sprite {
		return _unmasked;
	}

	/** Above dim — SymbolSpotlight promotes winners here. */
	public var spotlight(get, never):Sprite;

	function get_spotlight():Sprite {
		return _spotlight;
	}

	public var mainInset(get, never):Float;

	function get_mainInset():Float {
		return _mainInset;
	}

	public var crossBleed(get, never):Float;

	function get_crossBleed():Float {
		return _crossBleed;
	}

	/** Active mask strategy (for tests / diagnostics). */
	public var maskStrategy(get, never):MaskStrategy;

	function get_maskStrategy():MaskStrategy {
		return _maskStrategy;
	}

	/** Per-reel clip rects (copy). Empty = strategy falls back to bounding box. */
	public var maskRects(get, never):Array<ReelMaskRect>;

	function get_maskRects():Array<ReelMaskRect> {
		return _maskRects.copy();
	}

	/**
	 * Inset the clip on the travel axis so a curved drum's shortfall band
	 * (buffer fill) is masked out. Content stays put — empty bands read as
	 * a natural bezel. `verticalMain` true → inset on Y.
	 */
	public function setMainInset(inset:Float, verticalMain:Bool = true):Void {
		_mainInset = inset > 0 ? inset : 0;
		_verticalMain = verticalMain;
		applyMask();
	}

	/**
	 * Expand the clip on the cross axis so `curveBleed` overhang is visible.
	 * Main axis stays inset — buffer cells remain hidden.
	 */
	public function setCrossBleed(bleed:Float, verticalMain:Bool = true):Void {
		_crossBleed = bleed > 0 ? bleed : 0;
		_verticalMain = verticalMain;
		applyMask();
	}

	/**
	 * Per-reel mask rects for {@link RectMaskStrategy}. Empty = bounding box.
	 * Built once in {@link reels.ReelSetBuilder} (fixed extent; MultiWays reshape
	 * does not rebuild — pixi parity). BoardGrid may leave them empty.
	 */
	public function setMaskRects(rects:Array<ReelMaskRect>):Void {
		_maskRects = rects != null ? rects.copy() : [];
		applyMask();
	}

	public function resize(width:Float, height:Float):Void {
		_width = width;
		_height = height;
		applyMask();
		redrawDim();
	}

	/** Show dim overlay; reference-counted with hideDim. */
	public function showDim(alpha:Float = 0.5):Void {
		_dimCount++;
		_dim.alpha = alpha;
		_dim.visible = true;
	}

	/** Release one dim request; hides only when count hits zero. */
	public function hideDim():Void {
		if (_dimCount > 0) _dimCount--;
		if (_dimCount == 0) _dim.visible = false;
	}

	function applyMask():Void {
		_maskStrategy.update(_clip, maskContext());
	}

	function maskContext():MaskContext {
		return {
			width: _width,
			height: _height,
			rects: _maskRects,
			verticalMain: _verticalMain,
			bleed: _crossBleed,
			mainInset: _mainInset
		};
	}

	function redrawDim():Void {
		_dim.graphics.clear();
		_dim.graphics.beginFill(0x000000, 1);
		_dim.graphics.drawRect(0, 0, _width, _height);
		_dim.graphics.endFill();
	}

	public function destroy():Void {
		_maskHost.mask = null;
		_clip.graphics.clear();
		_dim.graphics.clear();
		_dimCount = 0;
		while (_unmasked.numChildren > 0) {
			_unmasked.removeChildAt(0);
		}
		while (_spotlight.numChildren > 0) {
			_spotlight.removeChildAt(0);
		}
		if (view.parent != null) view.parent.removeChild(view);
	}
}
