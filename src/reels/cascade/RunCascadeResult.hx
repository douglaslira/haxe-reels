package reels.cascade;

/** Summary returned by {@link reels.ReelSet.runCascade}. */
typedef RunCascadeResult = {
	chainLength:Int,
	totalWinners:Int,
	finalGrid:Array<Array<String>>,
	wasSkipped:Bool
};
