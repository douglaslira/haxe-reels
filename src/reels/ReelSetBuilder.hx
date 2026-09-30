package reels;

import reels.cascade.TumbleConfig;
import reels.cascade.TumbleConfigUtil;
import reels.cascade.ResolvedTumbleConfig;
import reels.clock.FrameClock;
import reels.clock.IFrameClock;
import reels.config.Defaults;
import reels.config.MultiWaysConfig;
import reels.config.SpeedProfile;
import reels.core.CurveFocus;
import reels.core.CurveMode;
import reels.core.Direction;
import reels.core.MaskStrategy;
import reels.core.MaskStrategyVersion;
import reels.core.Orientation;
import reels.core.RectMaskStrategy;
import reels.core.SharedRectMaskStrategy;
import reels.core.ReelMaskRect;
import reels.core.Reel;
import reels.core.ReelAxis;
import reels.core.ReelConfig;
import reels.core.ReelCurveInput;
import reels.core.ReelViewport;
import reels.events.EventEmitter;
import reels.frame.ColumnTarget;
import reels.frame.ColumnTargets;
import reels.frame.FrameBuilder;
import reels.frame.RandomSymbolProvider;
import reels.speed.SpeedManager;
import reels.symbols.BigSymbolCoord;
import reels.symbols.SymbolFactory;
import reels.symbols.SymbolRegistry;

/**
 * Fluent builder for ReelSet. Validates required fields on build().
 */
class ReelSetBuilder {
	var _reels:Null<Int>;
	var _visibleCells:Null<Int>;
	var _symbolW:Null<Float>;
	var _symbolH:Null<Float>;
	var _gapX:Float = Defaults.SYMBOL_GAP_X;
	var _gapY:Float = Defaults.SYMBOL_GAP_Y;
	var _bufferStart:Int = Defaults.BUFFER_SYMBOLS;
	var _bufferEnd:Int = Defaults.BUFFER_SYMBOLS;
	var _orientation:Orientation = Vertical;
	var _direction:Direction = Forward;
	var _directionPerReel:Null<Array<Direction>> = null;
	var _clock:Null<IFrameClock>;
	var _registry:SymbolRegistry = new SymbolRegistry();
	var _weights:Map<String, Float> = new Map();
	var _speedProfiles:Array<SpeedProfile> = [];
	var _initialSpeed:String = Defaults.INITIAL_SPEED;
	var _initialFrame:Null<Array<ColumnTarget>>;
	var _rng:Null<() -> Float>;
	var _tumble:Null<ResolvedTumbleConfig>;
	var _curve:Null<ReelCurveInput> = null;
	var _curvePerReel:Null<Array<ReelCurveInput>> = null;
	var _curveFocus:CurveFocus = CurveFocus.Reel;
	var _curveMode:CurveMode = CurveMode.Symbol;
	var _curveBleed:Float = 0;
	var _multiways:Null<MultiWaysConfig> = null;
	var _adjustDurationMs:Float = 0;
	var _maskStrategy:MaskStrategy = new RectMaskStrategy();
	var _maskStrategyExplicit:Bool = false;

	public function new() {}

	public function reels(count:Int):ReelSetBuilder {
		_reels = count;
		return this;
	}

	public function visibleCells(count:Int):ReelSetBuilder {
		_visibleCells = count;
		return this;
	}

	/**
	 * MultiWays: fixed reel box; per-spin cell counts via `ReelSet.setShape`.
	 * Mutually exclusive with `visibleCells()`. Builds at `maxCells`.
	 */
	public function multiways(config:MultiWaysConfig):ReelSetBuilder {
		_multiways = config;
		return this;
	}

	/**
	 * Hold after MultiWays reshape before stop (ms). 0 = instant.
	 * Also the pin-overlay migration tween window (pixi `pinMigrationDuration`).
	 */
	public function adjustDuration(ms:Float):ReelSetBuilder {
		_adjustDurationMs = ms < 0 ? 0 : ms;
		return this;
	}

	/**
	 * Pixi alias for {@link adjustDuration}: duration of pin-overlay tweens
	 * across a MultiWays reshape (and the AdjustPhase hold).
	 */
	public function pinMigrationDuration(ms:Float):ReelSetBuilder {
		return adjustDuration(ms);
	}

	public function symbolSize(width:Float, height:Float):ReelSetBuilder {
		_symbolW = width;
		_symbolH = height;
		return this;
	}

	public function symbolGap(x:Float, y:Float):ReelSetBuilder {
		_gapX = x;
		_gapY = y;
		return this;
	}

	public function bufferSymbols(count:Int):ReelSetBuilder {
		_bufferStart = count;
		_bufferEnd = count;
		return this;
	}

	public function bufferSymbolsRange(start:Int, end:Int):ReelSetBuilder {
		_bufferStart = start;
		_bufferEnd = end;
		return this;
	}

