package tests;

import reels.frame.ColumnTargets;
import utest.Assert;
import utest.Test;

class TestColumnTarget extends Test {
	public function testStripMaterialize() {
		var target = {
			visible: ["a", "b", "c"],
			bufferStart: ["x"],
			bufferEnd: ["y"]
		};
		var strip = ColumnTargets.columnTargetToStrip(target, 1);
		Assert.equals(5, strip.length);
		Assert.equals("x", strip[0]);
		Assert.equals("a", strip[1]);
		Assert.equals("y", strip[4]);
	}

	public function testAssertRejectsPlainArrays() {
		Assert.raises(function() {
			ColumnTargets.assertColumnTargets([["a"]], "test");
		});
	}
}
