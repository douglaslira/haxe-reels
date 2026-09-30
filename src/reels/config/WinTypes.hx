package reels.config;

/**
 * Visible-grid cell. `reelIndex` = column; `cellIndex` = row from start of travel.
 * Win detection is consumer-side — the engine only animates these cells.
 */
typedef SymbolPosition = {
	reelIndex:Int,
	cellIndex:Int,
	?setId:String
};

/**
 * One win as the presenter sees it: ordered cells to highlight.
 * `value` drives default sort-desc; `id` is an optional event-routing tag.
 */
typedef Win = {
	cells:Array<SymbolPosition>,
	?value:Float,
	?id:Dynamic
};

typedef CellBounds = {
	x:Float,
	y:Float,
	width:Float,
	height:Float
};
