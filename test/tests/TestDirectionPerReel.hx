package tests;

import reels.ReelSetBuilder;
import reels.clock.FakeClock;
import reels.config.SpeedPresets;
import reels.core.Direction;
import reels.events.ReelEvents;
import reels.symbols.HeadlessSymbol;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestDirectionPerReel extends Test {
	public function testDirectionPerReelAssignsAxes() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			directionPerReel: [Forward, Reverse, Forward]
		});
		Assert.equals(Forward, h.reelSet.getReel(0).axis.direction);
		Assert.equals(Reverse, h.reelSet.getReel(1).axis.direction);
		Assert.equals(Forward, h.reelSet.getReel(2).axis.direction);
		Assert.equals(1, h.reelSet.getReel(0).axisPolarity());
		Assert.equals(-1, h.reelSet.getReel(1).axisPolarity());
		h.destroy();
	}

	public function testDirectionPerReelLengthMismatchThrows() {
		var clock = new FakeClock();
		Assert.raises(function() {
			new ReelSetBuilder()
				.reels(3)
				.visibleCells(3)
				.symbolSize(100, 100)
				.clock(clock)
				.directionPerReel([Forward, Reverse])
				.symbols(function(r) {
					r.register("a", function() return new HeadlessSymbol());
				})
				.speed("normal", SpeedPresets.NORMAL)
				.build();
		});
		clock.destroy();
	}

	public function testMixedDirectionsStandardSpinLands() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			directionPerReel: [Forward, Reverse, Forward],
			bufferSymbols: 1
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

		var grid = [
			{visible: ["a", "a", "a"]},
			{visible: ["b", "b", "b"]},
			{visible: ["c", "c", "c"]}
		];
		var done = false;
		h.reelSet.spin(function(_) done = true);
		h.reelSet.setResult(grid);
		var guard = 0;
		while (!done && guard < 200) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "mixed-direction spin should complete");
		TestHarness.expectGrid(h.reelSet, grid);
		h.destroy();
	}

	public function testMixedDirectionsCascadeSpinLands() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			directionPerReel: [Reverse, Forward, Reverse],
			tumble: true,
			bufferSymbols: 1
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

		var sawFall = 0;
		h.reelSet.events.on(ReelEvents.CASCADE_FALL_END, function(_) sawFall++);

		var grid = [
			{visible: ["a", "b", "c"]},
			{visible: ["c", "c", "c"]},
			{visible: ["b", "a", "b"]}
		];
		var done = false;
		h.reelSet.spin(function(_) done = true);
		h.reelSet.setResult(grid);
		var guard = 0;
		while (!done && guard < 200) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "mixed-direction cascade should complete");
		Assert.isTrue(sawFall >= 3, 'fall events $sawFall');
		TestHarness.expectGrid(h.reelSet, grid);
		// Reverse reels keep reverse polarity through tumble.
		Assert.equals(Reverse, h.reelSet.getReel(0).axis.direction);
		Assert.equals(Forward, h.reelSet.getReel(1).axis.direction);
		h.destroy();
	}

	public function testMixedDirectionsRefillCombined() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			directionPerReel: [Forward, Reverse],
			tumble: true,
			bufferSymbols: 1,
			initialFrame: [
				{visible: ["a", "b", "c"]},
				{visible: ["c", "c", "c"]}
			]
		});

		var next = [
			{visible: ["b", "a", "a"]},
			{visible: ["a", "b", "c"]}
		];
		var done = false;
		h.reelSet.refill({
			winners: [{reel: 0, cell: 1}, {reel: 0, cell: 2}],
			grid: next,
			mode: "combined"
		}, function(_) done = true);

		var guard = 0;
		while (!done && guard < 100) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done);
		TestHarness.expectGrid(h.reelSet, next);
		h.destroy();
	}
}
