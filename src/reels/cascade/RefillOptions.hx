package reels.cascade;

import reels.frame.ColumnTarget;

/**
 * Options for `ReelSet.refill` (Moment B).
 * `mode`: `combined` (default) or `gravity-then-drop` (two-stage).
 */
typedef RefillOptions = {
	winners:Array<Cell>,
	grid:Array<ColumnTarget>,
	?mode:String,
	/** Global pause between gravity and drop-in (ms). Default 250. Two-stage only. */
	?gravityHoldMs:Float,
	/** Fired at gravity-end (start of hold), sync. Two-stage only. */
	?gravityHold:() -> Void,
	/** Fired after hold resolves, before stage-2 drop-in. Two-stage only. */
	?onGravityComplete:() -> Void
};
