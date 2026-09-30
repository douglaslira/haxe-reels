package reels.util;

/**
 * Lightweight abort flag for callback-style async (cycle / presenter waits).
 * Mirrors AbortController.abort() without depending on JS AbortSignal.
 */
class AbortToken {
	public var aborted(default, null):Bool = false;
	var _listeners:Array<() -> Void> = [];

	public function new() {}

	public function abort():Void {
		if (aborted) return;
		aborted = true;
		var list = _listeners;
		_listeners = [];
		for (cb in list) cb();
	}

	public function onAbort(cb:() -> Void):Void {
		if (aborted) {
			cb();
			return;
		}
		_listeners.push(cb);
	}
}
