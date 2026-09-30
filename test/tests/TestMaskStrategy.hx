package tests;

import openfl.display.Shape;
import openfl.geom.Rectangle;
import reels.ReelSetBuilder;
import reels.board.BoardGrid;
import reels.clock.FakeClock;
import reels.core.MaskContext;
import reels.core.MaskStrategy;
import reels.core.Orientation;
import reels.core.RectMaskStrategy;
import reels.core.ReelMaskRect;
import reels.core.SharedRectMaskStrategy;
import reels.symbols.HeadlessSymbol;
import utest.Assert;
import utest.Test;

/**
 * MaskStrategy parity — subset of pixi maskStrategy.test.ts.
 */
class TestMaskStrategy extends Test {
	static final RECTS:Array<ReelMaskRect> = [
		{x: 0, y: 0, width: 100, height: 300},
		{x: 100, y: 100, width: 100, height: 100},
		{x: 200, y: 0, width: 100, height: 300}
	];

	static function ctx(
		rects:Array<ReelMaskRect>,
		width:Float,
		height:Float,
		bleed:Float = 0
	):MaskContext {
		return {
			width: width,
			height: height,
			rects: rects,
			verticalMain: true,
			bleed: bleed
		};
	}

	static function boundsOf(g:Shape):{width:Float, height:Float} {
		var b:Rectangle = g.getBounds(g);
		return {width: b.width, height: b.height};
	}

	public function testRectDrawsUnionOfPerReelRects() {
		var strat = new RectMaskStrategy();
		var g = strat.build(ctx(RECTS, 300, 300));
		var b = boundsOf(g);
		Assert.equals(300., b.width);
		Assert.equals(300., b.height);
		strat.update(g, ctx(RECTS, 300, 300));
	}

	public function testRectFallsBackToBoundingBoxWhenNoRects() {
		var strat = new RectMaskStrategy();
		var g = strat.build(ctx([], 500, 500));
		var b = boundsOf(g);
		Assert.equals(500., b.width);
		Assert.equals(500., b.height);
	}

	public function testSharedRectIgnoresPerReelRects() {
		var strat = new SharedRectMaskStrategy();
		var g = strat.build(ctx(RECTS, 300, 300));
		var b = boundsOf(g);
		Assert.equals(300., b.width);
		Assert.equals(300., b.height);
		strat.update(g, ctx(RECTS, 300, 300));
	}

	public function testSharedRectInflatesCrossAxisByBleed() {
		var strat = new SharedRectMaskStrategy();
		var g = strat.build(ctx(RECTS, 300, 300, 40));
		var b = boundsOf(g);
		// verticalMain: bleed expands width, not height
		Assert.equals(380., b.width);
		Assert.equals(300., b.height);
	}

	public function testSharedRectSurvivesMissingBleed() {
		var strat = new SharedRectMaskStrategy();
		var legacy:MaskContext = {
			width: 300,
			height: 300,
			rects: RECTS,
			verticalMain: true
		};
		var b = boundsOf(strat.build(legacy));
		Assert.equals(300., b.width);
		Assert.equals(300., b.height);
	}

	public function testBuilderRejectsNullStrategy() {
		Assert.raises(function() {
			new ReelSetBuilder().maskStrategy(null);
		});
	}

	public function testBuilderRejectsWrongVersion() {
		Assert.raises(function() {
			new ReelSetBuilder().maskStrategy(new StaleMaskStrategy());
		});
	}

