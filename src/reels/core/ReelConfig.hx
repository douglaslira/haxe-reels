package reels.core;

import reels.core.ReelAxis;

typedef ReelConfig = {
	index:Int,
	visibleCells:Int,
	bufferStart:Int,
	bufferEnd:Int,
	symbolWidth:Float,
	symbolHeight:Float,
	symbolGapX:Float,
	symbolGapY:Float,
	axis:ReelAxis,
	/** Optional curve input; flat/absent means no ReelCurve object. */
	?curve:ReelCurveInput,
	/**
	 * Reel-local cross coordinate the perspective converges on.
	 * Omitted = reel centreline (`cellCross / 2`).
	 */
	?curveFocusCross:Float,
	/**
	 * When true (and curve is non-flat), bend the whole reel via {@link ReelWarp}
	 * instead of per-symbol quads. Set by `ReelSetBuilder.curveMode('warp')`.
	 */
	?warping:Bool,
	/**
	 * Cross-axis overflow room for warp texture (art wider than a cell).
	 * Ignored in symbol mode.
	 */
	?curveBleed:Float
};
