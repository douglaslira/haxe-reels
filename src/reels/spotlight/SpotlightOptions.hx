package reels.spotlight;

import reels.config.WinTypes.SymbolPosition;

typedef SpotlightOptions = {
	/** Dim overlay opacity 0–1. Default 0.5. */
	?dimAmount:Float,
	/** Call playWin on spotlighted symbols. Default true. */
	?playWinAnimation:Bool,
	/** Reparent winners above the mask. Default true. */
	?promoteAboveMask:Bool
};

typedef WinLine = {
	positions:Array<SymbolPosition>
};

typedef CycleOptions = {
	> SpotlightOptions,
	/** Ms to display each line. Default 2000. */
	?displayDuration:Float,
	/** Ms between lines. Default 300. */
	?gapDuration:Float,
	/** Full passes through the list; -1 = infinite. Default 1. */
	?cycles:Int
};
