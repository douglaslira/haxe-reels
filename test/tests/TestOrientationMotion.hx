package tests;

import reels.core.Direction;
import reels.core.Orientation;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

/**
 * ADR 018 motion contract — four orientation × direction combos land stably.
 */
class TestOrientationMotion extends Test {
	static function runCombo(orientation:Orientation, direction:Direction) {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			symbolWidth: 80,
			symbolHeight: 80,
			bufferSymbols: 1,
			orientation: orientation,
			direction: direction
		});
		var grid = [
			{visible: ["a", "b", "c"]},
			{visible: ["c", "b", "a"]}
		];
		h.spinAndLand(grid, function(_) {});
		TestHarness.expectGrid(h.reelSet, grid);
		var mains = h.reelSet.getReel(0).getVisibleMains();
		Assert.equals(3, mains.length);
		Assert.floatEquals(0, mains[0], 0.5);
		Assert.floatEquals(80, mains[1], 0.5);
		Assert.floatEquals(160, mains[2], 0.5);
		h.destroy();
	}

	public function testVerticalForward() {
		runCombo(Vertical, Forward);
	}

	public function testVerticalReverse() {
		runCombo(Vertical, Reverse);
	}

	public function testHorizontalForward() {
		runCombo(Horizontal, Forward);
	}

	public function testHorizontalReverse() {
		runCombo(Horizontal, Reverse);
	}
}
