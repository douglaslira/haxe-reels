package reels.events;

typedef Listener = Array<Dynamic>->Void;

private typedef ListenerEntry = {
	fn:Listener,
	once:Bool
};

/**
 * Lightweight event emitter. Event names use colon namespaces (`spin:start`).
 */
class EventEmitter {
	var _listeners:Map<String, Array<ListenerEntry>> = new Map();

	public function new() {}

	public function on(event:String, fn:Listener):EventEmitter {
		return add(event, fn, false);
	}

	public function once(event:String, fn:Listener):EventEmitter {
		return add(event, fn, true);
	}

	public function off(event:String, ?fn:Listener):EventEmitter {
		var entries = _listeners.get(event);
		if (entries == null) return this;
		if (fn == null) {
			_listeners.remove(event);
			return this;
		}
		var filtered = [for (e in entries) if (e.fn != fn) e];
		if (filtered.length == 0) _listeners.remove(event);
		else _listeners.set(event, filtered);
		return this;
	}

	public function emit(event:String, ?args:Array<Dynamic>):Bool {
		var entries = _listeners.get(event);
		if (entries == null || entries.length == 0) return false;
		var payload = args == null ? [] : args;
		var snapshot = entries.copy();
		for (entry in snapshot) {
			if (entry.once) removeEntry(event, entry);
			entry.fn(payload);
		}
		return true;
	}

	public function removeAllListeners(?event:String):EventEmitter {
		if (event != null) _listeners.remove(event);
		else _listeners = new Map();
		return this;
	}

	public function listenerCount(event:String):Int {
		var entries = _listeners.get(event);
		return entries == null ? 0 : entries.length;
	}

	function add(event:String, fn:Listener, once:Bool):EventEmitter {
		var entries = _listeners.get(event);
		if (entries == null) {
			entries = [];
			_listeners.set(event, entries);
		}
		entries.push({fn: fn, once: once});
		return this;
	}

	function removeEntry(event:String, entry:ListenerEntry):Void {
		var entries = _listeners.get(event);
		if (entries == null) return;
		entries.remove(entry);
		if (entries.length == 0) _listeners.remove(event);
	}
}
