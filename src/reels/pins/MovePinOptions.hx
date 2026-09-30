package reels.pins;

import reels.symbols.ReelSymbol;

/** Grid coordinate for pin APIs. */
typedef CellCoord = {
	reel:Int,
	cell:Int
};

/**
 * Options for {@link reels.ReelSet.movePin}.
 * Flight animation tuning + lifecycle hooks (pixi parity).
 */
typedef MovePinOptions = {
	/** Animation duration in ms. Default 400. */
	?duration:Float,
	/** Easing name (`power2.inOut` default). Resolved via {@link reels.tween.Easing.resolve}. */
	?easing:String,
	/** Symbol id for the vacated cell. When omitted, engine picks a random filler. */
	?backfill:String,
	/** After flight symbol is placed at `from`, before the tween starts. */
	?onFlightCreated:ReelSymbol->Void,
	/** After tween completes, before flight is released to the pool. */
	?onFlightCompleted:ReelSymbol->Void
};
