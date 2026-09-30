package reels.board;

/**
 * Pure Hold & Win state machine — single source of truth for board ledger,
 * respin counter, round and {@link HwPhase}. Zero OpenFL / display.
 *
 * Reducer, not a cache: a future {@link HoldAndWinBoard} drives reels, reports
 * landings here, and replays returned {@link HwEffect}s onto its emitter.
 * Incremental wave: {@link beginWave} → N×{@link land} → {@link endWave}.
 */
class HoldAndWinState {
	var _locked:Map<String, HwCoin> = new Map();
	var _cellSet:Map<String, Bool> = new Map();
	var _allCells:Array<HwCell>;
	var _defaultRespins:Int;
	var _respinsLeft:Int = 0;
	var _round:Int = 0;
	var _phase:HwPhase = Idle;
	var _waveLanded:Array<HwCoin> = [];

	public function new(allCells:Array<HwCell>, defaultRespins:Int) {
		_allCells = allCells.copy();
		_defaultRespins = defaultRespins;
		for (c in _allCells) _cellSet.set(HwTypes.cellKey(c), true);
	}

	public var phase(get, never):HwPhase;

	function get_phase():HwPhase {
		return _phase;
	}

	public var respinsLeft(get, never):Int;

	function get_respinsLeft():Int {
		return _respinsLeft;
	}

	public var round(get, never):Int;

	function get_round():Int {
		return _round;
	}

	public var capacity(get, never):Int;

	function get_capacity():Int {
		return _allCells.length;
	}

	public var isFull(get, never):Bool;

	function get_isFull():Bool {
		return Lambda.count(_locked) == capacity;
	}

	public function lockedCoins():Array<HwCoin> {
		return [for (c in _locked) c];
	}

	public function freeCells():Array<HwCell> {
		return [for (c in _allCells) if (!_locked.exists(HwTypes.cellKey(c))) c];
	}

	public function isLocked(cell:HwCell):Bool {
		return _locked.exists(HwTypes.cellKey(cell));
	}

	public function coinAt(cell:HwCell):Null<HwCoin> {
		return _locked.get(HwTypes.cellKey(cell));
	}

	/** Seed trigger coins and arm the counter. Idle → active. */
	public function enter(seed:Array<HwCoin>):Array<HwEffect> {
		if (_phase != Idle) {
			throw "HoldAndWinBoard: enter() while a feature is active — call reset() first.";
		}
		var placed:Array<HwCoin> = [];
		var seen = new Map<String, Bool>();
		for (coin in seed) {
			var k = HwTypes.cellKey(coin.cell);
			assertInGrid(coin.cell, "enter");
			if (seen.exists(k)) throw 'HoldAndWinBoard: enter() seeds cell $k twice.';
			seen.set(k, true);
			var stored = freeze(coin.cell, coin.id, coin.data);
			_locked.set(k, stored);
			placed.push(stored);
		}
		_round = 0;
		_phase = Active;
		return [
			setRespins(_defaultRespins, Seed),
			{type: "feature:enter", payload: {seed: placed, respins: _respinsLeft}}
		];
	}

	/**
	 * Open a wave: validate hits, free cells spin, bump round.
	 * Active → spinning.
	 */
	public function beginWave(hits:Array<HwCoin>):HwBeginWaveResult {
		if (_phase == Idle) {
			throw "HoldAndWinBoard: respin() before enter().";
		}
		if (_phase == Spinning) {
			throw "HoldAndWinBoard: respin() while a wave is in flight.";
		}
		var hitByKey = new Map<String, HwCoin>();
		for (hit in hits) {
			var k = HwTypes.cellKey(hit.cell);
			assertInGrid(hit.cell, "respin");
			if (_locked.exists(k)) throw 'HoldAndWinBoard: hit targets locked cell $k.';
			if (hitByKey.exists(k)) throw 'HoldAndWinBoard: respin() targets cell $k twice.';
			hitByKey.set(k, hit);
		}
		_waveLanded = [];
		_phase = Spinning;
		_round += 1;
		return {round: _round, spinning: freeCells(), hitByKey: hitByKey};
	}

