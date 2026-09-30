package reels.board;

/**
 * One state-change the reducer decided, ready for a driver to emit.
 * `respin:start` / `feature:skip` are driver-owned and not produced here.
 */
typedef HwEffect = {
	type:String,
	payload:Dynamic
};
