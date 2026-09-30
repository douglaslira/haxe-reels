package tests;

import reels.events.EventEmitter;
import utest.Assert;
import utest.Test;

class TestEventEmitter extends Test {
	public function testOnEmitOff() {
		var em = new EventEmitter();
		var hits = 0;
		var fn = function(args:Array<Dynamic>) {
			hits++;
			Assert.equals(42, args[0]);
		};
		em.on("spin:start", fn);
		em.emit("spin:start", [42]);
		Assert.equals(1, hits);
		em.off("spin:start", fn);
		em.emit("spin:start", [1]);
		Assert.equals(1, hits);
	}

	public function testOnce() {
		var em = new EventEmitter();
		var hits = 0;
		em.once("x", function(_) hits++);
		em.emit("x");
		em.emit("x");
		Assert.equals(1, hits);
	}
}