	/** Record one cell landing. `coin` null = miss. */
	public function land(cell:HwCell, coin:Null<HwCoin>):Array<HwEffect> {
		if (_phase != Spinning) return [];
		if (coin == null) {
			return [{type: "cell:landed", payload: {cell: cell, coin: null}}];
		}
		var stored = freeze(cell, coin.id, coin.data);
		_locked.set(HwTypes.cellKey(cell), stored);
		_waveLanded.push(stored);
		return [
			{type: "cell:landed", payload: {cell: cell, coin: stored}},
			{
				type: "coin:locked",
				payload: {coin: stored, locked: Lambda.count(_locked), capacity: capacity}
			}
		];
	}

	/** Close the wave: resolve counter, detect full / feature end. */
	public function endWave():HwEndWaveResult {
		if (_phase != Spinning) return {effects: [], landed: []};
		var landed = _waveLanded;
		var effects:Array<HwEffect> = [];
		effects.push(
			landed.length > 0
				? setRespins(_defaultRespins, HitReset)
				: setRespins(_respinsLeft - 1, Miss)
		);
		_phase = Active;
		effects.push({
			type: "respin:end",
			payload: {round: _round, hits: landed.copy(), respinsLeft: _respinsLeft}
		});
		var full = isFull;
		if (full) {
			effects.push({type: "board:full", payload: {coins: lockedCoins()}});
		}
		var done = full || _respinsLeft <= 0;
		if (done) {
			_phase = Idle;
			effects.push({
				type: "feature:end",
				payload: {coins: lockedCoins(), rounds: _round, full: full}
			});
		}
		return {effects: effects, landed: landed.copy()};
	}

	/**
	 * Abandon an in-flight wave after a driver error: spinning → active.
	 * Cells that already landed stay locked.
	 */
	public function abortWave():Void {
		if (_phase != Spinning) return;
		_phase = Active;
		_waveLanded = [];
	}

	/** Remove locked coins — the collect moment. */
	public function release(cells:Array<HwCell>):HwReleaseResult {
		if (_phase == Spinning) {
			throw "HoldAndWinBoard: release() while a wave is in flight — await respin() first.";
		}
		var effects:Array<HwEffect> = [];
		var released:Array<HwCoin> = [];
		for (cell in cells) {
			var k = HwTypes.cellKey(cell);
			var coin = _locked.get(k);
			if (coin == null) continue;
			_locked.remove(k);
			released.push(coin);
			effects.push({
				type: "coin:released",
				payload: {coin: coin, remaining: Lambda.count(_locked)}
			});
		}
		return {effects: effects, released: released};
	}

	/**
	 * Rewrite a locked cell's coin identity in place.
	 * Throws on a free cell.
	 */
	public function swap(cell:HwCell, id:String, ?data:Dynamic):Void {
		if (_phase == Spinning) {
			throw "HoldAndWinBoard: setSymbolAt() while a wave is in flight — await respin() first.";
		}
		var k = HwTypes.cellKey(cell);
		var prev = _locked.get(k);
		if (prev == null) {
			throw 'HoldAndWinBoard: setSymbolAt($k) on a non-locked cell — setSymbolAt rewrites a locked coin\'s identity.';
		}
		_locked.set(k, freeze(cell, id, data != null ? data : prev.data));
	}

	/** Hard clear back to idle. Fires `feature:reset`, never `coin:released`. */
	public function reset():Array<HwEffect> {
		var clearedCoins = Lambda.count(_locked);
		_locked.clear();
		_waveLanded = [];
		_round = 0;
		_respinsLeft = 0;
		_phase = Idle;
		return [{type: "feature:reset", payload: {clearedCoins: clearedCoins}}];
	}

	function setRespins(value:Int, reason:HwRespinReason):HwEffect {
		_respinsLeft = value < 0 ? 0 : value;
		return {type: "respins:changed", payload: {value: _respinsLeft, reason: reason}};
	}

	/**
	 * Board-owned copy of `cell` so mutating a caller-held reference cannot
	 * corrupt the ledger key. `data` stays by reference (live game value).
	 */
	function freeze(cell:HwCell, id:String, data:Dynamic):HwCoin {
		return {
			cell: {reel: cell.reel, cell: cell.cell},
			id: id,
			data: data
		};
	}

	function assertInGrid(cell:HwCell, op:String):Void {
		var k = HwTypes.cellKey(cell);
		if (!_cellSet.exists(k)) {
			throw 'HoldAndWinBoard: $op() targets cell $k outside the grid.';
		}
	}
}
