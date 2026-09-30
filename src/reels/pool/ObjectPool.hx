package reels.pool;

import reels.util.IDisposable;

/**
 * Generic object pool keyed by string. Reduces GC pressure on the spin hot path.
 */
class ObjectPool<T> implements IDisposable {
	var _factory:(key:String) -> T;
	var _reset:Null<(item:T) -> Void>;
	var _dispose:Null<(item:T) -> Void>;
	var _maxPerKey:Int;
	var _pools:Map<String, Array<T>> = new Map();
	var _pooled:Array<T> = [];
	var _destroyed:Bool = false;

	public function new(
		factory:(key:String) -> T,
		?reset:(item:T) -> Void,
		?dispose:(item:T) -> Void,
		maxPerKey:Int = 20
	) {
		_factory = factory;
		_reset = reset;
		_dispose = dispose;
		_maxPerKey = maxPerKey;
	}

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	public var isDestroyed(get, never):Bool;

	public function acquire(key:String):T {
		if (_destroyed) {
			throw 'ObjectPool.acquire(\'$key\') called after destroy()';
		}
		var pool = _pools.get(key);
		if (pool != null && pool.length > 0) {
			var item = pool.pop();
			_pooled.remove(item);
			if (_reset != null) _reset(item);
			return item;
		}
		return _factory(key);
	}

	public function release(key:String, item:T):Void {
		if (_destroyed) return;
		if (_pooled.indexOf(item) >= 0) return;

		var pool = _pools.get(key);
		if (pool == null) {
			pool = [];
			_pools.set(key, pool);
		}
		if (pool.length >= _maxPerKey) {
			if (_dispose != null) _dispose(item);
			return;
		}
		pool.push(item);
		_pooled.push(item);
	}

	public function size(key:String):Int {
		var pool = _pools.get(key);
		return pool == null ? 0 : pool.length;
	}

	public var totalSize(get, never):Int;

	function get_totalSize():Int {
		var total = 0;
		for (pool in _pools) total += pool.length;
		return total;
	}

	public function clear():Void {
		if (_dispose != null) {
			for (pool in _pools) {
				for (item in pool) _dispose(item);
			}
		}
		_pools = new Map();
		_pooled = [];
	}

	public function destroy():Void {
		if (_destroyed) return;
		clear();
		_destroyed = true;
	}
}
