package tests;

import reels.ReelSetBuilder;
import reels.clock.FakeClock;
import reels.config.CellTypes.ReelCellQuad;
import reels.config.SpeedPresets;
import reels.core.Direction;
import reels.core.Orientation;
import reels.core.ReelAxis;
import reels.core.ReelCurve;
import reels.symbols.HeadlessSymbol;
import reels.testing.TestHarness;
import reels.testing.TestHarness.TestReelSetHandle;
import utest.Assert;
import utest.Test;

class TestReelCurve extends Test {
	static inline var CELL = 100.;
	static inline var CELLS = 3;
	static inline var MAX_ARC = 1.0;

	function build(amount:Float, ?depth:Float, gap:Float = 0, ?axis:ReelAxis):ReelCurve {
		var a = axis != null ? axis : ReelAxis.VERTICAL_FORWARD;
		var cfg = depth != null
			? ReelCurve.resolveCurveConfig({amount: amount, depth: depth})
			: ReelCurve.resolveCurveConfig({amount: amount});
		var curve = new ReelCurve(cfg, a);
		curve.setGeometry(CELL, CELL, CELL + gap, CELLS);
		return curve;
	}

	function flatStart(i:Int, gap:Float = 0):Float {
		return i * (CELL + gap);
	}

	function quad(curve:ReelCurve, i:Int):ReelCellQuad {
		var q = curve.quadFor(flatStart(i));
		Assert.notNull(q);
		return q;
	}

	function nearWidth(q:ReelCellQuad):Float {
		return Math.sqrt((q.x1 - q.x0) * (q.x1 - q.x0) + (q.y1 - q.y0) * (q.y1 - q.y0));
	}

	function farWidth(q:ReelCellQuad):Float {
		return Math.sqrt((q.x2 - q.x3) * (q.x2 - q.x3) + (q.y2 - q.y3) * (q.y2 - q.y3));
	}

	public function testResolveNumberShorthand() {
		Assert.floatEquals(0.4, ReelCurve.resolveCurveConfig(0.4).amount, 1e-9);
	}

	public function testResolveDerivesDepth() {
		Assert.floatEquals(0.2, ReelCurve.resolveCurveConfig(0.4).depth, 1e-9);
		Assert.floatEquals(0.3, ReelCurve.resolveCurveConfig({amount: 0.4, depth: 0.3}).depth, 1e-9);
	}

	public function testResolveClamps() {
		Assert.equals(0, ReelCurve.resolveCurveConfig(-3).amount);
		Assert.equals(1, ReelCurve.resolveCurveConfig(7).amount);
		Assert.equals(0, ReelCurve.resolveCurveConfig(Math.NaN).amount);
		Assert.equals(0, ReelCurve.resolveCurveConfig({amount: 0.5, depth: -1}).depth);
	}

	public function testResolveFoldLimit() {
		for (amount in [0.25, 0.5, 0.75, 1.0]) {
			var resolved = ReelCurve.resolveCurveConfig({amount: amount, depth: 1});
			Assert.isTrue(resolved.depth < Math.cos(amount * MAX_ARC));
		}
		Assert.isTrue(ReelCurve.resolveCurveConfig({amount: 1, depth: 1}).depth < 1);
		Assert.floatEquals(0.15, ReelCurve.resolveCurveConfig({amount: 0.3, depth: 0.15}).depth, 1e-9);
	}

	public function testFlatProjectsNothing() {
		var curve = build(0);
		Assert.isTrue(curve.isFlat);
		Assert.isNull(curve.quadFor(flatStart(0)));
		Assert.floatEquals(150, curve.mapMain(150), 1e-9);
		Assert.floatEquals(1, curve.scaleAt(150), 1e-9);
		Assert.floatEquals(0, curve.edgeInsetMain, 1e-9);
		Assert.floatEquals(0, curve.projectedHalfExtent, 1e-9);
	}

	public function testEdgeInsetGrowsWithAmount() {
		var flat = build(0);
		Assert.floatEquals(0, flat.edgeInsetMain, 1e-9);

		var mild = build(0.3);
		var strong = build(0.7);
		Assert.isTrue(mild.edgeInsetMain > 0);
		Assert.isTrue(strong.edgeInsetMain > mild.edgeInsetMain);
		Assert.floatEquals(
			mild.halfExtent,
			mild.projectedHalfExtent + mild.edgeInsetMain,
			1e-9
		);
		Assert.floatEquals(
			mild.halfExtent * mild.edgeMapped,
			mild.projectedHalfExtent,
			1e-9
		);
	}

