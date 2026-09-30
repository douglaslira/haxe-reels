package tests;

import reels.ReelSetBuilder;
import reels.clock.FakeClock;
import reels.config.CellTypes.ReelCellQuad;
import reels.config.SpeedPresets;
import reels.spine.MockSpineFactory;
import reels.spine.SpineReelSymbol;
import reels.symbols.AffineCellFit;
import openfl.display.Sprite;
import utest.Assert;
import utest.Test;

/**
 * Spine affine fit under curveMode('symbol') — Spine-on-curve polish.
 */
class TestSpineOnCurve extends Test {
	static function makeWild():SpineReelSymbol {
		return new SpineReelSymbol({
			factory: new MockSpineFactory(),
			spineMap: ["WILD" => {skeleton: "w", atlas: "w", skin: "w"}]
		});
	}

	/** Trapezoid larger than the flat cell (drum face-on) — scale should exceed 1. */
	static function midQuad(cell:Float):ReelCellQuad {
		var grow = cell * 0.25;
		return {
			x: 0,
			y: 0,
			width: cell,
			height: cell,
			x0: -grow,
			y0: -grow,
			x1: cell + grow,
			y1: -grow,
			x2: cell + grow * 1.2,
			y2: cell + grow,
			x3: -grow * 1.2,
			y3: cell + grow
		};
	}

	public function testAffineHelperScalesAndCenters() {
		var fit = new Sprite();
		var cell = 100.;
		AffineCellFit.apply(fit, midQuad(cell), cell, cell);
		Assert.isTrue(fit.scaleX > 1, "mid-window quad should magnify");
		Assert.floatEquals(fit.scaleX, fit.scaleY, 1e-9);
		AffineCellFit.clear(fit);
		Assert.floatEquals(1, fit.scaleX, 1e-9);
		Assert.floatEquals(0, fit.x, 1e-9);
		Assert.floatEquals(0, fit.y, 1e-9);
	}

	public function testSpineApplyCellQuadScalesFit() {
		var s = makeWild();
		s.resize(100, 100);
		s.activate("WILD");
		Assert.floatEquals(1, s.curveFitScale, 1e-9);
		s.applyCellQuad(midQuad(100));
		Assert.isTrue(s.curveFitScale > 1, "curve fit should leave flat scale");
		s.applyCellQuad(null);
		Assert.floatEquals(1, s.curveFitScale, 1e-9);
		s.destroy();
	}

	public function testSpineOnCurvedReelProjects() {
		var clock = new FakeClock();
		var factory = new MockSpineFactory();
		var reelSet = new ReelSetBuilder()
			.reels(1)
			.visibleCells(3)
			.symbolSize(80, 80)
			.curve(0.6)
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.symbols(function(r) {
				r.register("WILD", function() {
					return new SpineReelSymbol({
						factory: factory,
						spineMap: ["WILD" => {skeleton: "w", atlas: "w"}]
					});
				});
				r.register("a", function() {
					return new reels.symbols.HeadlessSymbol();
				});
			})
			.weights(["WILD" => 1., "a" => 1.])
			.initialFrame([{visible: ["WILD", "a", "WILD"]}])
			.build();

		clock.advance(16);
		var sym = cast(reelSet.getReel(0).getSymbolAt(0), SpineReelSymbol);
		Assert.isTrue(sym.curveFitScale != 1, "edge cell on curved reel should affine-fit");

		reelSet.getReel(0).setCurveVisuals(false);
		clock.advance(16);
		Assert.floatEquals(1, sym.curveFitScale, 1e-6);

		reelSet.destroy();
	}

	public function testWarpBuildWithSpineDoesNotThrow() {
		var clock = new FakeClock();
		var factory = new MockSpineFactory();
		var reelSet = new ReelSetBuilder()
			.reels(1)
			.visibleCells(2)
			.symbolSize(60, 60)
			.curve(0.5)
			.curveMode("warp")
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.symbols(function(r) {
				r.register("WILD", function() {
					return new SpineReelSymbol({
						factory: factory,
						spineMap: ["WILD" => {skeleton: "w", atlas: "w"}]
					});
				});
			})
			.initialFrame([{visible: ["WILD", "WILD"]}])
			.build();
		Assert.isTrue(reelSet.getReel(0).warping);
		clock.advance(16);
		reelSet.destroy();
	}
}
