package reels.symbols;

import reels.frame.ColumnTarget;
import reels.frame.ColumnTargets;

/**
 * Paints {@link OccupiedStub.SENTINEL} across non-anchor cells of big symbols
 * in a result grid (visible + bufferStart/End — pixi parity).
 */
class BigSymbolCoord {
	/**
	 * Pure: returns a cloned grid with OCCUPIED painted. Throws if a block
	 * does not fit. No-op when every symbol is 1×1.
	 *
	 * @param bufferStart strip buffer above (uniform across reels)
	 * @param bufferEnd strip buffer below (uniform across reels)
	 */
	public static function coordinate(
		grid:Array<ColumnTarget>,
		getSize:String->SymbolSize,
		visibleCellsForReel:Int->Int,
		bufferStart:Int = 0,
		bufferEnd:Int = 0
	):Array<ColumnTarget> {
		var out:Array<ColumnTarget> = [];
		for (col in grid) out.push(ColumnTargets.cloneColumnTarget(col));
		for (reel in 0...out.length) {
			var cells = visibleCellsForReel(reel);
			var cell = -bufferStart;
			while (cell < cells + bufferEnd) {
				var id = ColumnTargets.getTargetSlot(out[reel], cell);
				if (id == null || id == OccupiedStub.SENTINEL) {
					cell++;
					continue;
				}
				var size = getSize(id);
				var w = size.reels;
				var h = size.cells;
				if (w <= 1 && h <= 1) {
					cell++;
					continue;
				}
				if (cell + h > cells + bufferEnd) {
					throw 'big symbol \'$id\' (${w}x${h}) at (reel=$reel, cell=$cell) '
						+ 'extends past the bottom of the strip on reel $reel '
						+ '(anchor cell + h = ${cell + h} > visibleCells + bufferEnd = ${cells + bufferEnd}).';
				}
				if (reel + w > out.length) {
					throw 'big symbol \'$id\' (${w}x${h}) at (reel=$reel, cell=$cell) '
						+ 'exceeds reel count ${out.length}.';
				}
				for (dx in 0...w) {
					var targetCells = visibleCellsForReel(reel + dx);
					if (cell + h > targetCells + bufferEnd) {
						throw 'big symbol \'$id\' (${w}x${h}) at (reel=$reel, cell=$cell) '
							+ 'extends past the bottom of the strip on reel ${reel + dx}.';
					}
				}
				for (dy in 0...h) {
					for (dx in 0...w) {
						if (dx == 0 && dy == 0) continue;
						ColumnTargets.setTargetSlot(out[reel + dx], cell + dy, OccupiedStub.SENTINEL);
					}
				}
				cell++;
			}
		}
		return out;
	}

	public static function isBig(size:SymbolSize):Bool {
		return size != null && (size.reels > 1 || size.cells > 1);
	}

	public static function unit():SymbolSize {
		return {reels: 1, cells: 1};
	}
}
