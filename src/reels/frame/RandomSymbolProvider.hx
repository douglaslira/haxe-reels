package reels.frame;

/**
 * Weighted random symbol provider for spinning/buffer fills.
 * Not used for outcomes — outcomes come from setResult.
 */
class RandomSymbolProvider {
	var _ids:Array<String>;
	var _weights:Array<Float>;
	var _total:Float;
	var _rng:() -> Float;

	public function new(weights:Map<String, Float>, ?rng:() -> Float) {
		_rng = rng != null ? rng : Math.random;
		_ids = [];
		_weights = [];
		_total = 0;
		for (id => w in weights) {
			if (w <= 0) continue;
			_ids.push(id);
			_weights.push(w);
			_total += w;
		}
		if (_ids.length == 0) throw "RandomSymbolProvider requires at least one positive weight";
	}

	public function next():String {
		var r = _rng() * _total;
		var acc = 0.0;
		for (i in 0..._ids.length) {
			acc += _weights[i];
			if (r <= acc) return _ids[i];
		}
		return _ids[_ids.length - 1];
	}

	public function ids():Array<String> {
		return _ids.copy();
	}
}
