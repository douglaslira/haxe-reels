package reels.core;

import reels.config.CellTypes.ReelCellInset;
import reels.config.CellTypes.ReelCellQuad;

/**
 * Fake the curvature of a spinning reel cylinder.
 *
 * Middle cell faces you; outer cells become trapezoids (keystone), not just
 * smaller rectangles. Port of pixi-reels ReelCurve.
 *
 * Does NOT write symbol.position — projection is a view-LOCAL quad.
 */
typedef ReelCurveConfig = {
	amount:Float,
	?depth:Float
};

typedef ResolvedReelCurveConfig = {
	amount:Float,
	depth:Float
};

class ReelCurve {
	static inline var MAX_ARC:Float = 1.0;
	static inline var MIN_ARC:Float = 1e-4;
	static inline var DEPTH_SAFETY:Float = 0.9;

	var _config:ResolvedReelCurveConfig;
	var _axis:ReelAxis;
	var _arc:Float;
	var _k:Float;
	var _edgeScale:Float;
	var _norm:Float;
	var _edgeMapped:Float;
	var _edgeSlope:Float;

	var _cellMain:Float = 0;
	var _cellCross:Float = 0;
	var _halfExtent:Float = 0;
	var _radius:Float = 0;
	var _focusCross:Null<Float> = null;

	public function new(config:ResolvedReelCurveConfig, axis:ReelAxis) {
		_config = config;
		_axis = axis;
		_arc = config.amount * MAX_ARC;
		var sinArc = Math.sin(_arc);
		var cosArc = Math.cos(_arc);
		var versine = 1 - cosArc;
		_k = versine > 0 ? config.depth / versine : 0;
		_edgeScale = perspectiveAt(_arc);
		_norm = _arc > 0 ? _arc : 1;
		_edgeMapped = (sinArc * _edgeScale) / _norm;
		_edgeSlope = _arc > 0
			? (_arc * (cosArc * (1 + _k) - _k) * _edgeScale * _edgeScale) / _norm
			: 1;
	}

	/** Normalize shorthand and fill fold-safe default depth. */
	public static function resolveCurveConfig(input:ReelCurveInput):ResolvedReelCurveConfig {
		var amount:Float = 0;
		var depthOpt:Null<Float> = null;
		if (input == null) {
			amount = 0;
		} else {
			switch (Type.typeof(input)) {
				case TInt:
					amount = (input : Int);
				case TFloat:
					amount = (input : Float);
				default:
					if (Reflect.hasField(input, "amount")) {
						amount = Reflect.field(input, "amount");
					}
					if (Reflect.hasField(input, "depth")) {
						depthOpt = Reflect.field(input, "depth");
					}
			}
		}
		amount = clamp01(amount);
		var requested = clamp01(depthOpt != null ? depthOpt : amount * 0.5);
		var limit = DEPTH_SAFETY * Math.cos(amount * MAX_ARC);
		return {amount: amount, depth: Math.min(requested, limit)};
	}

	static function clamp01(v:Float):Float {
		if (!Math.isFinite(v)) return 0;
		if (v < 0) return 0;
		if (v > 1) return 1;
		return v;
	}

	public var config(get, never):ResolvedReelCurveConfig;

	function get_config():ResolvedReelCurveConfig {
		return _config;
	}

	public var isFlat(get, never):Bool;

	function get_isFlat():Bool {
		return _arc < MIN_ARC;
	}

	/**
	 * Flat half-window along main (leading edge of first cell → trailing of last).
	 */
	public var halfExtent(get, never):Float;

	function get_halfExtent():Float {
		return _halfExtent;
	}

	/**
	 * Where the drum edge lands as a fraction of {@link halfExtent}.
	 * `< 1` means ends fall short of the flat window (buffer band).
	 */
	public var edgeMapped(get, never):Float;

	function get_edgeMapped():Float {
		return _edgeMapped;
	}

	/**
	 * Projected half-window: `halfExtent * edgeMapped`.
	 * Zero when flat / unbound.
	 */
	public var projectedHalfExtent(get, never):Float;

	function get_projectedHalfExtent():Float {
		if (isFlat || _halfExtent <= 0) return 0;
		return _halfExtent * _edgeMapped;
	}

