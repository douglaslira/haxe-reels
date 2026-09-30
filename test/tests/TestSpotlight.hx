package tests;

import reels.config.WinTypes.SymbolPosition;
import reels.events.ReelEvents;
import reels.frame.ColumnTarget;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestSpotlight extends Test {
	static function grid():Array<ColumnTarget> {
		return [
			for (_ in 0...5) ({visible: ["a", "b", "c"]}:ColumnTarget)
		];
	}

	static function pos(r:Int, c:Int):SymbolPosition {
		return {reelIndex: r, cellIndex: c};
	}

	public function testShowHideEmitsEventsAndRestoresParent() {
		var h = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"]
		});
		var log:Array<String> = [];
		h.reelSet.events.on(ReelEvents.SPOTLIGHT_START, function(_) log.push("start"));
		h.reelSet.events.on(ReelEvents.SPOTLIGHT_END, function(_) log.push("end"));

		h.spinAndLand(grid(), function(_) {});
		var reel = h.reelSet.getReel(0);
		var sym = reel.getSymbolAt(1);
		var parentBefore = sym.displayObject.parent;

		var done = false;
		h.reelSet.spotlight.show([pos(0, 1)], {playWinAnimation: true}, function() done = true);
		Assert.isTrue(done);
		Assert.isTrue(h.reelSet.spotlight.isActive);
		Assert.notEquals(parentBefore, sym.displayObject.parent);

		h.reelSet.spotlight.hide();
		Assert.isFalse(h.reelSet.spotlight.isActive);
		Assert.equals(parentBefore, sym.displayObject.parent);
		Assert.same(["start", "end"], log);
		h.destroy();
	}

	public function testHideSkipsRecycledPromotedSymbol() {
		var h = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"]
		});
		h.spinAndLand(grid(), function(_) {});

		h.reelSet.spotlight.show([pos(0, 1)], {playWinAnimation: false, promoteAboveMask: true});
		// Recycle via another land while still promoted.
		h.spinAndLand([
			for (_ in 0...5) ({visible: ["c", "c", "c"]}:ColumnTarget)
		], function(_) {});
		h.reelSet.spotlight.hide();

		for (r in 0...5) {
			var reel = h.reelSet.getReel(r);
			for (i in 0...reel.visibleCells) {
				var s = reel.getSymbolAt(i);
				Assert.equals(
					reel.host,
					s.displayObject.parent,
					'reel $r cell $i parent'
				);
			}
		}
		h.destroy();
	}

	public function testPromoteFalseDoesNotReparent() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b"]
		});
		h.spinAndLand([
			{visible: ["a", "a", "a"]},
			{visible: ["b", "b", "b"]},
			{visible: ["a", "b", "a"]}
		], function(_) {});
		var sym = h.reelSet.getReel(0).getSymbolAt(0);
		var parent = sym.displayObject.parent;
		h.reelSet.spotlight.show([pos(0, 0)], {promoteAboveMask: false, playWinAnimation: false});
		Assert.equals(parent, sym.displayObject.parent);
		h.reelSet.spotlight.hide();
		h.destroy();
	}

	public function testCycleRunsThenCompletes() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a"]
		});
		h.spinAndLand([
			{visible: ["a", "a", "a"]},
			{visible: ["a", "a", "a"]},
			{visible: ["a", "a", "a"]}
		], function(_) {});

		var starts = 0;
		h.reelSet.events.on(ReelEvents.SPOTLIGHT_START, function(_) starts++);

		var done = false;
		h.reelSet.spotlight.cycle(
			[
				{positions: [pos(0, 0)]},
				{positions: [pos(1, 1)]}
			],
			{displayDuration: 50, gapDuration: 10, cycles: 1, playWinAnimation: false},
			function() done = true
		);
		Assert.isFalse(done);
		h.advance(500);
		Assert.isTrue(done);
		Assert.equals(2, starts);
		h.destroy();
	}

	public function testGetCellBoundsFlat() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a"],
			symbolWidth: 100,
			symbolHeight: 80
		});
		var b = h.reelSet.getCellBounds(1, 2);
		Assert.floatEquals(100 + 0, b.x, 0.01); // reel 1 at x = 100 (gap 0)
		Assert.floatEquals(160, b.y, 0.01); // cell 2 * 80
		Assert.floatEquals(100, b.width, 0.01);
		Assert.floatEquals(80, b.height, 0.01);
		h.destroy();
	}
}
