package reels.clock;

import haxe.Timer;

/**
 * Production clock: Timer + Timer.stamp() dt. Never ENTER_FRAME for duration.
 */
class FrameClock implements IFrameClock {
	static inline var INTERVAL_MS:Int = 16;
	static inline var MAX_DT_MS:Float = 64;

	var _timer:Null<Timer>;
	var _lastStamp:Float;
	var _callbacks:Array<Float->Void> = [];
	var _destroyed:Bool = false;

	public function new() {
		_lastStamp = Timer.stamp();
		_timer = new Timer(INTERVAL_MS);
		_timer.run = onTick;
	}

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

	function onTick():Void {
		if (_destroyed) return;
		var now = Timer.stamp();
		var dtMs = (now - _lastStamp) * 1000;
		_lastStamp = now;
		if (dtMs > MAX_DT_MS) dtMs = MAX_DT_MS;
		if (dtMs < 0) dtMs = 0;
		var snapshot = _callbacks.copy();
		for (cb in snapshot) cb(dtMs);
	}

	public function destroy():Void {
		if (_destroyed) return;
		_destroyed = true;
		if (_timer != null) {
			_timer.stop();
			_timer = null;
		}
		_callbacks = [];
	}
}
