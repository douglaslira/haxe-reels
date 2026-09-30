package reels.core;

import reels.symbols.ReelSymbol;

/**
 * Physics of one reel: march symbols along travel axis and wrap.
 * Positions are DERIVED from total travel every frame (ADR 018).
 */
class ReelMotion {
	static inline var EPS:Float = 1e-9;

	var _symbols:Array<ReelSymbol>;
	var _pitch:Float;
	var _bufferStart:Int;
	var _axis:ReelAxis;
	var _travel:Float = 0;
	var _rot:Int = 0;
	var _off:Float = 0;
	var _onSymbolWrapped:ReelSymbol->Void;
	var _curve:Null<ReelCurve> = null;
	var _projectCurve:Bool = true;

	public function new(
		symbols:Array<ReelSymbol>,
		symbolHeight:Float,
		symbolGapY:Float,
		bufferStart:Int,
		_visibleCells:Int,
		_bufferEnd:Int,
		onSymbolWrapped:ReelSymbol->Void,
		?axis:ReelAxis
	) {
		_symbols = symbols;
		_pitch = symbolHeight + symbolGapY;
		_bufferStart = bufferStart;
		_axis = axis != null ? axis : ReelAxis.VERTICAL_FORWARD;
		_onSymbolWrapped = onSymbolWrapped;
		render();
	}

	public var slotPitch(get, never):Float;

	function get_slotPitch():Float {
		return _pitch;
	}

	/**
	 * Move strip by `delta` screen pixels along travel axis.
	 * Positive = toward larger coordinate; polarity maps direction.
	 */
	public function advance(delta:Float):Void {
		if (delta == 0) return;
		_travel += _axis.polarity * delta;

		var q = _travel / _pitch;
		var r = Math.round(q);
		if (Math.abs(q - r) < EPS) q = r;
		var targetRot = Math.floor(q);

		while (_rot < targetRot) {
			_rot++;
			rotateToStart();
		}
		while (_rot > targetRot) {
			_rot--;
			rotateToEnd();
		}

		_off = _travel - targetRot * _pitch;
		if (Math.abs(_off) < EPS) _off = 0;
		render();
	}

	/**
	 * Swap curvature in/out. Flatten symbols when dropping curve so last
	 * quad does not stick on screen.
	 */
	public function setCurve(curve:Null<ReelCurve>):Void {
		if (_curve != null && curve == null) {
			for (s in _symbols) s.applyCellQuad(null);
		}
		_curve = curve;
		render();
	}

	/**
	 * When false, keep curve math but draw flat cells. Prefer leaving this
	 * true during tumble (setVisibleMain re-projects). Used as an escape
	 * hatch / slam restore — not as the default fall/drop-in path.
	 */
	public function setCurveProjection(on:Bool):Void {
		if (_projectCurve == on) {
			if (on) render();
			return;
		}
		_projectCurve = on;
		if (!on) {
			for (s in _symbols) s.applyCellQuad(null);
		} else {
			render();
		}
	}

	public var curveProjection(get, never):Bool;

	function get_curveProjection():Bool {
		return _projectCurve;
	}

	public function snapToGrid():Void {
		_travel = 0;
		_rot = 0;
		_off = 0;
		render();
	}

	/** Sub-slot remainder in travel-axis pixels (0 = on grid). */
	public var subSlotOffset(get, never):Float;

	function get_subSlotOffset():Float {
		return _off;
	}

	/** Re-apply derived positions without resetting travel. */
	public function refreshPositions():Void {
		render();
	}

	public function getCellMain(cell:Int):Float {
		return (cell - _bufferStart) * _pitch;
	}

	public function reshape(symbolHeight:Float, symbolGapY:Float, bufferStart:Int):Void {
		_pitch = symbolHeight + symbolGapY;
		_bufferStart = bufferStart;
	}

	function rotateToStart():Void {
		var s = _symbols.pop();
		_symbols.unshift(s);
		_onSymbolWrapped(s);
	}

	function rotateToEnd():Void {
		var s = _symbols.shift();
		_symbols.push(s);
		_onSymbolWrapped(s);
	}

	function render():Void {
		var off = _off;
		var curve = _curve;
		for (i in 0..._symbols.length) {
			var symbol = _symbols[i];
			var main = (i - _bufferStart) * _pitch + off;
			// Always zero the cross axis — pin overlays may have left a baked
			// absolute host offset on a pooled symbol.
			_axis.setCross(symbol.view, 0);
			_axis.setMain(symbol.view, main);
			if (curve != null && _projectCurve) {
				symbol.applyCellQuad(curve.quadFor(main, symbol.cellInset));
			}
		}
	}
}
