package reels.board;

import reels.ReelSet;
import reels.config.SpeedProfile;
import reels.config.WinTypes.CellBounds;
import reels.events.EventEmitter;
import reels.symbols.ReelSymbol;
import reels.util.IDisposable;

/** Extra spin time (ms) a tense wave adds on top of the normal profile. */
private inline var TENSION_EXTRA_MS = 1100.;

/**
 * Hold & Win board: grid of independently spinning cells plus round
 * choreography (spin free cells, lock hits, respin counter, full board).
 *
 * Composes {@link BoardGrid} (mechanism) and {@link HoldAndWinState} (reducer).
 * Coins are opaque `{ cell, id, data }` — value stays game-layer.
 */
class HoldAndWinBoard implements IDisposable {
	public final events:EventEmitter = new EventEmitter();
	public final cols:Int;
	public final rows:Int;

	var _grid:BoardGrid;
	var _state:HoldAndWinState;
	var _emptyId:String;
	var _anticipateWhen:Null<({locked:Int, capacity:Int, respinsLeft:Int}) -> Bool>;

	public function new(cfg:HoldAndWinBoardConfig) {
		cols = cfg.cols;
		rows = cfg.rows;
		_emptyId = cfg.emptyId;
		_anticipateWhen = cfg.anticipateWhen;

		var baseProfile = cfg.baseProfile;
		var stagger = cfg.stagger;
		function baseMs(cell:BoardCell):Float {
			var floor = baseProfile.minimumSpinTime;
			return floor + stagger(cell.reel, cell.cell);
		}
		var profiles = new Map<String, BoardProfile>();
		profiles.set("normal", function(cell) {
			return copyProfile(baseProfile, "normal", baseMs(cell));
		});
		profiles.set("tension", function(cell) {
			return copyProfile(baseProfile, "tension", baseMs(cell) + TENSION_EXTRA_MS);
		});

		_grid = new BoardGrid({
			cols: cfg.cols,
			rows: cfg.rows,
			cellSize: cfg.cell,
			gap: cfg.gap,
			emptyId: cfg.emptyId,
			bufferSymbols: cfg.bufferSymbols,
			symbols: cfg.configurator,
			weights: cfg.weights,
			chrome: cfg.chrome,
			orientation: cfg.orientation,
			direction: cfg.direction,
			clock: cfg.clock,
			rng: cfg.rng,
			profiles: profiles
		});
		_state = new HoldAndWinState(toHwCells(_grid.cells()), cfg.respins);
	}

	public var view(get, never):openfl.display.Sprite;

	function get_view():openfl.display.Sprite {
		return _grid.view;
	}

	public var capacity(get, never):Int;

	function get_capacity():Int {
		return _state.capacity;
	}

	public var respinsLeft(get, never):Int;

	function get_respinsLeft():Int {
		return _state.respinsLeft;
	}

	public var lockedCoins(get, never):Array<HwCoin>;

	function get_lockedCoins():Array<HwCoin> {
		return _state.lockedCoins();
	}

	public var isFull(get, never):Bool;

	function get_isFull():Bool {
		return _state.isFull;
	}

	public var freeCells(get, never):Array<HwCell>;

	function get_freeCells():Array<HwCell> {
		return _state.freeCells();
	}

	public var phase(get, never):HwPhase;

	function get_phase():HwPhase {
		return _state.phase;
	}

	public function cellBounds(cell:HwCell):CellBounds {
		return _grid.cellBounds(cell);
	}

	public function cellCenter(cell:HwCell):{x:Float, y:Float} {
		return _grid.cellCenter(cell);
	}

	public function symbolAt(cell:HwCell):ReelSymbol {
		return _grid.symbolAt(cell);
	}

	public function reelAt(cell:HwCell):ReelSet {
		return _grid.reelAt(cell);
	}

	/**
	 * Rewrite a **locked** cell's coin in place. Throws on a free cell or
	 * while a wave is in flight.
	 */
	public function setSymbolAt(cell:HwCell, id:String, ?data:Dynamic):ReelSymbol {
		_state.swap(cell, id, data);
		_grid.place(cell, id);
		return _grid.symbolAt(cell);
	}

