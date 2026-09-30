package tests;

import reels.events.ReelEvents;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestDestroyAndCascade extends Test {
	public function testDestroySymbolsEmitsAndClearsAlpha() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			tumble: true,
			bufferSymbols: 1,
			initialFrame: [
				{visible: ["a", "b", "c"]},
				{visible: ["c", "c", "c"]}
			]
		});

		var started = 0;
		var ended = 0;
		h.reelSet.events.on(ReelEvents.CASCADE_DESTROY_START, function(_) started++);
		h.reelSet.events.on(ReelEvents.CASCADE_DESTROY_END, function(_) ended++);

		var done = false;
		var cells = [{reel: 0, cell: 1}, {reel: 0, cell: 2}];
		h.reelSet.destroySymbols(cells, {durationMs: 50, staggerMs: 0}, function() {
			done = true;
		});

		var guard = 0;
		while (!done && guard < 40) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "destroySymbols should complete");
		Assert.equals(1, started);
		Assert.equals(1, ended);
		Assert.equals(0., h.reelSet.getReel(0).getVisibleSymbol(1).alpha);
		Assert.equals(0., h.reelSet.getReel(0).getVisibleSymbol(2).alpha);
		Assert.equals(1., h.reelSet.getReel(0).getVisibleSymbol(0).alpha);
		h.destroy();
	}

	public function testRunCascadeOneChainThenIdle() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			tumble: true,
			bufferSymbols: 1,
			initialFrame: [
				{visible: ["a", "a", "a"]},
				{visible: ["b", "b", "b"]}
			]
		});

		// Instant drop for fast FakeClock tests
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

		var next = [
			{visible: ["c", "c", "c"]},
			{visible: ["b", "b", "b"]}
		];
		var detectCalls = 0;
		var done = false;
		var summaryChain = -1;
		var summaryWins = -1;

		h.reelSet.runCascade({
			detectWinners: function(grid, chain) {
				detectCalls++;
				if (chain == 0) return [{reel: 0, cell: 0}, {reel: 0, cell: 1}, {reel: 0, cell: 2}];
				return [];
			},
			nextGrid: function(_, _, _) return next,
			pauseAfterDestroyMs: 0,
			destroyOptions: {durationMs: 0}
		}, function(summary) {
			done = true;
			summaryChain = summary.chainLength;
			summaryWins = summary.totalWinners;
			Assert.isFalse(summary.wasSkipped);
		});

		var guard = 0;
		while (!done && guard < 200) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "runCascade should complete");
		Assert.equals(1, summaryChain);
		Assert.equals(3, summaryWins);
		Assert.isTrue(detectCalls >= 2, 'detectCalls $detectCalls');
		TestHarness.expectGrid(h.reelSet, next);
		h.destroy();
	}

	public function testAutoSlamRefillsAfterSkip() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			tumble: true,
			bufferSymbols: 1,
			initialFrame: [
				{visible: ["a", "b", "c"]},
				{visible: ["c", "c", "c"]}
			]
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

		var spinDone = false;
		h.reelSet.spin(function(_) spinDone = true);
		h.reelSet.setResult([
			{visible: ["a", "a", "a"]},
			{visible: ["b", "b", "b"]}
		]);
		// Skip mid-spin → sets _autoSlamRefills
		h.reelSet.skipSpin();
		var guard = 0;
		while (!spinDone && guard < 40) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(spinDone);

		var next = [
			{visible: ["c", "c", "c"]},
			{visible: ["a", "a", "a"]}
		];
		var refillDone = false;
		var wasSkipped = false;
		h.reelSet.refill({
			winners: [{reel: 0, cell: 0}],
			grid: next
		}, function(r) {
			refillDone = true;
			wasSkipped = r.wasSkipped;
		});
		// Auto-slam should finish without needing many frames of dropIn
		h.clock.advance(1);
		Assert.isTrue(refillDone, "auto-slam refill should land immediately");
		Assert.isTrue(wasSkipped);
		TestHarness.expectGrid(h.reelSet, next);
		h.destroy();
	}
}
