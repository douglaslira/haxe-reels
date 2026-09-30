package tests;

import reels.events.ReelEvents;
import reels.events.SpinResult;
import reels.frame.ColumnTarget;
import reels.testing.TestHarness;
import reels.testing.TestHarness.TestReelSetHandle;
import utest.Assert;
import utest.Test;

/**
 * Subset-spin via `SpinOptions.holdReels` — parity with pixi holdReels.test.ts.
 */
class TestHoldReels extends Test {
	static function grid5(
		a:String, b:String, c:String, d:String, e:String
	):Array<ColumnTarget> {
		return [
			{visible: [a, a, a]},
			{visible: [b, b, b]},
			{visible: [c, c, c]},
			{visible: [d, d, d]},
			{visible: [e, e, e]}
		];
	}

	static function wildAll():Array<ColumnTarget> {
		return [
			{visible: ["wild", "wild", "wild"]},
			{visible: ["wild", "wild", "wild"]},
			{visible: ["wild", "wild", "wild"]},
			{visible: ["wild", "wild", "wild"]},
			{visible: ["wild", "wild", "wild"]}
		];
	}

	static function makeHarness():TestReelSetHandle {
		return TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a", "b", "c", "d", "e", "wild"]
		});
	}

	static function spinAndLandWithHold(
		h:TestReelSetHandle,
		grid:Array<ColumnTarget>,
		holdReels:Array<Int>,
		onDone:SpinResult->Void
	):Void {
		var done = false;
		h.reelSet.spin({holdReels: holdReels}, function(result) {
			done = true;
			onDone(result);
		});
		h.reelSet.setResult(grid);
		h.reelSet.slamStop();
		var guard = 0;
		while (!done && guard < 200) {
			h.clock.advance(50);
			guard++;
		}
		if (!done) throw "spinAndLandWithHold: spin did not complete";
	}

	public function testHeldReelsKeepVisibleNonHeldLand() {
		var h = makeHarness();
		h.spinAndLand(grid5("a", "b", "c", "d", "e"), function(_) {});
		var before = h.reelSet.getVisibleGrid();

		spinAndLandWithHold(h, wildAll(), [0, 4], function(_) {});

		var after = h.reelSet.getVisibleGrid();
		Assert.same(before[0], after[0]);
		Assert.same(before[4], after[4]);
		Assert.same(["wild", "wild", "wild"], after[1]);
		Assert.same(["wild", "wild", "wild"], after[2]);
		Assert.same(["wild", "wild", "wild"], after[3]);
		h.destroy();
	}

	public function testSpinResultIncludesHeldCells() {
		var h = makeHarness();
		h.spinAndLand(grid5("a", "b", "c", "d", "e"), function(_) {});

		var result:Null<SpinResult> = null;
		spinAndLandWithHold(h, wildAll(), [2], function(r) {
			result = r;
		});

		Assert.notNull(result);
		Assert.same(["c", "c", "c"], result.symbols[2]);
		Assert.same(["wild", "wild", "wild"], result.symbols[0]);
		h.destroy();
	}

	public function testNoReelLandedEventForHeld() {
		var h = makeHarness();
		h.spinAndLand(grid5("a", "b", "c", "d", "e"), function(_) {});

		var landed:Array<Int> = [];
		h.reelSet.events.on(ReelEvents.SPIN_REEL_LANDED, function(args) {
			landed.push(Std.int(args[0]));
		});

		spinAndLandWithHold(h, grid5("a", "b", "c", "d", "e"), [1, 3], function(_) {});

		landed.sort(Reflect.compare);
		Assert.same([0, 2, 4], landed);
		h.destroy();
	}

	public function testAllLandedAndCompleteWithPartialHold() {
		var h = makeHarness();
		h.spinAndLand(grid5("a", "b", "c", "d", "e"), function(_) {});

		var log:Array<String> = [];
		h.reelSet.events.on(ReelEvents.SPIN_ALL_LANDED, function(_) log.push("allLanded"));
		h.reelSet.events.on(ReelEvents.SPIN_COMPLETE, function(_) log.push("complete"));

		spinAndLandWithHold(h, grid5("a", "b", "c", "d", "e"), [0, 1, 4], function(_) {});

		Assert.same(["allLanded", "complete"], log);
		h.destroy();
	}

	public function testAllHeldResolvesCurrentGrid() {
		var h = makeHarness();
		h.spinAndLand(grid5("a", "b", "c", "d", "e"), function(_) {});
		var before = h.reelSet.getVisibleGrid();

		var log:Array<String> = [];
		h.reelSet.events.on(ReelEvents.SPIN_START, function(_) log.push("start"));
		h.reelSet.events.on(ReelEvents.SPIN_REEL_LANDED, function(_) log.push("reelLanded"));
		h.reelSet.events.on(ReelEvents.SPIN_ALL_LANDED, function(_) log.push("allLanded"));

		var result:Null<SpinResult> = null;
		var done = false;
		h.reelSet.spin({holdReels: [0, 1, 2, 3, 4]}, function(r) {
			done = true;
			result = r;
		});
		var guard = 0;
		while (!done && guard < 20) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done);
		Assert.notNull(result);
		Assert.same(before, result.symbols);
		Assert.same(["start", "allLanded"], log);
		h.destroy();
	}

	public function testOutOfRangeAndDuplicateHoldIndicesFiltered() {
		var h = makeHarness();
		h.spinAndLand(grid5("a", "b", "c", "d", "e"), function(_) {});

		spinAndLandWithHold(h, wildAll(), [-1, 99, 2, 2, 7], function(_) {});

		var after = h.reelSet.getVisibleGrid();
		Assert.same(["c", "c", "c"], after[2]);
		Assert.same(["wild", "wild", "wild"], after[0]);
		Assert.same(["wild", "wild", "wild"], after[1]);
		Assert.same(["wild", "wild", "wild"], after[3]);
		Assert.same(["wild", "wild", "wild"], after[4]);
		h.destroy();
	}

	public function testAnticipationSkipsHeldIndices() {
		var h = makeHarness();
		h.spinAndLand(grid5("a", "b", "c", "d", "e"), function(_) {});

		// Apply anticipation before spin — haxe binds it at spin start.
		h.reelSet.setAnticipation([2, 3, 4]);
		spinAndLandWithHold(h, grid5("a", "b", "c", "d", "e"), [3], function(_) {});

		Assert.same(["d", "d", "d"], h.reelSet.getVisibleGrid()[3]);
		h.destroy();
	}
}
