package reels.board;

/** Shared helpers for Hold & Win board types. */
class HwTypes {
	/** `reel,cell` string key for cell-indexed maps. */
	public static inline function cellKey(c:HwCell):String {
		return '${c.reel},${c.cell}';
	}
}
