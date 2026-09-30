package reels.board;

/** Resolution of one board respin wave (driver-facing). */
typedef HwRespinResult = {
	round:Int,
	hits:Array<HwCoin>,
	respinsLeft:Int,
	full:Bool,
	done:Bool
};