	public function orientation(value:Orientation):ReelSetBuilder {
		_orientation = value;
		return this;
	}

	/** Default travel direction for every reel. */
	public function direction(value:Direction):ReelSetBuilder {
		_direction = value;
		return this;
	}

	/**
	 * Per-reel travel direction (length must equal `reels()`).
	 * Reels use `direction()` when this is unset.
	 */
	public function directionPerReel(directions:Array<Direction>):ReelSetBuilder {
		_directionPerReel = directions != null ? directions.copy() : null;
		return this;
	}

	public function clock(clock:IFrameClock):ReelSetBuilder {
		_clock = clock;
		return this;
	}

	/** Convenience: allocate a live FrameClock. */
	public function liveClock():ReelSetBuilder {
		_clock = new FrameClock();
		return this;
	}

	public function symbols(configure:SymbolRegistry->Void):ReelSetBuilder {
		configure(_registry);
		return this;
	}

	public function weights(map:Map<String, Float>):ReelSetBuilder {
		_weights = map;
		return this;
	}

	public function speed(name:String, profile:SpeedProfile):ReelSetBuilder {
		_speedProfiles.push({
			name: name,
			spinDelay: profile.spinDelay,
			spinSpeed: profile.spinSpeed,
			stopDelay: profile.stopDelay,
			anticipationDelay: profile.anticipationDelay,
			bounceDistance: profile.bounceDistance,
			bounceDuration: profile.bounceDuration,
			accelerationEase: profile.accelerationEase,
			decelerationEase: profile.decelerationEase,
			accelerationDuration: profile.accelerationDuration,
			minimumSpinTime: profile.minimumSpinTime
		});
		return this;
	}

	public function initialSpeed(name:String):ReelSetBuilder {
		_initialSpeed = name;
		return this;
	}

	public function initialFrame(grid:Array<ColumnTarget>):ReelSetBuilder {
		_initialFrame = grid;
		return this;
	}

	public function rng(fn:() -> Float):ReelSetBuilder {
		_rng = fn;
		return this;
	}

	/**
	 * Enable tumble/cascade mode: Fall → wait → Place → DropIn on spin,
	 * and unlock `ReelSet.refill()`.
	 */
	public function tumble(?config:TumbleConfig):ReelSetBuilder {
		_tumble = TumbleConfigUtil.resolveTumbleConfig(config);
		return this;
	}

	/**
	 * Cylinder curvature for every reel. `0` / omitted = flat.
	 * Pass a number (`0.35`) or `{ amount: 0.5, depth: 0.3 }`.
	 */
	public function curve(input:ReelCurveInput):ReelSetBuilder {
		_curve = input;
		return this;
	}

	/**
	 * Per-reel curvature (length must equal `reels()`).
	 * Overrides `curve()` for listed indices.
	 */
	public function curvePerReel(curves:Array<ReelCurveInput>):ReelSetBuilder {
		_curvePerReel = curves != null ? curves.copy() : null;
		return this;
	}

	/**
	 * Where the camera sits across the strip.
	 * `'reel'` (default) | `'set-lean'` | `'set'`.
	 * Only has effect alongside `curve(...)` / `curvePerReel(...)`.
	 * Lean modes may clip at the per-reel mask edge (no shared mask auto yet).
	 */
	public function curveFocus(focus:CurveFocus):ReelSetBuilder {
		_curveFocus = CurveFocus.parse(Std.string(focus));
		return this;
	}

	/**
	 * How curvature is drawn: `'symbol'` (default, per-cell quads) or `'warp'`
	 * (whole-reel texture + mesh). Warp needs a non-flat `curve(...)` and lets
	 * cascade fall/drop-in ride the drum without per-cell re-keystone.
	 *
	 * builder.curve(0.5).curveMode('warp').curveBleed(24);
	 */
	public function curveMode(mode:CurveMode):ReelSetBuilder {
		_curveMode = CurveMode.parse(Std.string(mode));
		return this;
	}

	/**
	 * Cross-axis overflow room for `curveMode('warp')` textures — art wider
	 * than its cell. Ignored under symbol mode. Also expands the viewport
	 * mask on the cross axis so overhang is not clipped flat.
	 */
	public function curveBleed(pixels:Float):ReelSetBuilder {
		if (Math.isNaN(pixels) || pixels < 0) {
			throw 'curveBleed(): expected a non-negative number, got $pixels.';
		}
		_curveBleed = pixels;
		return this;
	}

