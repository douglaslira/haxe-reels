package reels.cascade;

import reels.core.Direction;

/** Options for {@link TumbleAlgorithm.computeDropOffsets}. */
typedef ComputeDropOptions = {
	/**
	 * Moment A: treat every visible cell as new (initial drop).
	 * Default false — empty winners means no movement (Moment B idle reel).
	 */
	?initial:Bool,
	/** Settle toward larger (`forward`) or smaller (`reverse`) cell index. */
	?gravity:Direction
};

/**
 * Gravity-correct refill geometry for tumble cascades (pixi-reels ADR 010).
 *
 * Two moments share the same algorithm:
 *   - Moment A (`initial: true`): every visible cell is new; fall distance = visibleCells.
 *   - Moment B (`initial: false`): `winnerCells` removed; survivors pack to exit edge;
 *     empty winners means no movement on this reel.
 *
 * Gravity is travel-direction only — orientation never reaches this function.
 */
class TumbleAlgorithm {
	/**
	 * Compute per-cell drop offsets for one reel given its winner set.
	 * Returns one entry per visible cell, start-to-end.
	 */
	public static function computeDropOffsets(
		visibleCells:Int,
		winnerCells:Array<Int>,
		?options:ComputeDropOptions
	):Array<DropOffset> {
		var initial = options != null && options.initial == true;
		var gravity:Direction = (options != null && options.gravity != null)
			? options.gravity
			: TumbleConfigUtil.DEFAULT_GRAVITY;

		var winCount = initial ? visibleCells : winnerCells.length;
		var winSet = new Map<Int, Bool>();
		if (!initial) {
			for (w in winnerCells) winSet.set(w, true);
		}

		var nonWinnerCells:Array<Int> = [];
		for (r in 0...visibleCells) {
			if (!winSet.exists(r)) nonWinnerCells.push(r);
		}

		var survivorCount = visibleCells - winCount;
		var offsets:Array<DropOffset> = [];
		for (cell in 0...visibleCells) {
			var isNew = gravity == Forward ? cell < winCount : cell >= survivorCount;
			var originalCell:Int;
			if (isNew) {
				originalCell = gravity == Forward ? cell - winCount : cell + winCount;
			} else {
				originalCell = gravity == Forward
					? nonWinnerCells[cell - winCount]
					: nonWinnerCells[cell];
			}
			offsets.push({
				cell: cell,
				originalCell: originalCell,
				offsetCells: cell - originalCell,
				isNew: isNew
			});
		}
		return offsets;
	}
}
