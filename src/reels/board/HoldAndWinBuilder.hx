package reels.board;

import openfl.display.Graphics;
import reels.clock.IFrameClock;
import reels.config.SpeedPresets;
import reels.config.SpeedProfile;
import reels.core.Direction;
import reels.core.Orientation;
import reels.symbols.SymbolRegistry;

/**
 * Fluent builder for {@link HoldAndWinBoard}.
 *
 * A Hold & Win board is a W×H grid of cells that spin independently — each
 * cell is its own 1×1 ReelSet. Value-shaped logic stays in the game layer.
 */
class HoldAndWinBuilder {
	var _cols:Int = 5;
	var _rows:Int = 3;
	var _cell:Float = 72;
	var _gap:Float = 4;
	var _emptyId:String = "empty";
	var _respins:Int = 3;
	var _bufferSymbols:Int = 3;
	var _configurator:Null<SymbolRegistry->Void> = null;
	var _weights:Null<Map<String, Float>> = null;
	var _baseProfile:SpeedProfile = copyPreset(SpeedPresets.NORMAL, 320);
	var _stagger:Int->Int->Float = function(reel, cell) return (reel + cell) * 70.;
	var _anticipateWhen:Null<({locked:Int, capacity:Int, respinsLeft:Int}) -> Bool> = null;
	var _chrome:Null<Graphics->Float->Void> = null;
	var _orientation:Orientation = Vertical;
	var _direction:Direction = Forward;
	var _clock:Null<IFrameClock> = null;
	var _rng:Null<() -> Float> = null;

	public function new() {}

	public function grid(cols:Int, rows:Int):HoldAndWinBuilder {
		_cols = cols;
		_rows = rows;
		return this;
	}

	public function cellSize(size:Float, ?opts:HwCellSizeOptions):HoldAndWinBuilder {
		_cell = size;
		if (opts != null && opts.gap != null) _gap = opts.gap;
		return this;
	}

	/**
	 * Register coin symbol factories. An {@link reels.symbols.EmptySymbol} is
	 * auto-registered under {@link emptyId} unless the configurator registers one.
	 */
	public function symbols(configurator:SymbolRegistry->Void):HoldAndWinBuilder {
		_configurator = configurator;
		return this;
	}

	/** Strip weights during the spin. */
	public function weights(weights:Map<String, Float>):HoldAndWinBuilder {
		_weights = weights;
		return this;
	}

	/** Symbol id a cell shows when it holds no coin. Default `'empty'`. */
	public function emptyId(id:String):HoldAndWinBuilder {
		_emptyId = id;
		return this;
	}

	/** Respins granted on enter and restored on every hit. Default 3. */
	public function respins(count:Int):HoldAndWinBuilder {
		_respins = count;
		return this;
	}

	/**
	 * Off-window strip depth per cell. Default 3 (engine default for boards is
	 * deeper than column reels so 1×1 spins still show symbols scrolling past).
	 */
	public function bufferSymbols(count:Int):HoldAndWinBuilder {
		_bufferSymbols = count < 1 ? 1 : count;
		return this;
	}

	/** Base spin feel for every cell. Default: NORMAL with a 320ms floor. */
	public function speedProfile(profile:SpeedProfile):HoldAndWinBuilder {
		_baseProfile = profile;
		return this;
	}

	/**
	 * Extra milliseconds of spin per cell on top of the base minimum spin time.
	 * Default `(reel + cell) * 70` — the diagonal landing wave.
	 */
	public function stagger(fn:Int->Int->Float):HoldAndWinBuilder {
		_stagger = fn;
		return this;
	}

	/**
	 * When the predicate returns true for a wave, every spinning cell uses a
	 * drawn-out tension profile. Evaluated once per wave against pre-wave state.
	 */
	public function anticipateWhen(
		fn:({locked:Int, capacity:Int, respinsLeft:Int}) -> Bool
	):HoldAndWinBuilder {
		_anticipateWhen = fn;
		return this;
	}

	/** Per-cell background, drawn behind each mini reel. */
	public function cellChrome(draw:Graphics->Float->Void):HoldAndWinBuilder {
		_chrome = draw;
		return this;
	}

	/**
	 * Which way each cell's strip travels while it spins. Board `cols`×`rows`
	 * layout is unaffected. Defaults to vertical / forward.
	 */
	public function axis(orientation:Orientation, ?direction:Direction):HoldAndWinBuilder {
		_orientation = orientation;
		_direction = direction != null ? direction : Forward;
		return this;
	}

	public function clock(clock:IFrameClock):HoldAndWinBuilder {
		_clock = clock;
		return this;
	}

	/** Injected RNG for the spin strips (deterministic demos / tests). */
	public function rng(fn:() -> Float):HoldAndWinBuilder {
		_rng = fn;
		return this;
	}

	public function build():HoldAndWinBoard {
		if (_configurator == null) {
			throw "HoldAndWinBuilder: .symbols(...) is required — register at least one coin id.";
		}
		if (_clock == null) {
			throw "HoldAndWinBuilder: .clock(...) is required.";
		}
		return new HoldAndWinBoard({
			cols: _cols,
			rows: _rows,
			cell: _cell,
			gap: _gap,
			emptyId: _emptyId,
			respins: _respins,
			bufferSymbols: _bufferSymbols,
			configurator: _configurator,
			weights: _weights,
			baseProfile: _baseProfile,
			stagger: _stagger,
			anticipateWhen: _anticipateWhen,
			chrome: _chrome,
			orientation: _orientation,
			direction: _direction,
			clock: _clock,
			rng: _rng
		});
	}

	static function copyPreset(base:SpeedProfile, minimumSpinTime:Float):SpeedProfile {
		return {
			name: base.name,
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
