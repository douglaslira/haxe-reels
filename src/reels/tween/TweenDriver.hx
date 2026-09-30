package reels.tween;

/**
 * Lightweight tween driven by the same frame clock as the reel engine.
 */
class TweenDriver {
	var _active:Array<TweenHandle> = [];

	public function new() {}

	public function to(
		getValue:() -> Float,
		setValue:Float->Void,
		toValue:Float,
		durationMs:Float,
		?ease:Float->Float,
		?onComplete:() -> Void
	):TweenHandle {
		var from = getValue();
		var easeFn = ease != null ? ease : Easing.quadOut;
		var handle = new TweenHandle(from, toValue, durationMs, getValue, setValue, easeFn, onComplete);
		_active.push(handle);
		return handle;
	}

	public function update(deltaMs:Float):Void {
		var i = 0;
		while (i < _active.length) {
			var t = _active[i];
			if (t.update(deltaMs)) {
				_active.splice(i, 1);
			} else {
				i++;
			}
		}
	}

	public function kill(handle:TweenHandle):Void {
		_active.remove(handle);
	}

	public function killAll():Void {
		_active = [];
	}
}

class TweenHandle {
	var _from:Float;
	var _to:Float;
	var _duration:Float;
	var _elapsed:Float = 0;
	var _get:() -> Float;
	var _set:Float->Void;
	var _ease:Float->Float;
	var _onComplete:Null<() -> Void>;
	public var alive(default, null):Bool = true;

	public function new(
		from:Float,
		to:Float,
		durationMs:Float,
		getValue:() -> Float,
		setValue:Float->Void,
		ease:Float->Float,
		?onComplete:() -> Void
	) {
		_from = from;
		_to = to;
		_duration = durationMs <= 0 ? 1 : durationMs;
		_get = getValue;
		_set = setValue;
		_ease = ease;
		_onComplete = onComplete;
	}

	/** Returns true when finished. */
	public function update(deltaMs:Float):Bool {
		if (!alive) return true;
		_elapsed += deltaMs;
		var t = _elapsed / _duration;
		if (t >= 1) {
			_set(_to);
			alive = false;
			if (_onComplete != null) _onComplete();
			return true;
		}
		var e = _ease(t);
		_set(_from + (_to - _from) * e);
		return false;
	}

	public function completeNow():Void {
		if (!alive) return;
		_set(_to);
		alive = false;
		if (_onComplete != null) _onComplete();
	}
}
