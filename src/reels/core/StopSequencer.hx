package reels.core;

/**
 * Staggers stop start times across reels.
 */
class StopSequencer {
	var _delays:Array<Float>;
	var _elapsed:Float = 0;
	var _started:Array<Bool>;
	var _onStart:Int->Void;
	var _done:Bool = false;

	public function new(delays:Array<Float>, onStart:Int->Void) {
		_delays = delays;
		_onStart = onStart;
		_started = [for (_ in 0...delays.length) false];
	}

	public function update(deltaMs:Float):Void {
		if (_done) return;
		_elapsed += deltaMs;
		var all = true;
		for (i in 0..._delays.length) {
			if (_started[i]) continue;
			if (_elapsed >= _delays[i]) {
				_started[i] = true;
				_onStart(i);
			} else {
				all = false;
			}
		}
		if (all) _done = true;
	}

	public function forceAll():Void {
		for (i in 0..._delays.length) {
			if (!_started[i]) {
				_started[i] = true;
				_onStart(i);
			}
		}
		_done = true;
	}

	public var isDone(get, never):Bool;

	function get_isDone():Bool {
		return _done;
	}
}