	/**
	 * Clip strategy for the viewport mask. Default {@link RectMaskStrategy}.
	 * Board grids and big cross-gap symbols typically use
	 * {@link reels.core.SharedRectMaskStrategy}.
	 *
	 * builder.maskStrategy(new SharedRectMaskStrategy())
	 */
	public function maskStrategy(strategy:MaskStrategy):ReelSetBuilder {
		if (strategy == null) {
			throw "maskStrategy(): expected a MaskStrategy with build(...) and update(...) "
				+ "(e.g. new RectMaskStrategy() or new SharedRectMaskStrategy()).";
		}
		if (strategy.version != MaskStrategyVersion.V2) {
			throw 'maskStrategy(): this strategy declares version ${strategy.version}, '
				+ 'expected ${MaskStrategyVersion.V2}.';
		}
		_maskStrategy = strategy;
		_maskStrategyExplicit = true;
		return this;
	}

	public function build():ReelSet {
		if (_reels == null || _reels < 1) throw "ReelSetBuilder: reels(n) is required";
		if (_symbolW == null || _symbolH == null) throw "ReelSetBuilder: symbolSize(w,h) is required";
		if (_clock == null) throw "ReelSetBuilder: clock(...) is required";
		if (_registry.ids().length == 0) throw "ReelSetBuilder: symbols(...) must register at least one id";
		if (_directionPerReel != null && _directionPerReel.length != _reels) {
			throw 'ReelSetBuilder: directionPerReel() length (${_directionPerReel.length}) must equal reels() ($_reels)';
		}
		if (_curvePerReel != null && _curvePerReel.length != _reels) {
			throw 'ReelSetBuilder: curvePerReel() length (${_curvePerReel.length}) must equal reels() ($_reels)';
		}

		var multiways = _multiways;
		if (multiways != null) {
			if (_visibleCells != null) {
				throw "ReelSetBuilder: multiways() and visibleCells() are mutually exclusive";
			}
			if (multiways.minCells <= 0 || multiways.maxCells <= 0) {
				throw "ReelSetBuilder: multiways({minCells, maxCells}) must both be positive";
			}
			if (multiways.minCells > multiways.maxCells) {
				throw 'ReelSetBuilder: multiways minCells ${multiways.minCells} cannot exceed maxCells ${multiways.maxCells}';
			}
			if (multiways.reelExtent <= 0) {
				throw "ReelSetBuilder: multiways.reelExtent must be > 0";
			}
			_visibleCells = multiways.maxCells;
		} else if (_visibleCells == null || _visibleCells < 1) {
			throw "ReelSetBuilder: visibleCells(n) or multiways({...}) is required";
		}

		// mainProp is orientation-only; any same-orientation axis is fine for bind.
		var bindAxis = ReelAxis.create(_orientation, _direction);
		_registry.bindMainAxis(bindAxis.mainProp);

		var weights = _weights;
		if (emptyWeights(weights)) {
			weights = new Map();
			for (id in _registry.ids()) weights.set(id, 1);
		}

		var random = new RandomSymbolProvider(weights, _rng);
		var events = new EventEmitter();
		var speed = new SpeedManager(events);
		for (p in _speedProfiles) speed.addProfile(p);
		if (speed.has(_initialSpeed)) speed.setSpeed(_initialSpeed);

		var factory = new SymbolFactory(_registry, _symbolW, _symbolH);
		var vpW:Float;
		var vpH:Float;
		if (_orientation == Vertical) {
			vpW = _reels * _symbolW + (_reels - 1) * _gapX;
			vpH = _visibleCells * _symbolH + (_visibleCells - 1) * _gapY;
		} else {
			// Horizontal: cells march on X; reels stack on Y.
			vpW = _visibleCells * _symbolW + (_visibleCells - 1) * _gapX;
			vpH = _reels * _symbolH + (_reels - 1) * _gapY;
		}
		if (multiways != null) {
			if (_orientation == Vertical) vpH = multiways.reelExtent;
			else vpW = multiways.reelExtent;
		}

		// Set-focused curve leans cells across column edges — share one mask
		// (pixi parity). Explicit `.maskStrategy(...)` always wins. Big/unmask
		// auto-pick lands with SymbolData (Big symbols fatia).
		var hasCurve = _curve != null || _curvePerReel != null;
		var curveLeans = _curveFocus != CurveFocus.Reel && hasCurve;
		var crossGapForPick = _orientation == Vertical ? _gapX : _gapY;
		var needShared = curveLeans
			|| ((_registry.hasBigSymbols() || _registry.hasUnmaskedSymbols()) && crossGapForPick > 0);
		if (!_maskStrategyExplicit && needShared) {
			_maskStrategy = new SharedRectMaskStrategy();
			var reason = curveLeans
				? 'curveFocus(\'$_curveFocus\') leans cells across their own reel column'
				: (_registry.hasBigSymbols()
					? "big symbols are registered"
					: "one or more symbols use unmask: true");
			trace(
				"mask-auto-shared: auto-selected SharedRectMaskStrategy because "
					+ reason
					+ ". Pass .maskStrategy(...) explicitly to override."
			);
		}

		if (multiways != null && _registry.hasBigSymbols()) {
			throw "ReelSetBuilder: multiways() and big symbols (size > 1×1) are mutually exclusive";
		}

		if (_curveMode == CurveMode.Warp && hasCurve) {
			trace(
				"warp-skips-unmask: curveMode('warp') does not bend pin overlays, "
					+ "spotlight, or unmask symbols — they render flat above the drum mesh. "
					+ "Use curveMode('symbol') if those must follow the curve."
			);
		}

		var viewport = new ReelViewport(vpW, vpH, _maskStrategy);

		var crossCell = _orientation == Vertical ? _symbolW : _symbolH;
		var crossGap = _orientation == Vertical ? _gapX : _gapY;
		var crossSpan = _reels * crossCell + (_reels - 1) * crossGap;
		var setCentreCross = crossSpan / 2;
		var focusWeight = CurveFocus.weight(_curveFocus);

		var warping = _curveMode == CurveMode.Warp;
		var warpBleed = warping ? _curveBleed : 0;
		var reelList:Array<Reel> = [];
		for (i in 0..._reels) {
			var dir = directionForReel(i);
			var axis = ReelAxis.create(_orientation, dir);
			var frame = new FrameBuilder(_visibleCells, _bufferStart, _bufferEnd, random);
			var focusCross:Null<Float> = null;
			if (focusWeight > 0 && (curveForReel(i) != null)) {
				// Reel-local cross: centreline + lean toward set centre (pixi formula).
				focusCross = crossCell / 2
					+ focusWeight
						* (setCentreCross - i * (crossCell + crossGap) - crossCell / 2);
			}
			var cfg:ReelConfig = {
				index: i,
				visibleCells: _visibleCells,
				bufferStart: _bufferStart,
				bufferEnd: _bufferEnd,
				symbolWidth: _symbolW,
				symbolHeight: _symbolH,
				symbolGapX: _gapX,
				symbolGapY: _gapY,
				axis: axis,
				curve: curveForReel(i),
				curveFocusCross: focusCross,
				warping: warping,
				curveBleed: warpBleed
			};
			var reel = new Reel(cfg, factory, frame);
			reelList.push(reel);
		}

		// Per-reel clip rects (fixed at build — MultiWays reshape keeps extent).
		var maskRects:Array<ReelMaskRect> = [];
		var mainExtent = _orientation == Vertical ? vpH : vpW;
		for (i in 0..._reels) {
			if (_orientation == Vertical) {
				maskRects.push({
					x: i * (_symbolW + _gapX),
					y: 0,
					width: _symbolW,
					height: mainExtent
				});
			} else {
				maskRects.push({
					x: 0,
					y: i * (_symbolH + _gapY),
					width: mainExtent,
					height: _symbolH
				});
			}
		}
		viewport.setMaskRects(maskRects);

		// Clip viewport to the drum edge so the shortfall band (buffer fill)
		// does not read as extra symbols during flat scroll through a curve.
		var maxInset = 0.;
		for (reel in reelList) {
			var c = reel.curve;
			if (c == null) continue;
			var inset = c.edgeInsetMain;
			if (inset > maxInset) maxInset = inset;
		}
		if (maxInset > 0) {
			viewport.setMainInset(maxInset, _orientation == Vertical);
		}
		if (warpBleed > 0) {
			viewport.setCrossBleed(warpBleed, _orientation == Vertical);
		}

		var set = new ReelSet(
			viewport,
			reelList,
			factory,
			_clock,
			events,
			speed,
			_symbolW,
			_symbolH,
			_visibleCells,
			_gapX,
			_gapY,
			_orientation,
			_tumble,
			multiways,
			_adjustDurationMs
		);

		if (_initialFrame != null) {
			ColumnTargets.assertColumnTargets(_initialFrame, "ReelSetBuilder.initialFrame");
			var decorated = BigSymbolCoord.coordinate(
				_initialFrame,
				function(id) return _registry.getSize(id),
				function(_) return _visibleCells,
				_bufferStart,
				_bufferEnd
			);
			for (i in 0...reelList.length) {
				if (i < decorated.length) reelList[i].forceResult(decorated[i]);
			}
		}

		return set;
	}

	function directionForReel(index:Int):Direction {
		if (_directionPerReel != null && index < _directionPerReel.length) {
			return _directionPerReel[index];
		}
		return _direction;
	}

	function curveForReel(index:Int):Null<ReelCurveInput> {
		if (_curvePerReel != null && index < _curvePerReel.length) {
			return _curvePerReel[index];
		}
		return _curve;
	}

	function emptyWeights(map:Map<String, Float>):Bool {
		for (_ in map) return false;
		return true;
	}
}
