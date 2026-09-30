package reels.board;

import openfl.display.Graphics;
import reels.clock.IFrameClock;
import reels.core.Direction;
import reels.core.Orientation;
import reels.symbols.SymbolRegistry;

/** Options for {@link BoardGrid}. */
typedef BoardGridOptions = {
	cols:Int,
	rows:Int,
	cellSize:Float,
	?gap:Float,
	?emptyId:String,
	/**
	 * Off-window buffer depth per cell (start and end). Default 3 — a 1×1
	 * reel with buffer 1 barely shows strip motion; deeper buffers let
	 * weighted fillers scroll past during spin.
	 */
	?bufferSymbols:Int,
	symbols:SymbolRegistry->Void,
	?weights:Map<String, Float>,
	clock:IFrameClock,
	?chrome:Graphics->Float->Void,
	?orientation:Orientation,
	?direction:Direction,
	/**
	 * Named profiles registered on every cell. Defaults to a single
	 * `'default'` profile when omitted.
	 */
	?profiles:Map<String, BoardProfile>,
	?rng:() -> Float
};
