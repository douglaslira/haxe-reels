package reels.cascade;

/**
 * Per-visible-cell drop geometry from computeDropOffsets.
 * `offsetCells === 0` means the symbol stays put and must NOT be animated.
 */
typedef DropOffset = {
	/** Visible cell in the new grid (start-to-end, 0-indexed). */
	var cell:Int;
	/**
	 * Where this symbol came from as a virtual cell index.
	 * Off-grid values name the entry edge; in-range values are a survivor's old cell.
	 */
	var originalCell:Int;
	/** Signed cell distance: `cell - originalCell`. */
	var offsetCells:Int;
	/** True for a fresh symbol entering from off-grid. */
	var isNew:Bool;
};
