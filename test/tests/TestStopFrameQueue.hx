package tests;

import reels.core.StopFrameQueue;
import utest.Assert;
import utest.Test;

class TestStopFrameQueue extends Test {
	public function testForwardConsumesEndFirst() {
		var q = new StopFrameQueue();
		q.setFrame(["a", "b", "c"], "start");
		Assert.equals(3, q.remaining);
		Assert.equals("c", q.next());
		Assert.equals("b", q.next());
		Assert.equals("a", q.next());
		Assert.isFalse(q.hasRemaining);
	}

	public function testReverseConsumesHeadFirst() {
		var q = new StopFrameQueue();
		q.setFrame(["a", "b", "c"], "end");
		Assert.equals("a", q.next());
		Assert.equals("b", q.next());
		Assert.equals("c", q.next());
		Assert.isFalse(q.hasRemaining);
	}

	public function testNextThrowsWhenEmpty() {
		var q = new StopFrameQueue();
		q.setFrame(["x"], "start");
		q.next();
		Assert.raises(function() q.next());
	}
}
