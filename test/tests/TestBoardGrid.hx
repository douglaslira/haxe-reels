package tests;

import reels.board.BoardGrid;
import reels.clock.FakeClock;
import reels.symbols.HeadlessSymbol;
import utest.Assert;
import utest.Test;

/**
 * BoardGrid geometry / lifecycle — parity with pixi BoardGrid.test.ts.
 */
class TestBoardGrid extends Test {
	function make(?over:{?cols:Int, ?rows:Int, ?cellSize:Float, ?gap:Float, ?emptyId:String}):BoardGrid {
		var clock = new FakeClock();
		return new BoardGrid({
			cols: over != null && over.cols != null ? over.cols : 3,
			rows: over != null && over.rows != null ? over.rows : 2,
			cellSize: over != null && over.cellSize != null ? over.cellSize : 80,
			gap: over != null && over.gap != null ? over.gap : 4,
			emptyId: over != null ? over.emptyId : null,
			symbols: function(r) {
				r.register("a", function() return new HeadlessSymbol());
			},
			weights: ["a" => 1., "empty" => 3.],
			clock: clock
		});
	}

	public function testBuildsOneReelPerCellReelMajor() {
		var grid = make();
		Assert.equals(3, grid.cols);
		Assert.equals(2, grid.rows);
		var cells = grid.cells();
		Assert.equals(6, cells.length);
		Assert.isTrue(cellsExists(cells, 0, 0));
		Assert.isTrue(cellsExists(cells, 2, 1));
		Assert.isFalse(grid.cells() == cells); // fresh array each call
		grid.destroy();
	}

	public function testComputesCellGeometryFromSizeAndGap() {
		var grid = make();
		var b = grid.cellBounds({reel: 1, cell: 0});
		Assert.equals(84., b.x);
		Assert.equals(0., b.y);
		Assert.equals(80., b.width);
		Assert.equals(80., b.height);
		var c0 = grid.cellCenter({reel: 0, cell: 0});
		Assert.equals(40., c0.x);
		Assert.equals(40., c0.y);
		var c21 = grid.cellCenter({reel: 2, cell: 1});
		Assert.equals(2 * 84 + 40., c21.x);
		Assert.equals(1 * 84 + 40., c21.y);
		grid.destroy();
	}

	public function testExposesLiveSymbolAndReelPerCell() {
		var grid = make();
		Assert.notNull(grid.symbolAt({reel: 0, cell: 0}));
		Assert.notNull(grid.reelAt({reel: 1, cell: 1}));
		grid.place({reel: 0, cell: 0}, "a");
		Assert.equals("a", grid.symbolAt({reel: 0, cell: 0}).symbolId);
		grid.destroy();
	}

	public function testThrowsOutsideGrid() {
		var grid = make();
		Assert.raises(function() grid.symbolAt({reel: 9, cell: 9}));
		Assert.raises(function() grid.reelAt({reel: 9, cell: 9}));
		grid.destroy();
	}

	public function testDefaultsEmptyIdGapAndProfile() {
		var clock = new FakeClock();
		var grid = new BoardGrid({
			cols: 1,
			rows: 1,
			cellSize: 60,
			symbols: function(r) {
				r.register("a", function() return new HeadlessSymbol());
			},
			clock: clock
		});
		Assert.equals("empty", grid.emptyId);
		Assert.equals(4., grid.gap);
		grid.setProfile({reel: 0, cell: 0}, "default");
		grid.destroy();
	}

	public function testRequiresClock() {
		Assert.raises(function() {
			new BoardGrid({
				cols: 1,
				rows: 1,
				cellSize: 60,
				symbols: function(r) {
					r.register("a", function() return new HeadlessSymbol());
				},
				clock: null
			});
		});
	}

	public function testSkipSpinningIdleAndDestroyIdempotent() {
		var grid = make();
		Assert.equals(0, grid.skipSpinning());
		Assert.isFalse(grid.isDestroyed);
		grid.destroy();
		Assert.isTrue(grid.isDestroyed);
		grid.destroy(); // idempotent
		Assert.isTrue(grid.isDestroyed);
	}

	function cellsExists(cells:Array<{reel:Int, cell:Int}>, reel:Int, cell:Int):Bool {
		for (c in cells) {
			if (c.reel == reel && c.cell == cell) return true;
		}
		return false;
	}
}
