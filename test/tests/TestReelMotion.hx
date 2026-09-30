package tests;

import reels.core.ReelAxis;
import reels.core.ReelMotion;
import reels.symbols.HeadlessSymbol;
import reels.symbols.ReelSymbol;
import utest.Assert;
import utest.Test;

class TestReelMotion extends Test {
	public function testAdvanceWrapsAndDerivedPositions() {
		var symbols:Array<ReelSymbol> = [];
		for (i in 0...5) {
			var s = new HeadlessSymbol();
			s.activate('s$i');
			symbols.push(s);
		}
		var wraps = 0;
		var motion = new ReelMotion(symbols, 100, 0, 1, 3, 1, function(_) wraps++, ReelAxis.VERTICAL_FORWARD);
		motion.snapToGrid();
		Assert.equals(0.0, symbols[1].y); // bufferStart=1 → visible cell 0 at y=0

		motion.advance(100); // one full pitch forward
		Assert.isTrue(wraps >= 1);
		motion.snapToGrid();
		Assert.equals(0.0, symbols[1].y);
	}

	public function testReversePolarity() {
		var symbols:Array<ReelSymbol> = [];
		for (_ in 0...4) symbols.push(new HeadlessSymbol());
		var axis = ReelAxis.create(Vertical, Reverse);
		var motion = new ReelMotion(symbols, 50, 0, 0, 3, 1, function(_) {}, axis);
		motion.advance(50);
		// reverse polarity: positive delta moves toward smaller y
		Assert.isTrue(symbols[0].y <= 0);
	}

	public function testCurveProjectionCanFlatten() {
		var symbols:Array<ReelSymbol> = [];
		for (_ in 0...5) symbols.push(new HeadlessSymbol());
		var motion = new ReelMotion(symbols, 100, 0, 1, 3, 1, function(_) {});
		var curve = new reels.core.ReelCurve(reels.core.ReelCurve.resolveCurveConfig(0.7), ReelAxis.VERTICAL_FORWARD);
		curve.setGeometry(100, 100, 100, 3);
		motion.setCurve(curve);
		Assert.isTrue(motion.curveProjection);

		motion.setCurveProjection(false);
		Assert.isFalse(motion.curveProjection);

		motion.setCurveProjection(true);
		Assert.isTrue(motion.curveProjection);
	}
}
