package reels.testing;

import reels.ReelSet;
import reels.ReelSetBuilder;
import reels.clock.FakeClock;
import reels.config.SpeedPresets;
import reels.core.Direction;
import reels.core.Orientation;
import reels.events.SpinResult;
import reels.frame.ColumnTarget;
import reels.symbols.HeadlessSymbol;
import utest.Assert;

typedef TestReelSetOptions = {
	?reels:Int,
	?visibleCells:Int,
	?symbolIds:Array<String>,
	?weights:Map<String, Float>,
	?symbolWidth:Float,
	?symbolHeight:Float,
	?bufferSymbols:Int,
	?orientation:Orientation,
	?direction:Direction,
	?directionPerReel:Array<Direction>,
	?curve:Dynamic,
	?curvePerReel:Array<Dynamic>,
	?curveFocus:String,
	?curveMode:String,
	?curveBleed:Float,
	?initialFrame:Array<ColumnTarget>,
	?tumble:Bool,
	?tumbleInstant:Bool,
	?multiways:{minCells:Int, maxCells:Int, reelExtent:Float},
	?adjustDurationMs:Float
};

typedef TestReelSetHandle = {
	reelSet:ReelSet,
	clock:FakeClock,
	advance:Float->Void,
	spinAndLand:Array<ColumnTarget>->(SpinResult->Void)->Void,
	destroy:() -> Void
};

/**
 * Headless ReelSet + FakeClock for mechanic tests.
 */
class TestHarness {
	public static function createTestReelSet(?opts:TestReelSetOptions):TestReelSetHandle {
		if (opts == null) opts = {};
		var reels = opts.reels != null ? opts.reels : 5;
		var visible = opts.visibleCells != null ? opts.visibleCells : 3;
		var ids = opts.symbolIds != null ? opts.symbolIds : ["a", "b", "c"];
		var w = opts.symbolWidth != null ? opts.symbolWidth : 120;
		var h = opts.symbolHeight != null ? opts.symbolHeight : 100;
		var clock = new FakeClock();

		var builder = new ReelSetBuilder()
			.reels(reels)
			.symbolSize(w, h)
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.speed("turbo", SpeedPresets.TURBO)
			.symbols(function(r) {
				for (id in ids) {
					r.register(id, function() return new HeadlessSymbol());
				}
			});

		if (opts.multiways != null) {
			builder.multiways(opts.multiways);
			if (opts.adjustDurationMs != null) builder.adjustDuration(opts.adjustDurationMs);
		} else {
			builder.visibleCells(visible);
		}

		if (opts.weights != null) builder.weights(opts.weights);
		if (opts.bufferSymbols != null) builder.bufferSymbols(opts.bufferSymbols);
		if (opts.orientation != null) builder.orientation(opts.orientation);
		if (opts.direction != null) builder.direction(opts.direction);
		if (opts.directionPerReel != null) builder.directionPerReel(opts.directionPerReel);
		if (opts.curvePerReel != null) builder.curvePerReel(opts.curvePerReel);
		else if (opts.curve != null) builder.curve(opts.curve);
		if (opts.curveFocus != null) builder.curveFocus(opts.curveFocus);
		if (opts.curveMode != null) builder.curveMode(opts.curveMode);
		if (opts.curveBleed != null) builder.curveBleed(opts.curveBleed);
		if (opts.initialFrame != null) builder.initialFrame(opts.initialFrame);
		if (opts.tumble == true) {
			var instant = opts.tumbleInstant != false;
			builder.tumble(instant ? {
				fall: {duration: 0, cellStagger: 0},
				dropIn: {duration: 0, cellStagger: 0}
			} : null);
		}

		// Deterministic filler for tests
		builder.rng(function() return 0.5);

		var reelSet = builder.build();

		function advance(ms:Float):Void {
			clock.advance(ms);
		}

		function spinAndLand(grid:Array<ColumnTarget>, onDone:SpinResult->Void):Void {
			var done = false;
			reelSet.spin(function(result) {
				done = true;
				onDone(result);
			});
			reelSet.setResult(grid);
			reelSet.slamStop();
			// Drive clock until complete (slam should finish synchronously on next ticks)
			var guard = 0;
			while (!done && guard < 200) {
				clock.advance(50);
				guard++;
			}
			if (!done) throw "spinAndLand: spin did not complete";
		}

		return {
			reelSet: reelSet,
			clock: clock,
			advance: advance,
			spinAndLand: spinAndLand,
			destroy: function() {
				reelSet.destroy();
				clock.destroy();
			}
		};
	}

	public static function expectGrid(reelSet:ReelSet, expected:Array<ColumnTarget>):Void {
		var actual = reelSet.getVisibleGrid();
		Assert.equals(expected.length, actual.length, 'reel count');
		for (c in 0...expected.length) {
			var exp = expected[c].visible;
			var act = actual[c];
			Assert.equals(exp.length, act.length, 'column $c length');
			for (r in 0...exp.length) {
				Assert.equals(exp[r], act[r], '[$c][$r]');
			}
		}
	}
}
