package tests;

import reels.events.ReelEvents;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestGravityThenDrop extends Test {
	/** gravity events fire before dropIn; hold delays stage 2. */
	public function testTwoStageOrderAndHold() {
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

		var timeline:Array<String> = [];
		h.reelSet.events.on(ReelEvents.CASCADE_GRAVITY_START, function(_) timeline.push("gStart"));
		h.reelSet.events.on(ReelEvents.CASCADE_GRAVITY_END, function(_) timeline.push("gEnd"));
		h.reelSet.events.on(ReelEvents.CASCADE_DROPIN_START, function(_) timeline.push("dStart"));
		h.reelSet.events.on(ReelEvents.CASCADE_DROPIN_END, function(_) timeline.push("dEnd"));

		var holdFired = false;
		var gravCompleteFired = false;
		var done = false;
		var next = [
			{visible: ["b", "a", "a"]},
			{visible: ["c", "c", "c"]}
		];

		h.reelSet.refill({
			winners: [{reel: 0, cell: 1}, {reel: 0, cell: 2}],
			grid: next,
			mode: "gravity-then-drop",
			gravityHoldMs: 50,
			gravityHold: function() {
				holdFired = true;
				timeline.push("holdCb");
			},
			onGravityComplete: function() {
				gravCompleteFired = true;
				timeline.push("gravDone");
			}
		}, function(_) {
			done = true;
			timeline.push("refillDone");
		});

		// Stage 1 completes instantly (tumbleInstant); hold not done yet.
		h.clock.advance(1);
		Assert.isTrue(holdFired, "gravityHold fires at gravity-end");
		Assert.isFalse(gravCompleteFired, "onGravityComplete waits for hold");
		Assert.isFalse(done);

		var guard = 0;
		while (!done && guard < 40) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "two-stage refill should complete");
		Assert.isTrue(gravCompleteFired);

		// All gravity ends before any dropIn start.
		var firstDrop = timeline.indexOf("dStart");
		var lastGrav = -1;
		for (i in 0...timeline.length) {
			if (timeline[i] == "gEnd") lastGrav = i;
		}
		Assert.isTrue(firstDrop > lastGrav, 'gravity before dropIn: $timeline');
		Assert.isTrue(timeline.indexOf("holdCb") < timeline.indexOf("gravDone"));
		TestHarness.expectGrid(h.reelSet, next);
		h.destroy();
	}

	public function testRunCascadeForwardsTwoStage() {
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

		var sawGravity = 0;
		h.reelSet.events.on(ReelEvents.CASCADE_GRAVITY_END, function(_) sawGravity++);

		var next = [
			{visible: ["c", "c", "c"]},
			{visible: ["b", "b", "b"]}
		];
		var done = false;
		h.reelSet.runCascade({
			detectWinners: function(_, chain) {
				if (chain == 0) return [{reel: 0, cell: 0}, {reel: 0, cell: 1}, {reel: 0, cell: 2}];
				return [];
			},
			nextGrid: function(_, _, _) return next,
			pauseAfterDestroyMs: 0,
			destroyOptions: {durationMs: 0},
			refillMode: "gravity-then-drop",
			gravityHoldMs: 0
		}, function(summary) {
			done = true;
			Assert.equals(1, summary.chainLength);
		});

		var guard = 0;
		while (!done && guard < 200) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done);
		Assert.isTrue(sawGravity >= 2, 'expected gravity ends, got $sawGravity');
		TestHarness.expectGrid(h.reelSet, next);
		h.destroy();
	}

	public function testAutoSlamBypassesTwoStage() {
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
		h.reelSet.skipSpin();
		var guard = 0;
		while (!spinDone && guard < 40) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(spinDone);

		var gravityStarts = 0;
		h.reelSet.events.on(ReelEvents.CASCADE_GRAVITY_START, function(_) gravityStarts++);

		var next = [
			{visible: ["c", "c", "c"]},
			{visible: ["a", "a", "a"]}
		];
		var refillDone = false;
		h.reelSet.refill({
			winners: [{reel: 0, cell: 0}],
			grid: next,
			mode: "gravity-then-drop",
			gravityHoldMs: 500
		}, function(r) {
			refillDone = true;
			Assert.isTrue(r.wasSkipped);
		});
		h.clock.advance(1);
		Assert.isTrue(refillDone, "auto-slam should bypass two-stage hold");
		Assert.equals(0, gravityStarts);
		TestHarness.expectGrid(h.reelSet, next);
		h.destroy();
	}
}
