package reels.config;

class MultiWaysMath {
	public static function cellMain(reelExtent:Float, cells:Int, mainGap:Float):Float {
		if (cells < 1) throw "MultiWaysMath.cellMain: cells must be >= 1";
		return (reelExtent - (cells - 1) * mainGap) / cells;
	}
}