	public function testMiddleAtOneToOne() {
		for (amount in [0.2, 0.5, 0.8, 1.0]) {
			var curve = build(amount);
			var centre = (CELLS * CELL) / 2;
			var d = 0.25;
			var magnification = (curve.mapMain(centre + d) - curve.mapMain(centre - d)) / (2 * d);
			Assert.floatEquals(1, magnification, 1e-4);
		}
	}

	public function testEndsFallShortSymmetrically() {
		var curve = build(0.6);
		var span = CELLS * CELL;
		Assert.isTrue(curve.mapMain(0) > 0);
		Assert.isTrue(curve.mapMain(span) < span);
		Assert.floatEquals(span - curve.mapMain(span), curve.mapMain(0), 1e-6);
	}

	public function testCentreFixedAndSymmetric() {
		var curve = build(0.6);
		var centre = (CELLS * CELL) / 2;
		Assert.floatEquals(centre, curve.mapMain(centre), 1e-6);
		for (d in [10., 60., 140., 190.]) {
			Assert.floatEquals(
				centre - curve.mapMain(centre - d),
				curve.mapMain(centre + d) - centre,
				1e-6
			);
		}
	}

	public function testRecedesTowardEdges() {
		var curve = build(0.6, 0.3);
		var centre = (CELLS * CELL) / 2;
		Assert.floatEquals(1, curve.scaleAt(centre), 1e-6);
		Assert.floatEquals(1 / 1.3, curve.scaleAt(0), 1e-6);
		Assert.floatEquals(1 / 1.3, curve.scaleAt(CELLS * CELL), 1e-6);
		Assert.isTrue(curve.scaleAt(-3 * CELL) < curve.scaleAt(0));
	}

	public function testStrictlyIncreasingAcrossBuffers() {
		for (amount in [0.25, 0.5, 0.75, 1.0]) {
			var curve = build(amount, 1);
			var previous = Math.NEGATIVE_INFINITY;
			var m = -2 * CELL;
			while (m <= (CELLS + 2) * CELL) {
				var mapped = curve.mapMain(m);
				Assert.isTrue(mapped > previous);
				previous = mapped;
				m += 5;
			}
		}
	}

	public function testWindowFromArtNotPitch() {
		var gapped = build(0.6, 0.2, 20);
		Assert.floatEquals(170, gapped.mapMain(170), 1e-6);
		Assert.floatEquals(340 - gapped.mapMain(340), gapped.mapMain(0), 1e-6);
	}

	public function testKeystoneOuterCells() {
		var curve = build(0.7, 0.35);
		var top = quad(curve, 0);
		var bottom = quad(curve, 2);
		Assert.isTrue(nearWidth(top) < farWidth(top));
		Assert.isTrue(farWidth(bottom) < nearWidth(bottom));
		Assert.floatEquals(farWidth(bottom), nearWidth(top), 1e-6);
	}

	public function testMiddleCellRectangleWidest() {
		var curve = build(0.7, 0.35);
		var middle = quad(curve, 1);
		Assert.floatEquals(farWidth(middle), nearWidth(middle), 1e-6);
		Assert.isTrue(nearWidth(middle) < CELL);
		Assert.isTrue(nearWidth(middle) > nearWidth(quad(curve, 0)));
		Assert.isTrue(nearWidth(middle) > farWidth(quad(curve, 2)));
	}

	public function testRealTrapezoidNotScaledRect() {
		var top = quad(build(0.7, 0.35), 0);
		Assert.isTrue(Math.abs(nearWidth(top) - farWidth(top)) > 1);
	}

	public function testAuthoredSizeMiddleShortensRest() {
		var curve = build(0.6, 0.3);
		function height(i:Int):Float {
			var q = quad(curve, i);
			return q.y3 - q.y0;
		}
		function width(i:Int):Float {
			return nearWidth(quad(curve, i));
		}
		Assert.isTrue(height(1) <= CELL + 1e-6);
		Assert.isTrue(height(1) > CELL * 0.94);
		Assert.isTrue(width(1) <= CELL + 1e-6);
		Assert.isTrue(width(1) > CELL * 0.94);
		Assert.floatEquals(1, height(1) / width(1), 0.1);
		Assert.isTrue(height(0) < height(1) * 0.8);
		Assert.floatEquals(height(2), height(0), 1e-6);
	}

