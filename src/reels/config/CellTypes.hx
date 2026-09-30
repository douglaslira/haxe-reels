package reels.config;

/**
 * Projected cell footprint, view-local.
 * Built by ReelCurve.quadFor(), consumed by ReelSymbol.applyCellQuad().
 */
typedef ReelCellQuad = {
	/** Flat box left, view-local. */
	x:Float,
	/** Flat box top, view-local. */
	y:Float,
	width:Float,
	height:Float,
	/** Clockwise from screen top-left: TL, TR, BR, BL. */
	x0:Float,
	y0:Float,
	x1:Float,
	y1:Float,
	x2:Float,
	y2:Float,
	x3:Float,
	y3:Float
};

/**
 * Fraction of the flat cell the art covers (screen space 0..1).
 * null means art fills the cell.
 */
typedef ReelCellInset = {
	left:Float,
	top:Float,
	right:Float,
	bottom:Float
};
