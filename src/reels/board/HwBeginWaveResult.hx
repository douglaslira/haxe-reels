package reels.board;

typedef HwBeginWaveResult = {
	round:Int,
	spinning:Array<HwCell>,
	hitByKey:Map<String, HwCoin>
};