	/** Activate the feature with trigger coins. Seeds land locked, instantly. */
	public function enter(seed:Array<HwCoin>):Void {
		var effects = _state.enter(seed);
		for (coin in seed) _grid.place(coin.cell, coin.id);
		applyEffects(effects);
	}

	/**
	 * Spin every free cell; `hits` land (and lock) their coins, others land
	 * empty. Calls `onComplete` once the wave has landed and the counter is
	 * resolved.
	 */
	public function respin(hits:Array<HwCoin>, onComplete:HwRespinResult->Void):Void {
		var wave = _state.beginWave(hits);
		var round = wave.round;
		var spinning = wave.spinning;
		var hitByKey = wave.hitByKey;
		try {
			var tense = anticipating() && spinning.length > 0;
			var profileName = tense ? "tension" : "normal";
			for (cell in spinning) _grid.setProfile(cell, profileName);
			events.emit("respin:start", [
				{round: round, respinsLeft: _state.respinsLeft, spinning: spinning}
			]);

			var targets:Array<BoardSpinTarget> = [];
			for (cell in spinning) {
				var hit = hitByKey.get(HwTypes.cellKey(cell));
				targets.push({
					cell: cell,
					id: hit != null ? hit.id : _emptyId
				});
			}
			_grid.spinCells(targets, function(cell, _) {
				var hit = hitByKey.get(HwTypes.cellKey(cell));
				applyEffects(_state.land(cell, hit));
			}, function() {
				var ended = _state.endWave();
				applyEffects(ended.effects);
				onComplete({
					round: round,
					hits: ended.landed,
					respinsLeft: _state.respinsLeft,
					full: _state.isFull,
					done: _state.phase == Idle
				});
			});
		} catch (err:Dynamic) {
			_state.abortWave();
			_grid.skipSpinning();
			throw err;
		}
	}

	/** Remove locked coins — the collect moment. */
	public function release(cells:Array<HwCell>):Array<HwCoin> {
		var result = _state.release(cells);
		for (coin in result.released) _grid.place(coin.cell, _emptyId);
		applyEffects(result.effects);
		return result.released;
	}

	/**
	 * Fast-forward in-flight cells. Returns how many were spinning.
	 * Landing / lock / feature:end still resolve normally.
	 */
	public function skip():Int {
		var inFlight = _grid.skipSpinning();
		events.emit("feature:skip", [{inFlight: inFlight}]);
		return inFlight;
	}

	/** Clear the board back to idle. Fires `feature:reset` (not `coin:released`). */
	public function reset():Void {
		var effects = _state.reset();
		for (cell in _grid.cells()) _grid.place(cell, _emptyId);
		applyEffects(effects);
	}

	public var isDestroyed(get, never):Bool;

	function get_isDestroyed():Bool {
		return _grid.isDestroyed;
	}

	public function destroy():Void {
		if (_grid.isDestroyed) return;
		events.removeAllListeners();
		_grid.destroy();
	}

	function applyEffects(effects:Array<HwEffect>):Void {
		for (fx in effects) {
			events.emit(fx.type, [fx.payload]);
			if (fx.type == "coin:locked") {
				try {
					var coin:HwCoin = fx.payload.coin;
					symbolAt(coin.cell).playWin(function() {});
				} catch (_:Dynamic) {
					// Presentation hiccup must not break feature flow.
				}
			}
		}
	}

	function anticipating():Bool {
		if (_anticipateWhen == null) return false;
		return _anticipateWhen({
			locked: _state.lockedCoins().length,
			capacity: _state.capacity,
			respinsLeft: _state.respinsLeft
		});
	}

	static function toHwCells(cells:Array<BoardCell>):Array<HwCell> {
		return [for (c in cells) {reel: c.reel, cell: c.cell}];
	}

	static function copyProfile(base:SpeedProfile, name:String, minimumSpinTime:Float):SpeedProfile {
		return {
			name: name,
			spinDelay: base.spinDelay,
			spinSpeed: base.spinSpeed,
			stopDelay: base.stopDelay,
			anticipationDelay: base.anticipationDelay,
			bounceDistance: base.bounceDistance,
			bounceDuration: base.bounceDuration,
			accelerationEase: base.accelerationEase,
			decelerationEase: base.decelerationEase,
			accelerationDuration: base.accelerationDuration,
			minimumSpinTime: minimumSpinTime
		};
	}
}
