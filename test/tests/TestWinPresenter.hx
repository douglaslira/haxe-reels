package tests;

import reels.config.WinTypes.SymbolPosition;
import reels.config.WinTypes.Win;
import reels.events.ReelEvents;
import reels.frame.ColumnTarget;
import reels.testing.TestHarness;
import reels.wins.WinPresenter;
import reels.wins.WinSort;
import utest.Assert;
import utest.Test;

class TestWinPresenter extends Test {
	static function cell(r:Int, c:Int):SymbolPosition {
		return {reelIndex: r, cellIndex: c};
	}

	static function mkWin(cells:Array<SymbolPosition>, ?value:Float, ?id:Int):Win {
		return {cells: cells, value: value, id: id};
	}

	static function flatGrid(reels:Int):Array<ColumnTarget> {
		return [for (_ in 0...reels) ({visible: ["a", "a", "a"]}:ColumnTarget)];
	}

	public function testSortByValueDesc() {
		var a = mkWin([cell(0, 0)], 10, 1);
		var b = mkWin([cell(1, 0)], 50, 2);
		var c = mkWin([cell(2, 0)], null, 3);
		var d = mkWin([cell(3, 0)], 25, 4);
		var input = [a, b, c, d];
		var out = WinSort.sortByValueDesc(input);
		Assert.same([2, 4, 1, 3], [for (w in out) w.id]);
		Assert.same([1, 2, 3, 4], [for (w in input) w.id]);
	}

	public function testEventOrder() {
		var h = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a", "b"]
		});
		var log:Array<String> = [];
		h.reelSet.events.on(ReelEvents.WIN_START, function(args) {
			var wins:Array<Win> = args[0];
			log.push('start:${wins.length}');
		});
		h.reelSet.events.on(ReelEvents.WIN_GROUP, function(args) {
			var w:Win = args[0];
			log.push('group:${w.id}');
		});
		h.reelSet.events.on(ReelEvents.WIN_SYMBOL, function(args) {
			var c:SymbolPosition = args[1];
			log.push('sym:${c.reelIndex},${c.cellIndex}');
		});
		h.reelSet.events.on(ReelEvents.WIN_END, function(args) {
			log.push('end:${args[0]}');
		});

		h.spinAndLand(flatGrid(5), function(_) {});
		var p = new WinPresenter(h.reelSet, {cycleGap: 0});
		var done = false;
		p.show([mkWin([cell(0, 0), cell(1, 0), cell(2, 0)], 10, 7)], function() done = true);
		h.advance(50);
		Assert.isTrue(done);
		Assert.same([
			"start:1",
			"group:7",
			"sym:0,0",
			"sym:1,0",
			"sym:2,0",
			"end:complete"
		], log);
		p.destroy();
		h.destroy();
	}

	public function testSortsByValueDescending() {
		var h = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a"]
		});
		var order:Array<Dynamic> = [];
		h.reelSet.events.on(ReelEvents.WIN_GROUP, function(args) {
			var w:Win = args[0];
			order.push(w.id);
		});
		h.spinAndLand(flatGrid(5), function(_) {});
		var p = new WinPresenter(h.reelSet, {cycleGap: 0});
		var done = false;
		p.show([
			mkWin([cell(0, 0)], 10, 1),
			mkWin([cell(0, 1)], 50, 2),
			mkWin([cell(0, 2)], 25, 3)
		], function() done = true);
		h.advance(100);
		Assert.isTrue(done);
		Assert.same([2, 3, 1], order);
		p.destroy();
		h.destroy();
	}

	public function testDimsLosersAndRestores() {
		var h = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a"]
		});
		var winnerAlpha = -1.;
		var loserAlpha = -1.;
		h.reelSet.events.on(ReelEvents.WIN_GROUP, function(_) {
			winnerAlpha = h.reelSet.getReel(0).getSymbolAt(1).alpha;
			loserAlpha = h.reelSet.getReel(0).getSymbolAt(0).alpha;
		});
		h.spinAndLand(flatGrid(5), function(_) {});
		var p = new WinPresenter(h.reelSet, {dimLosersAlpha: 0.2, cycleGap: 0});
		var done = false;
		p.show([
			mkWin([cell(0, 1), cell(1, 1), cell(2, 1), cell(3, 1), cell(4, 1)], 10)
		], function() done = true);
		h.advance(50);
		Assert.isTrue(done);
		Assert.floatEquals(1, winnerAlpha, 0.001);
		Assert.floatEquals(0.2, loserAlpha, 0.001);
		for (r in 0...5) {
			for (c in 0...3) {
				Assert.floatEquals(1, h.reelSet.getReel(r).getSymbolAt(c).alpha, 0.001);
			}
		}
		p.destroy();
		h.destroy();
	}

	public function testDimLosersFalse() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a"]
		});
		var loserAlpha = -1.;
		h.reelSet.events.on(ReelEvents.WIN_GROUP, function(_) {
			loserAlpha = h.reelSet.getReel(0).getSymbolAt(0).alpha;
		});
		h.spinAndLand(flatGrid(3), function(_) {});
		var p = new WinPresenter(h.reelSet, {dimLosers: false, cycleGap: 0});
		p.show([mkWin([cell(0, 1)], 10)]);
		h.advance(20);
		Assert.floatEquals(1, loserAlpha, 0.001);
		p.destroy();
		h.destroy();
	}

	public function testAbortEmitsAborted() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a"]
		});
		var endReason = "";
		h.reelSet.events.on(ReelEvents.WIN_END, function(args) endReason = Std.string(args[0]));
		h.spinAndLand(flatGrid(3), function(_) {});
		var p = new WinPresenter(h.reelSet, {cycleGap: 200, cycles: -1});
		p.show([mkWin([cell(0, 0)], 1)]);
		h.advance(16);
		p.abort();
		h.advance(50);
		Assert.equals("aborted", endReason);
		p.destroy();
		h.destroy();
	}

	public function testStaggerDelaysSymbols() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a"]
		});
		var times:Array<Float> = [];
		h.reelSet.events.on(ReelEvents.WIN_SYMBOL, function(_) {
			times.push(h.clock.elapsedMs);
		});
		h.spinAndLand(flatGrid(3), function(_) {});
		var p = new WinPresenter(h.reelSet, {stagger: 40, cycleGap: 0});
		var done = false;
		p.show([mkWin([cell(0, 0), cell(1, 0), cell(2, 0)], 1)], function() done = true);
		h.advance(200);
		Assert.isTrue(done);
		Assert.equals(3, times.length);
		// Stagger spaces WIN_SYMBOL across clock ticks (not all in one frame).
		Assert.isTrue(times[1] > times[0], 't1=${times[1]} t0=${times[0]}');
		Assert.isTrue(times[2] > times[1], 't2=${times[2]} t1=${times[1]}');
		p.destroy();
		h.destroy();
	}

	public function testEmptyWinsNoEvents() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a"]
		});
		var started = false;
		h.reelSet.events.on(ReelEvents.WIN_START, function(_) started = true);
		var p = new WinPresenter(h.reelSet);
		var done = false;
		p.show([], function() done = true);
		Assert.isTrue(done);
		Assert.isFalse(started);
		p.destroy();
		h.destroy();
	}
}
