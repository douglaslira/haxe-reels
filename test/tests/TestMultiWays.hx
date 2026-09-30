package tests;

import reels.config.MultiWaysMath;
import reels.events.ReelEvents;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestMultiWays extends Test {
	public function testCellMainFormula() {
		Assert.floatEquals(100, MultiWaysMath.cellMain(300, 3, 0), 1e-9);
		Assert.floatEquals(90, MultiWaysMath.cellMain(300, 3, 15), 1e-9);
	}

	public function testBuildsAtMaxCells() {
		var h = TestHarness.createTestReelSet({
			reels: 4,
			multiways: {minCells: 2, maxCells: 6, reelExtent: 600},
			symbolIds: ["a", "b"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		Assert.isTrue(h.reelSet.isMultiWays);
		for (i in 0...4) {
			Assert.equals(6, h.reelSet.getReel(i).visibleCells);
		}
		h.destroy();
	}

	public function testMultiwaysExclusiveWithVisibleCells() {
		var clock = new reels.clock.FakeClock();
		Assert.raises(function() {
			new reels.ReelSetBuilder()
				.reels(3)
				.visibleCells(3)
				.multiways({minCells: 2, maxCells: 5, reelExtent: 500})
				.symbolSize(100, 100)
				.clock(clock)
				.symbols(function(r) {
					r.register("a", function() return new reels.symbols.HeadlessSymbol());
				})
				.speed("normal", reels.config.SpeedPresets.NORMAL)
				.build();
		});
		clock.destroy();
	}

	public function testSetShapeEmitsAndReshapesOnLand() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			multiways: {minCells: 2, maxCells: 6, reelExtent: 600},
			symbolIds: ["a", "b"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		var shapes:Array<Dynamic> = [];
		var adjusts = 0;
		h.reelSet.events.on(ReelEvents.SHAPE_CHANGED, function(args) {
			shapes.push(args[0]);
		});
		h.reelSet.events.on(ReelEvents.ADJUST_START, function(_) adjusts++);

		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([3, 4, 5]);
		Assert.equals(1, shapes.length);
		Assert.same([3, 4, 5], shapes[0]);

		h.reelSet.setResult([
			{visible: ["a", "a", "a"]},
			{visible: ["b", "b", "b", "b"]},
			{visible: ["a", "b", "a", "b", "a"]}
		]);
		h.advance(5000);
		h.reelSet.slamStop();
		h.advance(100);

		Assert.isTrue(adjusts >= 1);
		Assert.equals(3, h.reelSet.getReel(0).visibleCells);
		Assert.equals(4, h.reelSet.getReel(1).visibleCells);
		Assert.equals(5, h.reelSet.getReel(2).visibleCells);
		Assert.floatEquals(200, h.reelSet.getReel(0).symbolHeight, 1e-6);
		Assert.floatEquals(150, h.reelSet.getReel(1).symbolHeight, 1e-6);
		Assert.floatEquals(120, h.reelSet.getReel(2).symbolHeight, 1e-6);
		h.destroy();
	}

	public function testSetShapeThrowsOnNonMultiways() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a"]
		});
		Assert.raises(function() h.reelSet.setShape([3, 3, 3]));
		h.destroy();
	}

	public function testSetShapeThrowsAfterSetResult() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			multiways: {minCells: 2, maxCells: 5, reelExtent: 500},
			symbolIds: ["a"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([3, 3]);
		h.reelSet.setResult([
			{visible: ["a", "a", "a"]},
			{visible: ["a", "a", "a"]}
		]);
		Assert.raises(function() h.reelSet.setShape([2, 2]));
		h.reelSet.slamStop();
		h.advance(50);
		h.destroy();
	}

	public function testSetShapeValidatesBounds() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			multiways: {minCells: 2, maxCells: 5, reelExtent: 500},
			symbolIds: ["a"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		Assert.raises(function() h.reelSet.setShape([3, 3]));
		Assert.raises(function() h.reelSet.setShape([3, 3, 1]));
		Assert.raises(function() h.reelSet.setShape([3, 3, 6]));
		h.destroy();
	}

	public function testSetResultValidatesAgainstPendingShape() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			multiways: {minCells: 2, maxCells: 5, reelExtent: 500},
			symbolIds: ["a"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([2, 4]);
		Assert.raises(function() {
			h.reelSet.setResult([
				{visible: ["a", "a", "a"]},
				{visible: ["a", "a", "a", "a"]}
			]);
		});
		h.reelSet.slamStop();
		h.advance(50);
		h.destroy();
	}

	public function testUnchangedShapeIsNoop() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			multiways: {minCells: 2, maxCells: 4, reelExtent: 400},
			symbolIds: ["a"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		var n = 0;
		h.reelSet.events.on(ReelEvents.SHAPE_CHANGED, function(_) n++);
		h.reelSet.setShape([4, 4]);
		Assert.equals(0, n);
		h.destroy();
	}
}
