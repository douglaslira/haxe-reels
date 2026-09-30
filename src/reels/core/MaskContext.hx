package reels.core;

/**
 * Context passed to {@link MaskStrategy.build} / {@link MaskStrategy.update}.
 * `bleed` expands the clip on the cross axis (curveBleed overhang).
 * `mainInset` shrinks the clip on the travel axis (curved drum shortfall).
 */
typedef MaskContext = {
	width:Float,
	height:Float,
	rects:Array<ReelMaskRect>,
	/** True when travel axis is Y (vertical reels). */
	verticalMain:Bool,
	?bleed:Float,
	?mainInset:Float
};