	public function testCellsTileExactly() {
		var curve = build(1, 1);
		for (i in 0...CELLS - 1) {
			var above = quad(curve, i);
			var below = quad(curve, i + 1);
			Assert.floatEquals(flatStart(i + 1) + below.y0, flatStart(i) + above.y3, 1e-9);
			Assert.floatEquals(nearWidth(below), farWidth(above), 1e-9);
		}
	}

	public function testBufferCellsKeystone() {
		var curve = build(0.7, 0.35);
		var peeking = curve.quadFor(-CELL);
		Assert.notNull(peeking);
		Assert.isTrue(nearWidth(peeking) < farWidth(peeking) - 0.5);
		Assert.isTrue(farWidth(peeking) <= nearWidth(quad(curve, 0)) + 1e-6);

		var trailing = curve.quadFor(CELLS * CELL);
		Assert.notNull(trailing);
		Assert.isTrue(farWidth(trailing) < nearWidth(trailing) - 0.5);
	}

	public function testKeepsShrinkingPastWindow() {
		var curve = build(0.7, 0.35);
		var edge = curve.scaleAt(0);
		var oneOut = curve.scaleAt(-CELL);
		var twoOut = curve.scaleAt(-2 * CELL);
		Assert.isTrue(oneOut < edge);
		Assert.isTrue(twoOut < oneOut);
	}

	public function testCentresOnReelCentreline() {
		var curve = build(0.7, 0.35);
		for (i in 0...CELLS) {
			var q = quad(curve, i);
			Assert.floatEquals(CELL / 2, (q.x0 + q.x1) / 2, 1e-6);
			Assert.floatEquals(CELL / 2, (q.x2 + q.x3) / 2, 1e-6);
		}
	}

	public function testReportsFlatBox() {
		var q = quad(build(0.5), 0);
		Assert.floatEquals(CELL, q.width, 1e-9);
		Assert.floatEquals(CELL, q.height, 1e-9);
	}

	public function testCornersClockwiseBothOrientations() {
		var vertical = quad(build(0.7, 0.35), 0);
		Assert.floatEquals(vertical.y1, vertical.y0, 1e-6);
		Assert.floatEquals(vertical.y3, vertical.y2, 1e-6);
		Assert.isTrue(vertical.x0 < vertical.x1);
		Assert.isTrue(vertical.x3 < vertical.x2);
		Assert.isTrue(vertical.y3 > vertical.y0);

		var horizontal = quad(
			build(0.7, 0.35, 0, ReelAxis.create(Horizontal, Forward)),
			0
		);
		Assert.floatEquals(horizontal.x3, horizontal.x0, 1e-6);
		Assert.floatEquals(horizontal.x2, horizontal.x1, 1e-6);
		Assert.isTrue(horizontal.y0 < horizontal.y3);
		Assert.isTrue(horizontal.y1 < horizontal.y2);
		Assert.isTrue(horizontal.x1 > horizontal.x0);
	}

	public function testRebindReshape() {
		var curve = build(0.6);
		curve.setGeometry(60, 60, 60, 5);
		var centre = (5 * 60) / 2;
		Assert.floatEquals(centre, curve.mapMain(centre), 1e-6);
		Assert.floatEquals(
			1,
			(curve.mapMain(centre + 0.25) - curve.mapMain(centre - 0.25)) / 0.5,
			1e-4
		);
		Assert.floatEquals(60, quad(curve, 0).width, 1e-9);
	}

	public function testCurvePerReelLengthMismatchThrows() {
		var clock = new FakeClock();
		Assert.raises(function() {
			new ReelSetBuilder()
				.reels(3)
				.visibleCells(3)
				.symbolSize(100, 100)
				.clock(clock)
				.curvePerReel([0.2, 0.4])
				.symbols(function(r) {
					r.register("a", function() return new HeadlessSymbol());
				})
				.speed("normal", SpeedPresets.NORMAL)
				.build();
		});
		clock.destroy();
	}

