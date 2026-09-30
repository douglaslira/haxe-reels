package reels.board;

/**
 * A coin somewhere on the board. `id` selects the registered symbol art;
 * `data` is an opaque game-layer payload the board never interprets.
 *
 * Ownership: `cell` / `id` belong to the board (read-only). `data` is yours.
 * The reducer stores a **copy** of `cell` (no Object.freeze in Haxe).
 */
typedef HwCoin = {
	cell:HwCell,
	id:String,
	?data:Dynamic
};
