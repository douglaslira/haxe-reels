package tests;

import reels.events.ReelEvents;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestSpinAndLand extends Test {
	public function testSlamLandsTargetGrid() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"]
		});
		var grid = [
			{visible: ["a", "a", "a"]},
			{visible: ["b", "b", "b"]},
			{visible: ["c", "c", "c"]}
		];
		var completed = false;
		var wasSkipped = false;
		h.spinAndLand(grid, function(result) {
			completed = true;
			wasSkipped = result.wasSkipped;
		});
		Assert.isTrue(completed);
		Assert.isTrue(wasSkipped);
		TestHarness.expectGrid(h.reelSet, grid);
		h.destroy();
	}

	public function testSpinCompleteEvent() {
		var h = TestHarness.createTestReelSet({reels: 2, visibleCells: 2, symbolIds: ["x", "y"]});
		var events = 0;
		h.reelSet.events.on(ReelEvents.SPIN_COMPLETE, function(_) events++);
		h.spinAndLand([
			{visible: ["x", "y"]},
			{visible: ["y", "x"]}
		], function(_) {});
		Assert.equals(1, events);
		h.destroy();
	}

	public function testDestroyIsIdempotent() {
		var h = TestHarness.createTestReelSet({reels: 1, visibleCells: 1, symbolIds: ["a"]});
		h.destroy();
		h.destroy();
		Assert.isTrue(h.reelSet.isDestroyed);
	}

	/**
	 * Regression: rebuildStrip must keep the same Array instance that
	 * ReelMotion holds. Otherwise snapToGrid after setResult leaves views
	 * at y=0 and the grid shows empty holes.
	 */
	public function testSecondLandSnapsVisibleMains() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			symbolHeight: 100,
			symbolWidth: 120,
			bufferSymbols: 1
		});
		h.spinAndLand([{visible: ["a", "a", "a"]}], function(_) {});
		h.spinAndLand([{visible: ["b", "c", "b"]}], function(_) {});
		var mains = h.reelSet.getReel(0).getVisibleMains();
		Assert.equals(3, mains.length);
		Assert.floatEquals(0, mains[0], 0.01);
		Assert.floatEquals(100, mains[1], 0.01);
		Assert.floatEquals(200, mains[2], 0.01);
		TestHarness.expectGrid(h.reelSet, [{visible: ["b", "c", "b"]}]);
		h.destroy();
	}

	/** Slam immediately after spin() (still in StartPhase) must not corrupt the grid. */
	public function testImmediateSlamPreservesResult() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			bufferSymbols: 1
		});
		var grid = [{visible: ["c", "c", "c"]}];
		h.spinAndLand(grid, function(_) {});
		TestHarness.expectGrid(h.reelSet, grid);
		h.destroy();
	}

	/** skipSpin boosts once; next spin() restores the previous profile. */
	public function testSkipBoostRestoresOnNextSpin() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"]
		});
		Assert.equals("normal", h.reelSet.speed.current.name);
		var done = false;
		h.reelSet.spin(function(_) done = true);
		h.reelSet.setResult([{visible: ["a", "a", "a"]}]);
		h.reelSet.skipSpin();
		var guard = 0;
		while (!done && guard < 50) {
			h.clock.advance(50);
			guard++;
		}
		Assert.equals("superTurbo", h.reelSet.speed.current.name);
		// Next spin restores before phases run.
		done = false;
		h.reelSet.spin(function(_) done = true);
		Assert.equals("normal", h.reelSet.speed.current.name);
		h.reelSet.setResult([{visible: ["b", "b", "b"]}]);
		h.reelSet.slamStop();
		guard = 0;
		while (!done && guard < 50) {
			h.clock.advance(50);
			guard++;
		}
		Assert.equals("normal", h.reelSet.speed.current.name);
		h.destroy();
	}

	/** Manual setSpeed after skip must survive the next spin restore. */
	public function testManualSpeedSurvivesSkipRestore() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"]
		});
		var done = false;
		h.reelSet.spin(function(_) done = true);
		h.reelSet.setResult([{visible: ["a", "a", "a"]}]);
		h.reelSet.skipSpin();
		var guard = 0;
		while (!done && guard < 50) {
			h.clock.advance(50);
			guard++;
		}
		Assert.equals("superTurbo", h.reelSet.speed.current.name);
		h.reelSet.setSpeed("turbo");
		done = false;
		h.reelSet.spin(function(_) done = true);
		Assert.equals("turbo", h.reelSet.speed.current.name);
		h.reelSet.setResult([{visible: ["c", "c", "c"]}]);
		h.reelSet.slamStop();
		guard = 0;
		while (!done && guard < 50) {
			h.clock.advance(50);
			guard++;
		}
		Assert.equals("turbo", h.reelSet.speed.current.name);
		h.destroy();
	}

	/**
	 * Natural stop (no slam): result scrolls in via StopFrameQueue wraps.
	 * Must land the exact visible target without an instant strip swap.
	 */
	public function testNaturalLandViaStopQueue() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			bufferSymbols: 1,
			symbolHeight: 100
		});
		var grid = [{visible: ["a", "b", "c"]}];
		var done = false;
		h.reelSet.spin(function(_) done = true);
		h.reelSet.setResult(grid);
		var guard = 0;
		while (!done && guard < 500) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "natural land should complete");
		TestHarness.expectGrid(h.reelSet, grid);
		var mains = h.reelSet.getReel(0).getVisibleMains();
		Assert.floatEquals(0, mains[0], 0.01);
		Assert.floatEquals(100, mains[1], 0.01);
		Assert.floatEquals(200, mains[2], 0.01);
		h.destroy();
	}
}
