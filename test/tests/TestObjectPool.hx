package tests;

import reels.pool.ObjectPool;
import utest.Assert;
import utest.Test;

class TestObjectPool extends Test {
	public function testAcquireCreatesAndReleaseRecycles() {
		var created = 0;
		var pool = new ObjectPool(function(key) {
			created++;
			return {key: key, n: created};
		});
		var a = pool.acquire("x");
		Assert.equals(1, created);
		pool.release("x", a);
		Assert.equals(1, pool.size("x"));
		var b = pool.acquire("x");
		Assert.equals(1, created);
		Assert.equals(a, b);
		pool.destroy();
	}

	public function testDoubleReleaseIgnored() {
		var disposed = 0;
		var pool = new ObjectPool(
			function(_) return {id: 1},
			null,
			function(_) disposed++
		);
		var item = pool.acquire("k");
		pool.release("k", item);
		pool.release("k", item);
		Assert.equals(1, pool.size("k"));
		Assert.equals(0, disposed);
		pool.destroy();
	}

	public function testAcquireAfterDestroyThrows() {
		var pool = new ObjectPool(function(_) return 1);
		pool.destroy();
		Assert.raises(function() pool.acquire("a"));
	}
}
