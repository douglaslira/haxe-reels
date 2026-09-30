package tests;

import reels.core.Direction;
import reels.core.Orientation;
import reels.core.ReelAxis;
import utest.Assert;
import utest.Test;

class TestReelAxis extends Test {
	public function testVerticalForward() {
		var axis = ReelAxis.create(Vertical, Forward);
		Assert.equals(1, axis.polarity);
		Assert.equals("y", axis.mainProp);
		Assert.equals("x", axis.crossProp);
		var local = axis.toLocal(120, 100);
		Assert.equals(120, local.cross);
		Assert.equals(100, local.main);
	}

	public function testHorizontalReverse() {
		var axis = ReelAxis.create(Horizontal, Reverse);
		Assert.equals(-1, axis.polarity);
		Assert.equals("x", axis.mainProp);
		Assert.equals("y", axis.crossProp);
	}
}
