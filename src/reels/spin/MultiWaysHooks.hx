package reels.spin;

/**
 * Hooks ReelSet injects into SpinController for MultiWays reshape.
 * Non-multiways slots pass isMultiWays=false and no-op callbacks.
 */
typedef MultiWaysHooks = {
	isMultiWays:Bool,
	peekTargetShape:() -> Null<Array<Int>>,
	clearTargetShape:() -> Void,
	applyReshape:(reelIndex:Int, targetCells:Int) -> Void,
	/** Finish pin-overlay migrate tweens for a reel (AdjustPhase skip / slam). */
	snapPinOverlaysForReel:(reelIndex:Int) -> Void,
	adjustDurationMs:Float
};
