package reels.core;

/**
 * How {@link ReelCurve} is drawn (pixi `CurveMode`).
 * - `Symbol`: per-cell quads via PerspectiveCell (default)
 * - `Warp`: whole reel to texture + mesh bend (cascade rides the drum)
 */
enum abstract CurveMode(String) from String to String {
	var Symbol = "symbol";
	var Warp = "warp";

	public static function parse(raw:String):CurveMode {
		if (raw == Warp) return Warp;
		if (raw == Symbol) return Symbol;
		throw 'curveMode(): expected \'symbol\' or \'warp\', got "$raw".';
	}
}
