package reels.core;

/**
 * Queue of symbol ids to feed during stop wraps.
 * Forward reels consume end-first (new symbols enter at start edge).
 */
class StopFrameQueue {
	var _frame:Array<String> = [];
	var _remaining:Int = 0;
	var _cursor:Int = 0;
	var _step:Int = -1;

	public function new() {}

	public function setFrame(frame:Array<String>, feedEdge:String = "start"):Void {
		_frame = frame.copy();
		_remaining = _frame.length;
		if (feedEdge == "end") {
			_cursor = 0;
			_step = 1;
		} else {
			_cursor = _frame.length - 1;
			_step = -1;
		}
	}

	public function next():String {
		if (_remaining <= 0) {
			throw "StopFrameQueue.next(): frame exhausted";
		}
		_remaining--;
		var value = _frame[_cursor];
		_cursor += _step;
		return value;
	}

	public var hasRemaining(get, never):Bool;

	function get_hasRemaining():Bool {
		return _remaining > 0;
	}

	public var remaining(get, never):Int;

	function get_remaining():Int {
		return _remaining;
	}

	public function reset():Void {
		_frame = [];
		_remaining = 0;
		_cursor = 0;
		_step = -1;
	}
}
