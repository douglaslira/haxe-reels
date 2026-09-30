package reels.config;

/**
 * MultiWays: fixed reel box on the travel axis; per-spin cell count varies.
 * Cell main size = `(reelExtent - (cells - 1) * mainGap) / cells`.
 */
typedef MultiWaysConfig = {
	minCells:Int,
	maxCells:Int,
	/** Fixed main-axis length of each reel box (px). */
	reelExtent:Float
};
