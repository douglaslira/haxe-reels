package reels.frame;

/**
 * Builds a strip of symbol ids (buffer + visible + buffer) for one reel.
 */
class FrameBuilder {
	var _visibleCells:Int;
	var _bufferStart:Int;
	var _bufferEnd:Int;
	var _random:RandomSymbolProvider;

	public function new(visibleCells:Int, bufferStart:Int, bufferEnd:Int, random:RandomSymbolProvider) {
		_visibleCells = visibleCells;
		_bufferStart = bufferStart;
		_bufferEnd = bufferEnd;
		_random = random;
	}

	public function buildRandom():Array<String> {
		var strip:Array<String> = [];
		var len = _bufferStart + _visibleCells + _bufferEnd;
		for (_ in 0...len) strip.push(_random.next());
		return strip;
	}

	/** Single random symbol id (e.g. movePin backfill). */
	public function nextRandom():String {
		return _random.next();
	}

	/**
	 * Materialize target into full strip; null slots filled randomly.
	 */
	public function buildFromTarget(target:ColumnTarget):Array<String> {
		var raw = ColumnTargets.columnTargetToStrip(target, _bufferStart);
		var strip:Array<String> = [];
		for (i in 0...(_bufferStart + _visibleCells + _bufferEnd)) {
			var id = i < raw.length ? raw[i] : null;
			strip.push(id != null ? id : _random.next());
		}
		return strip;
	}

	public function visibleFromStrip(strip:Array<String>):Array<String> {
		return strip.slice(_bufferStart, _bufferStart + _visibleCells);
	}

	public function setVisibleCells(count:Int):Void {
		_visibleCells = count;
	}

	public var visibleCells(get, never):Int;

	function get_visibleCells():Int {
		return _visibleCells;
	}
}