	/**
	 * Main-axis inset from each flat window edge to the drum edge.
	 * Use this to clip the viewport so buffer fill in the shortfall band
	 * is not visible during flat scroll through a curved strip.
	 */
	public var edgeInsetMain(get, never):Float;

	function get_edgeInsetMain():Float {
		if (isFlat || _halfExtent <= 0) return 0;
		return _halfExtent * (1 - _edgeMapped);
	}

	public function setGeometry(cellMain:Float, cellCross:Float, pitch:Float, visibleCells:Int):Void {
		_cellMain = cellMain;
		_cellCross = cellCross;
		_halfExtent = (visibleCells * pitch - (pitch - cellMain)) / 2;
		_radius = _arc > 0 ? _halfExtent / _arc : 0;
	}

	public function setFocus(cross:Null<Float>):Void {
		_focusCross = cross;
	}

	public var focusCross(get, never):Float;

	function get_focusCross():Float {
		return _focusCross != null ? _focusCross : _cellCross / 2;
	}

	public function quadFor(mainStart:Float, ?inset:ReelCellInset):Null<ReelCellQuad> {
		if (isFlat || _halfExtent <= 0) return null;

		var mainFrom = mainStart;
		var mainTo = mainStart + _cellMain;
		var crossFrom = 0.;
		var crossTo = _cellCross;
		if (inset != null) {
			var from = _axis.toLocal(inset.left, inset.top);
			var to = _axis.toLocal(inset.right, inset.bottom);
			mainFrom = mainStart + from.main * _cellMain;
			mainTo = mainStart + to.main * _cellMain;
			crossFrom = from.cross * _cellCross;
			crossTo = to.cross * _cellCross;
		}

		var near = project(mainFrom);
		var far = project(mainTo);
		var centre = focusCross;
		var nearFrom = centre + (crossFrom - centre) * near.scale;
		var nearTo = centre + (crossTo - centre) * near.scale;
		var farFrom = centre + (crossFrom - centre) * far.scale;
		var farTo = centre + (crossTo - centre) * far.scale;
		var nearMain = near.main - mainStart;
		var farMain = far.main - mainStart;

		var a0 = _axis.toScreen(nearFrom, nearMain);
		var a1 = _axis.toScreen(nearTo, nearMain);
		var b0 = _axis.toScreen(farFrom, farMain);
		var b1 = _axis.toScreen(farTo, farMain);

		var origin = _axis.toScreen(crossFrom, mainFrom - mainStart);
		var size = _axis.toScreen(crossTo - crossFrom, mainTo - mainFrom);
		var vertical = _axis.orientation == Vertical;

		if (vertical) {
			return {
				x: origin.x, y: origin.y, width: size.x, height: size.y,
				x0: a0.x, y0: a0.y,
				x1: a1.x, y1: a1.y,
				x2: b1.x, y2: b1.y,
				x3: b0.x, y3: b0.y
			};
		}
		return {
			x: origin.x, y: origin.y, width: size.x, height: size.y,
			x0: a0.x, y0: a0.y,
			x1: b0.x, y1: b0.y,
			x2: b1.x, y2: b1.y,
			x3: a1.x, y3: a1.y
		};
	}

	public function mapMain(main:Float):Float {
		return project(main).main;
	}

	public function scaleAt(main:Float):Float {
		return project(main).scale;
	}

	function project(main:Float):{main:Float, scale:Float} {
		if (isFlat || _halfExtent <= 0) return {main: main, scale: 1};
		var h = _halfExtent;
		var phi = (main - h) / _radius;
		var scale = perspectiveAt(Math.min(Math.abs(phi), Math.PI));
		var edge = h * _edgeMapped;
		if (phi > _arc) {
			return {main: h + edge + (main - 2 * h) * _edgeSlope, scale: scale};
		}
		if (phi < -_arc) {
			return {main: h - edge + main * _edgeSlope, scale: scale};
		}
		return {main: h + (h * Math.sin(phi) * scale) / _norm, scale: scale};
	}

	function perspectiveAt(phi:Float):Float {
		return 1 / (1 + _k * (1 - Math.cos(phi)));
	}
}
