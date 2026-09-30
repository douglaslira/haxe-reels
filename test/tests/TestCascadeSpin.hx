package tests;

import reels.config.SpeedPresets;
import reels.events.ReelEvents;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestCascadeSpin extends Test {
	/** Moment A: tumble spin lands the setResult grid. */
	public function testCascadeSpinLandsGrid() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			tumble: true,
			bufferSymbols: 1
		});
		Assert.isTrue(h.reelSet.isCascade);

		// Fast spin wait
		h.reelSet.speed.addProfile({
			name: "fast",
			spinDelay: 0,
			spinSpeed: 30,
			stopDelay: 0,
			anticipationDelay: 0,
			bounceDistance: 0,
			bounceDuration: 1,
			accelerationEase: "linear",
			decelerationEase: "linear",
			accelerationDuration: 1,
			minimumSpinTime: 0
		});
		h.reelSet.setSpeed("fast");

		var grid = [
			{visible: ["a", "a", "a"]},
			{visible: ["b", "b", "b"]},
			{visible: ["c", "c", "c"]}
		];
		var done = false;
		var sawFall = 0;
		var sawPlace = 0;
		var sawDrop = 0;
		h.reelSet.events.on(ReelEvents.CASCADE_FALL_END, function(_) sawFall++);
		h.reelSet.events.on(ReelEvents.CASCADE_PLACE_END, function(_) sawPlace++);
		h.reelSet.events.on(ReelEvents.CASCADE_DROPIN_END, function(_) sawDrop++);

		h.reelSet.spin(function(_) done = true);
		h.reelSet.setResult(grid);
		var guard = 0;
		while (!done && guard < 200) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "cascade spin should complete");
		Assert.isTrue(sawFall >= 3, 'fall events $sawFall');
		Assert.isTrue(sawPlace >= 3, 'place events $sawPlace');
		Assert.isTrue(sawDrop >= 3, 'dropIn events $sawDrop');
		TestHarness.expectGrid(h.reelSet, grid);
		h.destroy();
	}

	/**
	 * curve + tumble must keep projection on for the whole spin
	 * (old fall/drop-in called setCurveVisuals(false) → flat flash).
	 */
	public function testCascadeSpinKeepsCurveProjection() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			tumble: true,
			tumbleInstant: false,
			bufferSymbols: 1,
			curve: 0.4
		});
		h.reelSet.speed.addProfile({
			name: "fast",
			spinDelay: 0,
			spinSpeed: 30,
			stopDelay: 0,
			anticipationDelay: 0,
			bounceDistance: 0,
			bounceDuration: 1,
			accelerationEase: "linear",
			decelerationEase: "linear",
			accelerationDuration: 1,
			minimumSpinTime: 0
		});
		h.reelSet.setSpeed("fast");

		Assert.isTrue(h.reelSet.getReel(0).curveVisuals);
		Assert.notNull(h.reelSet.getReel(0).curve);

		var done = false;
		h.reelSet.spin(function(_) done = true);
		h.reelSet.setResult([
			{visible: ["a", "a", "a"]},
			{visible: ["b", "b", "b"]},
			{visible: ["c", "c", "c"]}
		]);
		var guard = 0;
		while (!done && guard < 400) {
			for (i in 0...3) {
				Assert.isTrue(
					h.reelSet.getReel(i).curveVisuals,
					'reel $i lost curve mid-tumble (tick $guard)'
				);
			}
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "cascade spin should complete");
		Assert.isTrue(h.reelSet.getReel(0).curveVisuals);
		h.destroy();
	}
}
