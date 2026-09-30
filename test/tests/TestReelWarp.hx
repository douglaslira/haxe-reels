package tests;

import utest.Assert;
import utest.Test;
import reels.testing.TestHarness;

/**
 * curveMode('warp') + curveBleed — Fatia 1 of v0.5.
 */
class TestReelWarp extends Test {
	public function testDefaultCurveModeIsSymbol() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b"],
			curve: 0.5
		});
		Assert.isFalse(h.reelSet.getReel(0).warping);
		Assert.isNull(h.reelSet.getReel(0).warp);
		Assert.isTrue(h.reelSet.getReel(0).curveVisuals);
		Assert.floatEquals(0, h.reelSet.maskCrossBleed, 1e-9);
		h.destroy();
	}

	public function testBuilderCurveModeWarpAttaches() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b"],
			curve: 0.5,
			curveMode: "warp"
		});
		var reel = h.reelSet.getReel(0);
		Assert.isTrue(reel.warping);
		Assert.notNull(reel.warp);
		Assert.isTrue(reel.curveVisuals);
		Assert.isFalse(reel.warp.isDestroyed);
		// Host is off the masked content list; warp.view is shown instead.
		Assert.isNull(reel.host.parent);
		Assert.notNull(reel.warp.view.parent);
		h.destroy();
	}

	public function testWarpWithoutCurveBuildsFlat() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 2,
			symbolIds: ["a"],
			curveMode: "warp"
		});
		Assert.isFalse(h.reelSet.getReel(0).warping);
		Assert.isNull(h.reelSet.getReel(0).warp);
		h.destroy();
	}

	public function testCurveModeRejectsUnknown() {
		Assert.raises(function() {
			TestHarness.createTestReelSet({
				reels: 1,
				visibleCells: 1,
				symbolIds: ["a"],
				curve: 0.4,
				curveMode: "mesh"
			});
		});
	}

	public function testCurveBleedExpandsMaskOnlyInWarp() {
		var symbol = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a"],
			curve: 0.5,
			curveBleed: 24
		});
		Assert.floatEquals(0, symbol.reelSet.maskCrossBleed, 1e-9);
		Assert.floatEquals(0, symbol.reelSet.getReel(0).curveBleed, 1e-9);
		symbol.destroy();

		var warp = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a"],
			curve: 0.5,
			curveMode: "warp",
			curveBleed: 24
		});
		Assert.floatEquals(24, warp.reelSet.maskCrossBleed, 1e-9);
		Assert.floatEquals(24, warp.reelSet.getReel(0).curveBleed, 1e-9);
		Assert.floatEquals(24, warp.reelSet.getReel(0).warp.bleed, 1e-9);
		// Texture grows by bleed*2 on cross (vertical → width).
		Assert.isTrue(warp.reelSet.getReel(0).warp.textureWidth > 120);
		warp.destroy();
	}

	public function testCurveBleedRejectsNegative() {
		Assert.raises(function() {
			TestHarness.createTestReelSet({
				reels: 1,
				visibleCells: 1,
				symbolIds: ["a"],
				curve: 0.4,
				curveMode: "warp",
				curveBleed: -1
			});
		});
	}

	public function testWarpSetCurveVisualsIsNoop() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			visibleCells: 3,
			symbolIds: ["a"],
			curve: 0.6,
			curveMode: "warp"
		});
		var reel = h.reelSet.getReel(0);
		Assert.isTrue(reel.curveVisuals);
		reel.setCurveVisuals(false);
		Assert.isTrue(reel.curveVisuals);
		Assert.notNull(reel.warp);
		h.destroy();
	}

	public function testWarpTumbleLandStillCurved() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			tumble: true,
			tumbleInstant: true,
			curve: 0.45,
			curveMode: "warp",
			curveBleed: 16
		});
		for (i in 0...3) {
			Assert.isTrue(h.reelSet.getReel(i).warping);
			Assert.isTrue(h.reelSet.getReel(i).curveVisuals);
		}

		var landed = false;
		h.spinAndLand(
			[
				{visible: ["a", "b", "c"]},
				{visible: ["b", "c", "a"]},
				{visible: ["c", "a", "b"]}
			],
			function(_) {
				landed = true;
			}
		);
		Assert.isTrue(landed);
		for (i in 0...3) {
			var reel = h.reelSet.getReel(i);
			Assert.isTrue(reel.warping, 'reel $i lost warp after tumble land');
			Assert.isTrue(reel.curveVisuals, 'reel $i flattened after tumble land');
			Assert.notNull(reel.warp);
			Assert.isNull(reel.host.parent);
			Assert.notNull(reel.warp.view.parent);
		}
		TestHarness.expectGrid(h.reelSet, [
			{visible: ["a", "b", "c"]},
			{visible: ["b", "c", "a"]},
			{visible: ["c", "a", "b"]}
		]);
		h.destroy();
	}

	public function testWarpUpdateSurvivesTicks() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			visibleCells: 3,
			symbolIds: ["a", "b"],
			curve: 0.5,
			curveMode: "warp"
		});
		var warp = h.reelSet.getReel(0).warp;
		Assert.notNull(warp);
		h.advance(16);
		h.advance(16);
		Assert.isFalse(warp.isDestroyed);
		Assert.equals(h.reelSet.getReel(0).warp.view, warp.view);
		h.destroy();
		Assert.isTrue(warp.isDestroyed);
	}

	public function testWarpBounceDoesNotMoveMesh() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b"],
			curve: 0.5,
			curveMode: "warp",
			curveBleed: 24
		});
		var reel = h.reelSet.getReel(1);
		var warp = reel.warp;
		Assert.notNull(warp);
		var restX = warp.view.x;
		var restY = warp.view.y;
		Assert.floatEquals(reel.restHostMain, restY, 1e-9);
		Assert.floatEquals(reel.host.x, restX, 1e-9);

		reel.setHostMain(reel.restHostMain + 40);
		reel.updateWarp();
		Assert.floatEquals(restX, warp.view.x, 1e-9, "warp.view.x moved during bounce");
		Assert.floatEquals(restY, warp.view.y, 1e-9, "warp.view.y moved during bounce");
		Assert.floatEquals(reel.restHostMain + 40, reel.getHostMain(), 1e-9);

		reel.setHostMain(reel.restHostMain);
		reel.updateWarp();
		Assert.floatEquals(restX, warp.view.x, 1e-9);
		Assert.floatEquals(restY, warp.view.y, 1e-9);
		h.destroy();
	}
}