	public function testBuilderCurveAttachesNonFlat() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			curve: 0.5
		});
		Assert.notNull(h.reelSet.getReel(0).curve);
		Assert.isFalse(h.reelSet.getReel(0).curve.isFlat);
		h.destroy();
	}

	public function testBuilderCurveInsetsViewportMask() {
		var flat = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b"],
			symbolHeight: 100,
			symbolWidth: 100
		});
		Assert.floatEquals(0, flat.reelSet.maskMainInset, 1e-9);
		flat.destroy();

		var curved = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b"],
			symbolHeight: 100,
			symbolWidth: 100,
			curve: 0.7
		});
		var expected = curved.reelSet.getReel(0).curve.edgeInsetMain;
		Assert.isTrue(expected > 0);
		Assert.floatEquals(expected, curved.reelSet.maskMainInset, 1e-9);
		curved.destroy();
	}

	public function testBuilderCurvePerReelUsesMaxInset() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "c"],
			symbolHeight: 100,
			symbolWidth: 100,
			curvePerReel: [0.2, 0.7, 0.3]
		});
		var maxInset = 0.;
		for (i in 0...3) {
			var c = h.reelSet.getReel(i).curve;
			if (c == null) continue;
			if (c.edgeInsetMain > maxInset) maxInset = c.edgeInsetMain;
		}
		Assert.isTrue(maxInset > 0);
		Assert.floatEquals(maxInset, h.reelSet.maskMainInset, 1e-9);
		h.destroy();
	}

	public function testCurveFocusReelKeepsOwnDrum() {
		var h = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a"],
			symbolWidth: CELL,
			symbolHeight: CELL,
			curve: 0.6
		});
		for (i in 0...5) {
			Assert.floatEquals(CELL / 2, h.reelSet.getReel(i).curve.focusCross, 1e-6);
		}
		var outer = h.reelSet.getReel(0).curve.quadFor(0);
		Assert.notNull(outer);
		Assert.floatEquals(CELL / 2, (outer.x0 + outer.x1) / 2, 1e-6);
		Assert.floatEquals(CELL / 2, (outer.x2 + outer.x3) / 2, 1e-6);
		h.destroy();
	}

	public function testCurveFocusSetLeansTowardBoardCentre() {
		var h = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a"],
			symbolWidth: CELL,
			symbolHeight: CELL,
			curve: 0.6,
			curveFocus: "set"
		});
		Assert.floatEquals(2.5 * CELL, h.reelSet.getReel(0).curve.focusCross, 1e-6);
		Assert.floatEquals(CELL / 2, h.reelSet.getReel(2).curve.focusCross, 1e-6);
		Assert.floatEquals(-1.5 * CELL, h.reelSet.getReel(4).curve.focusCross, 1e-6);

		var left = h.reelSet.getReel(0).curve.quadFor(0);
		Assert.notNull(left);
		Assert.isTrue((left.x0 + left.x1) / 2 > CELL / 2);

		var right = h.reelSet.getReel(4).curve.quadFor(0);
		Assert.notNull(right);
		Assert.isTrue((right.x0 + right.x1) / 2 < CELL / 2);
		Assert.floatEquals(
			(left.x0 + left.x1) / 2 - CELL / 2,
			CELL / 2 - (right.x0 + right.x1) / 2,
			1e-6
		);

		var middle = h.reelSet.getReel(2).curve.quadFor(0);
		Assert.notNull(middle);
		Assert.floatEquals(CELL / 2, (middle.x0 + middle.x1) / 2, 1e-6);
		h.destroy();
	}

	public function testCurveFocusSetLeanIsHalfOfSet() {
		var full = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a"],
			symbolWidth: CELL,
			symbolHeight: CELL,
			curve: 0.6,
			curveFocus: "set"
		});
		var half = TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a"],
			symbolWidth: CELL,
			symbolHeight: CELL,
			curve: 0.6,
			curveFocus: "set-lean"
		});
		var centre = CELL / 2;
		function leanOf(h:TestReelSetHandle):Float {
			var q = h.reelSet.getReel(0).curve.quadFor(0);
			Assert.notNull(q);
			return (q.x0 + q.x1) / 2 - centre;
		}
		Assert.floatEquals(leanOf(full) / 2, leanOf(half), 1e-6);
		Assert.floatEquals(
			(centre + full.reelSet.getReel(0).curve.focusCross) / 2,
			half.reelSet.getReel(0).curve.focusCross,
			1e-6
		);
		full.destroy();
		half.destroy();
	}

	public function testCurveFocusRejectsUnknown() {
		Assert.raises(function() {
			TestHarness.createTestReelSet({
				reels: 3,
				visibleCells: 3,
				symbolIds: ["a"],
				curve: 0.5,
				curveFocus: "middle"
			});
		});
	}
}
