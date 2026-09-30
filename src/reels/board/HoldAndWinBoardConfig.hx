package reels.board;

import openfl.display.Graphics;
import reels.clock.IFrameClock;
import reels.config.SpeedProfile;
import reels.core.Direction;
import reels.core.Orientation;
import reels.symbols.SymbolRegistry;

/** Internal config produced by {@link HoldAndWinBuilder.build}. */
typedef HoldAndWinBoardConfig = {
	cols:Int,
	rows:Int,
	cell:Float,
	gap:Float,
	emptyId:String,
	respins:Int,
	bufferSymbols:Int,
	configurator:SymbolRegistry->Void,
	weights:Null<Map<String, Float>>,
	baseProfile:SpeedProfile,
	stagger:Int->Int->Float,
	anticipateWhen:Null<({locked:Int, capacity:Int, respinsLeft:Int}) -> Bool>,
	chrome:Null<Graphics->Float->Void>,
	?orientation:Orientation,
	?direction:Direction,
	clock:IFrameClock,
	rng:Null<() -> Float>
};
