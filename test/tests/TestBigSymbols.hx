package tests;

import reels.ReelSetBuilder;
import reels.clock.FakeClock;
import reels.config.SpeedPresets;
import reels.core.Orientation;
import reels.symbols.BigSymbolCoord;
import reels.symbols.HeadlessSymbol;
import reels.symbols.OccupiedStub;
import utest.Assert;
import utest.Test;

class TestBigSymbols extends Test {
	public function testCoordinatePaintsOccupied() {
		var grid = [
			{visible: ["BIG", "a", "a"]},
			{visible: ["a", "a", "a"]}
		];
		var out = BigSymbolCoord.coordinate(
			grid,
			function(id) return id == "BIG" ? {reels: 2, cells: 2} : BigSymbolCoord.unit(),
			function(_) return 3
		);
		Assert.equals("BIG", out[0].visible[0]);
		Assert.equals(OccupiedStub.SENTINEL, out[0].visible[1]);
		Assert.equals(OccupiedStub.SENTINEL, out[1].visible[0]);
		Assert.equals(OccupiedStub.SENTINEL, out[1].visible[1]);
		Assert.equals("a", out[0].visible[2]);
	}

	public function testCoordinateThrowsOnOverflow() {
		Assert.raises(function() {
			BigSymbolCoord.coordinate(
				[{visible: ["BIG", "a"]}],
				function(id) return id == "BIG" ? {reels: 1, cells: 3} : BigSymbolCoord.unit(),
				function(_) return 2
			);
		});
	}

	public function testCoordinatePaintsBufferEndSpill() {
		var grid = [{
			visible: ["a", "a", "BIG"],
			bufferEnd: ["x"]
		}];
		var out = BigSymbolCoord.coordinate(
			grid,
			function(id) return id == "BIG" ? {reels: 1, cells: 2} : BigSymbolCoord.unit(),
			function(_) return 3,
			0,
			1
		);
		Assert.equals("BIG", out[0].visible[2]);
		Assert.equals(OccupiedStub.SENTINEL, out[0].bufferEnd[0]);
	}

	public function testCoordinateAnchorInBufferStart() {
		var grid = [{
			visible: ["a", "a", "a"],
			bufferStart: ["BIG"]
		}];
		// BIG 1x2 at cell=-1 spills into visible[0]
		var out = BigSymbolCoord.coordinate(
			grid,
			function(id) return id == "BIG" ? {reels: 1, cells: 2} : BigSymbolCoord.unit(),
			function(_) return 3,
			1,
			0
		);
		Assert.equals("BIG", out[0].bufferStart[0]);
		Assert.equals(OccupiedStub.SENTINEL, out[0].visible[0]);
	}

	public function testSetResultResolvesVisibleIdsAndFootprint() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(2)
			.visibleCells(3)
			.symbolSize(40, 40)
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
				r.register("BIG", function() return new HeadlessSymbol(), {
					size: {reels: 2, cells: 2}
				});
			})
			.weights(["a" => 1., "BIG" => 0.])
			.initialFrame([
				{visible: ["a", "a", "a"]},
				{visible: ["a", "a", "a"]}
			])
			.build();

		set.spin();
		set.setResult([
			{visible: ["BIG", "a", "a"]},
			{visible: ["a", "a", "a"]}
		]);
		// Slam to land
		set.slamStop();
		clock.advance(2000);

		var ids0 = set.getReel(0).getVisibleIds();
		Assert.equals("BIG", ids0[0]);
		Assert.equals("BIG", ids0[1]);
		Assert.equals(0, set.getReel(0).getAnchorCell(1));

		var fp = set.getSymbolFootprint(1, 0);
		Assert.equals("BIG", fp.symbolId);
		Assert.equals(0, fp.reel);
		Assert.equals(0, fp.cell);
		Assert.equals(2, fp.reels);
		Assert.equals(2, fp.cells);

		set.destroy();
	}

	public function testAnchorResizesToFull2x2FootprintVertical() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(2)
			.visibleCells(3)
			.symbolSize(40, 50)
			.symbolGap(4, 6)
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
				r.register("BIG", function() return new HeadlessSymbol(), {
					size: {reels: 2, cells: 2}
				});
			})
			.weights(["a" => 1., "BIG" => 0.])
			.initialFrame([
				{visible: ["a", "a", "a"]},
				{visible: ["a", "a", "a"]}
			])
			.build();

		set.spin();
		set.setResult([
			{visible: ["BIG", "a", "a"]},
			{visible: ["a", "a", "a"]}
		]);
		set.slamStop();
		clock.advance(2000);

		var anchor = set.getReel(0).getVisibleSymbol(0);
		// Cross = 2*40 + 4, main = 2*50 + 6
		Assert.floatEquals(84, anchor.cellWidth, 1e-9);
		Assert.floatEquals(106, anchor.cellHeight, 1e-9);
		set.destroy();
	}

	public function testAnchorResizesToFull2x2FootprintHorizontal() {
		var clock = new FakeClock();
		var set = new ReelSetBuilder()
			.reels(2)
			.visibleCells(3)
			.symbolSize(40, 50)
			.symbolGap(4, 6)
			.orientation(Horizontal)
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
				r.register("BIG", function() return new HeadlessSymbol(), {
					size: {reels: 2, cells: 2}
				});
			})
			.weights(["a" => 1., "BIG" => 0.])
			.initialFrame([
				{visible: ["a", "a", "a"]},
				{visible: ["a", "a", "a"]}
			])
			.build();

		set.spin();
		set.setResult([
			{visible: ["BIG", "a", "a"]},
			{visible: ["a", "a", "a"]}
		]);
		set.slamStop();
		clock.advance(2000);

		var anchor = set.getReel(0).getVisibleSymbol(0);
		// Horizontal: main=X cells, cross=Y reels → W = 2*40+4, H = 2*50+6
		Assert.floatEquals(84, anchor.cellWidth, 1e-9);
		Assert.floatEquals(106, anchor.cellHeight, 1e-9);
		set.destroy();
	}

	public function testBuilderRejectsBigPlusMultiways() {
		Assert.raises(function() {
			new ReelSetBuilder()
				.reels(2)
				.symbolSize(40, 40)
				.multiways({minCells: 2, maxCells: 3, reelExtent: 120})
				.clock(new FakeClock())
				.symbols(function(r) {
					r.register("BIG", function() return new HeadlessSymbol(), {
						size: {reels: 2, cells: 1}
					});
				})
				.build();
		});
	}

	public function testAutoPickSharedRectOnBigWithGap() {
		var set = new ReelSetBuilder()
			.reels(2)
			.visibleCells(2)
			.symbolSize(40, 40)
			.symbolGap(4, 0)
			.clock(new FakeClock())
			.symbols(function(r) {
				r.register("a", function() return new HeadlessSymbol());
				r.register("BIG", function() return new HeadlessSymbol(), {
					size: {reels: 2, cells: 1}
				});
			})
			.build();
		Assert.isTrue(Std.isOfType(set.viewport.maskStrategy, reels.core.SharedRectMaskStrategy));
		set.destroy();
	}
}
