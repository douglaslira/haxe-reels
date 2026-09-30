package reels.cascade;

import reels.frame.ColumnTarget;

/**
 * Options for {@link reels.ReelSet.runCascade}.
 * Game rules stay in the callbacks; the library owns destroy → pause → refill.
 */
typedef RunCascadeOptions = {
	detectWinners:(grid:Array<Array<String>>, chain:Int) -> Array<Cell>,
	nextGrid:(grid:Array<Array<String>>, winners:Array<Cell>, chain:Int) -> Array<ColumnTarget>,
	?pauseAfterDestroyMs:Float,
	?maxChain:Int,
	/** Fired after destroy, before pause/refill (sync). */
	?onCascade:(chain:Int, winners:Array<Cell>) -> Void,
	/** Fired while winners are still visible, before destroy (sync). */
	?presentWinners:(chain:Int, winners:Array<Cell>) -> Void,
	?destroyOptions:DestroySymbolsOptions,
	/** `combined` (default) or `gravity-then-drop`. */
	?refillMode:String,
	?gravityHoldMs:Float,
	?gravityHold:() -> Void,
	?onGravityComplete:() -> Void
};
