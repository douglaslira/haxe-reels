package tests;

import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestRefillCombined extends Test {
	/** Moment B: refill with winners updates grid; idle reel (no winners) stays put. */
	public function testRefillCombinedPlacesGrid() {
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

		var next = [
			{visible: ["b", "a", "a"]},
			{visible: ["c", "c", "c"]}
		];
		var done = false;
		var placeCount = 0;
		h.reelSet.events.on("cascade:place:end", function(_) placeCount++);

		h.reelSet.refill({
			winners: [{reel: 0, cell: 1}, {reel: 0, cell: 2}],
			grid: next,
			mode: "combined"
		}, function(result) {
			done = true;
			Assert.equals(2, result.winnersRefilled);
			Assert.isFalse(result.wasSkipped);
		});

		var guard = 0;
		while (!done && guard < 100) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "refill should complete");
		Assert.equals(2, placeCount);
		TestHarness.expectGrid(h.reelSet, next);
		h.destroy();
	}

	public function testRefillRequiresTumble() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"]
		});
		Assert.raises(function() {
			h.reelSet.refill({
				winners: [],
				grid: [{visible: ["a", "a", "a"]}]
			}, function(_) {});
		});
		h.destroy();
	}
}
