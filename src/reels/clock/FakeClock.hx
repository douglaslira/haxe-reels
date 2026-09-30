package reels.clock;

/**
 * Deterministic clock for unit/integration tests. Advance manually.
 */
class FakeClock implements IFrameClock {
	var _callbacks:Array<Float->Void> = [];
	var _destroyed:Bool = false;
	public var elapsedMs(default, null):Float = 0;

	public function new() {}

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	public var isDestroyed(get, never):Bool;

	public function add(callback:Float->Void):Void {
		if (_destroyed) return;
		if (_callbacks.indexOf(callback) < 0) _callbacks.push(callback);
	}

	public function remove(callback:Float->Void):Void {
		_callbacks.remove(callback);
	}

	/** Advance by `ms`, optionally in fixed steps (default 16ms). */
	public function advance(ms:Float, stepMs:Float = 16):Void {
		if (_destroyed || ms <= 0) return;
		var remaining = ms;
		while (remaining > 0) {
			var step = remaining < stepMs ? remaining : stepMs;
			elapsedMs += step;
			var snapshot = _callbacks.copy();
			for (cb in snapshot) cb(step);
			remaining -= step;
		}
	}

	public function destroy():Void {
		if (_destroyed) return;
		_destroyed = true;
		_callbacks = [];
	}
}
