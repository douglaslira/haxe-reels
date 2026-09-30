package tests;

import reels.ReelSetBuilder;
import reels.clock.FakeClock;
import reels.config.SpeedPresets;
import reels.events.ReelEvents;
import reels.symbols.HeadlessSymbol;
import reels.util.AbortToken;
import utest.Assert;
import utest.Test;

class TestNudge extends Test {
	function build(clock:FakeClock) {
		return new ReelSetBuilder()
			.reels(1)
			.visibleCells(3)
			.bufferSymbols(1)
			.symbolSize(80, 80)
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
				r.register("b", function() return new HeadlessSymbol());
				r.register("WILD", function() return new HeadlessSymbol());
			})
			.weights(["a" => 1., "b" => 1., "WILD" => 1.])
			.initialFrame([{visible: ["a", "a", "a"]}])
			.build();
	}

	public function testNudgeShiftsVisibleColumn() {
		var clock = new FakeClock();
		var set = build(clock);
		var done = false;
		var ids:Array<String> = null;
		set.nudge(0, {
			distance: 1,
			direction: "forward",
			incoming: ["WILD"],
			duration: 100
		}, function(symbols) {
			done = true;
			ids = symbols;
		});
		clock.advance(120);
		Assert.isTrue(done);
		Assert.equals("WILD", ids[0]);
		set.destroy();
	}

	public function testSkipNudgeLandsImmediately() {
		var clock = new FakeClock();
		var set = build(clock);
		var done = false;
		set.nudge(0, {
			distance: 1,
			direction: "forward",
			incoming: ["b"],
			duration: 5000
		}, function(_) done = true);
		Assert.isFalse(done);
		set.skipNudge(0);
		Assert.isTrue(done);
		Assert.equals("b", set.getReel(0).getVisibleIds()[0]);
		set.destroy();
	}

	public function testAbortCancels() {
		var clock = new FakeClock();
		var set = build(clock);
		var cancelled = false;
		var token = new AbortToken();
		set.events.on(ReelEvents.NUDGE_CANCELLED, function(_) cancelled = true);
		set.nudge(0, {
			distance: 1,
			direction: "forward",
			incoming: ["WILD"],
			duration: 5000,
			abort: token
		});
		clock.advance(16);
		token.abort();
		Assert.isTrue(cancelled);
		set.destroy();
	}

	public function testBlocksSpinWhileNudging() {
		var clock = new FakeClock();
		var set = build(clock);
		set.nudge(0, {
			distance: 1,
			direction: "forward",
			incoming: ["WILD"],
			duration: 5000
		});
		Assert.raises(function() set.spin());
		set.skipNudge();
		set.destroy();
	}

	public function testRejectsPinOverlap() {
		var clock = new FakeClock();
		var set = build(clock);
		set.pin(0, 1, "WILD");
		Assert.raises(function() {
			set.nudge(0, {
				distance: 1,
				direction: "forward",
				incoming: ["b"]
			});
		});
		set.destroy();
	}

	public function testEmitsStartAndComplete() {
		var clock = new FakeClock();
		var set = build(clock);
		var started = false;
		var completed = false;
		set.events.on(ReelEvents.NUDGE_START, function(_) started = true);
		set.events.on(ReelEvents.NUDGE_COMPLETE, function(_) completed = true);
		set.nudge(0, {
			distance: 1,
			direction: "forward",
			incoming: ["WILD"],
			duration: 50
		});
		Assert.isTrue(started);
		clock.advance(80);
		Assert.isTrue(completed);
		set.destroy();
	}

	public function testRejectsIncomingBig() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(1)
			.visibleCells(3)
			.bufferSymbols(1)
			.symbolSize(40, 40)
			.clock(clock)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
				r.register("BIG", function() return new HeadlessSymbol(), {
					size: {reels: 1, cells: 2}
				});
			})
			.initialFrame([{visible: ["a", "a", "a"]}])
			.build();
		Assert.raises(function() {
			set.nudge(0, {
				distance: 1,
				direction: "forward",
				incoming: ["BIG"]
			});
		});
		set.destroy();
	}

	public function testTallBlockSurvivesShortNudge() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(1)
			.visibleCells(3)
			.bufferSymbols(1)
			.symbolSize(40, 40)
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
				r.register("TALL", function() return new HeadlessSymbol(), {
					size: {reels: 1, cells: 2}
				});
			})
			.weights(["a" => 1., "TALL" => 0.])
			.initialFrame([{visible: ["TALL", "a", "a"]}])
			.build();
		// Force coordinated land so OCCUPIED is on strip
		set.spin();
		set.setResult([{visible: ["TALL", "a", "a"]}]);
		set.slamStop();
		clock.advance(2000);

		var done = false;
		set.nudge(0, {
			distance: 1,
			direction: "reverse",
			incoming: ["a"],
			duration: 80
		}, function(_) done = true);
		clock.advance(120);
		Assert.isTrue(done);
		Assert.equals("TALL", set.getReel(0).getVisibleIds()[0]);
		set.destroy();
	}
}