	public function testBuilderAcceptsSharedRect() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(1)
			.visibleCells(1)
			.symbolSize(40, 40)
			.clock(clock)
			.maskStrategy(new SharedRectMaskStrategy())
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
			})
			.build();
		Assert.isTrue(Std.isOfType(set.view, openfl.display.DisplayObject));
		set.destroy();
	}

	public function testBoardGridBuildsWithSharedRect() {
		var clock = new FakeClock();
		var grid = new BoardGrid({
			cols: 2,
			rows: 2,
			cellSize: 40,
			symbols: function(r) {
				r.register("a", function() return new HeadlessSymbol());
			},
			weights: ["a" => 1., "empty" => 1.],
			clock: clock
		});
		Assert.equals(4, grid.cells().length);
		grid.destroy();
	}

	public function testBuilderPopulatesPerReelMaskRects() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(5)
			.visibleCells(3)
			.symbolSize(80, 80)
			.symbolGap(4, 4)
			.clock(clock)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
			})
			.build();
		Assert.equals(5, set.viewport.maskRects.length);
		Assert.floatEquals(0, set.viewport.maskRects[0].x, 1e-9);
		Assert.floatEquals(84, set.viewport.maskRects[1].x, 1e-9);
		Assert.floatEquals(80, set.viewport.maskRects[0].width, 1e-9);
		Assert.isTrue(Std.isOfType(set.viewport.maskStrategy, RectMaskStrategy));
		set.destroy();
	}

	public function testBuilderHorizontalMaskRectsSwapAxes() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(4)
			.visibleCells(3)
			.symbolSize(80, 60)
			.symbolGap(0, 5)
			.orientation(Horizontal)
			.clock(clock)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
			})
			.build();
		Assert.equals(4, set.viewport.maskRects.length);
		// Cells along X → width = 3 * 80; reels stack on Y.
		Assert.floatEquals(240, set.viewport.maskRects[0].width, 1e-9);
		Assert.floatEquals(60, set.viewport.maskRects[0].height, 1e-9);
		Assert.floatEquals(0, set.viewport.maskRects[0].y, 1e-9);
		Assert.floatEquals(65, set.viewport.maskRects[1].y, 1e-9);
		Assert.floatEquals(0, set.getReel(0).host.x, 1e-9);
		Assert.floatEquals(0, set.getReel(0).host.y, 1e-9);
		Assert.floatEquals(65, set.getReel(1).host.y, 1e-9);
		set.destroy();
	}

	public function testBuilderMultiWaysMaskRectsUseReelExtent() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(3)
			.symbolSize(50, 50)
			.symbolGap(2, 0)
			.multiways({minCells: 2, maxCells: 4, reelExtent: 220})
			.clock(clock)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
			})
			.build();
		Assert.equals(3, set.viewport.maskRects.length);
		Assert.floatEquals(220, set.viewport.maskRects[0].height, 1e-9);
		set.destroy();
	}

	public function testAutoPickSharedRectOnCurveFocusSet() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(3)
			.visibleCells(3)
			.symbolSize(60, 60)
			.curve(0.5)
			.curveFocus("set")
			.clock(clock)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
			})
			.build();
		Assert.isTrue(Std.isOfType(set.viewport.maskStrategy, SharedRectMaskStrategy));
		Assert.equals(3, set.viewport.maskRects.length);
		set.destroy();
	}

	public function testExplicitMaskStrategyWinsOverAutoPick() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(3)
			.visibleCells(3)
			.symbolSize(60, 60)
			.curve(0.5)
			.curveFocus("set")
			.maskStrategy(new RectMaskStrategy())
			.clock(clock)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
			})
			.build();
		Assert.isTrue(Std.isOfType(set.viewport.maskStrategy, RectMaskStrategy));
		Assert.equals(3, set.viewport.maskRects.length);
		set.destroy();
	}

	public function testCurveFocusReelDoesNotAutoPick() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(3)
			.visibleCells(3)
			.symbolSize(60, 60)
			.curve(0.5)
			.curveFocus("reel")
			.clock(clock)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
			})
			.build();
		Assert.isTrue(Std.isOfType(set.viewport.maskStrategy, RectMaskStrategy));
		set.destroy();
	}
}

/** Declares version 1 — builder must reject. */
private class StaleMaskStrategy implements MaskStrategy {
	public function new() {}

	public var version(get, never):Int;

	function get_version():Int {
		return 1;
	}

	public function build(ctx:MaskContext):Shape {
		return new Shape();
	}

	public function update(shape:Shape, ctx:MaskContext):Void {}
}
