package reels;

import openfl.display.Sprite;
import reels.cascade.Cell;
import reels.cascade.DestroySymbolsOptions;
import reels.cascade.RefillOptions;
import reels.cascade.RefillResult;
import reels.cascade.ResolvedTumbleConfig;
import reels.cascade.RunCascadeOptions;
import reels.cascade.RunCascadeResult;
import reels.clock.IFrameClock;
import reels.config.MultiWaysConfig;
import reels.config.MultiWaysMath;
import reels.config.NudgeOptions;
import reels.config.SlamOptions;
import reels.config.SpinOptions;
import reels.core.Orientation;
import reels.core.Reel;
import reels.core.ReelViewport;
import reels.events.EventEmitter;
import reels.events.ReelEvents;
import reels.events.SpinResult;
import reels.frame.ColumnTarget;
import reels.frame.ColumnTargets;
import reels.pins.CellPin;
import reels.pins.CellPin.CellPinOptions;
import reels.pins.MovePinOptions;
import reels.pins.MovePinOptions.CellCoord;
import reels.pins.PinExpireReason;
import reels.pins.PinMigration;
import reels.spotlight.SymbolSpotlight;
import reels.speed.SpeedManager;
import reels.spin.MultiWaysHooks;
import reels.spin.SpinController;
import reels.symbols.ReelSymbol;
import reels.symbols.BigSymbolCoord;
import reels.symbols.SymbolFactory;
import reels.tween.Easing;
import reels.tween.TweenDriver;
import reels.util.IDisposable;
import reels.config.WinTypes.CellBounds;

typedef PinOverlayEntry = {
	pin:CellPin,
	overlay:ReelSymbol,
	displayMain:Float,
	displayCellMain:Float,
	cellCross:Float
};

/**
 * Root reel set: OpenFL Sprite + spin orchestration.
 */
class ReelSet implements IDisposable {
	public final view:Sprite;
	public final events:EventEmitter;
	public final speed:SpeedManager;

	var _viewport:ReelViewport;
	var _reels:Array<Reel>;
	var _factory:SymbolFactory;
	var _clock:IFrameClock;
	var _tweens:TweenDriver;
	var _controller:SpinController;
	var _destroyed:Bool = false;
	var _onTick:Float->Void;
	var _symbolWidth:Float;
	var _symbolHeight:Float;
	var _symbolGapX:Float;
	var _symbolGapY:Float;
	var _orientation:Orientation;
	var _visibleCells:Int;
	var _reelCount:Int;
	var _cascade:Bool;
	var _cascadeRunning:Bool = false;
	var _multiways:Null<MultiWaysConfig>;
	var _adjustDurationMs:Float;
	var _targetShape:Null<Array<Int>> = null;
	var _resultSetForCurrentSpin:Bool = false;
	var _pins:Map<String, CellPin> = new Map();
	var _spotlight:SymbolSpotlight;
	/**
	 * Pin overlays on unmasked. `displayMain` / `displayCellMain` are reel-local
	 * (no host bounce); baked to screen each tick. Size is tweened across MW reshape.
	 */
	var _pinOverlays:Map<String, PinOverlayEntry> = new Map();
	var _pinOverlayTweens:Array<reels.tween.TweenHandle> = [];
	var _pinFlightActive:Bool = false;
	var _pinFlight:Null<ReelSymbol> = null;
	var _pinFlightTweens:Array<reels.tween.TweenHandle> = [];
	var _nudgesInFlight:Int = 0;

	@:allow(reels.ReelSetBuilder)
	function new(
		viewport:ReelViewport,
		reels:Array<Reel>,
		factory:SymbolFactory,
		clock:IFrameClock,
		events:EventEmitter,
		speed:SpeedManager,
		symbolWidth:Float,
		symbolHeight:Float,
		visibleCells:Int,
		symbolGapX:Float = 0,
		symbolGapY:Float = 0,
		orientation:Orientation = Vertical,
		?tumble:ResolvedTumbleConfig,
		?multiways:MultiWaysConfig,
		adjustDurationMs:Float = 0
	) {
		_viewport = viewport;
		view = viewport.view;
		_reels = reels;
		_factory = factory;
		_clock = clock;
		this.events = events;
		this.speed = speed;
		_tweens = new TweenDriver();
		_symbolWidth = symbolWidth;
		_symbolHeight = symbolHeight;
		_symbolGapX = symbolGapX;
		_symbolGapY = symbolGapY;
		_orientation = orientation;
		_visibleCells = visibleCells;
		_reelCount = reels.length;
		_cascade = tumble != null;
		_multiways = multiways;
		_adjustDurationMs = adjustDurationMs;

		var hooks:MultiWaysHooks = {
			isMultiWays: multiways != null,
			peekTargetShape: function() return _targetShape,
			clearTargetShape: function() {
				_targetShape = null;
			},
			applyReshape: applyReshapeForReel,
			snapPinOverlaysForReel: snapPinOverlaysForReel,
			adjustDurationMs: _adjustDurationMs
		};
		_controller = new SpinController(reels, speed, events, tumble, hooks);

		for (i in 0...reels.length) {
			var reel = reels[i];
			if (orientation == Vertical) {
				reel.host.x = i * (symbolWidth + _symbolGapX);
			} else {
				reel.host.y = i * (symbolHeight + _symbolGapY);
			}
			reel.captureRestHostMain();
			if (reel.warping && reel.warp != null) {
				// Host stays off-list — only the warp mesh is visible.
				reel.syncWarpViewPosition();
				viewport.content.addChild(reel.warp.view);
			} else {
				viewport.content.addChild(reel.host);
			}
		}

		_onTick = onTick;
		_clock.add(_onTick);

		_spotlight = new SymbolSpotlight(reels, viewport, events, _tweens);

		events.on(ReelEvents.SPIN_START, function(_) {
			onPinSpinStart();
		});
		events.on(ReelEvents.SPIN_ALL_LANDED, function(_) {
			onPinSpinLanded();
		});
	}

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	public var isDestroyed(get, never):Bool;

	public var isCascade(get, never):Bool;

	function get_isCascade():Bool {
		return _cascade;
	}

	public var isMultiWays(get, never):Bool;

	function get_isMultiWays():Bool {
		return _multiways != null;
	}

	/** Main-axis mask inset applied for curved drums (0 when flat). */
	public var maskMainInset(get, never):Float;

	function get_maskMainInset():Float {
		return _viewport.mainInset;
	}

	/** Viewport host (mask strategy / rects — tests and advanced layout). */
	public var viewport(get, never):ReelViewport;

	function get_viewport():ReelViewport {
		return _viewport;
	}

	/** Cross-axis mask expansion from `curveBleed` (0 in symbol mode). */
	public var maskCrossBleed(get, never):Float;

	function get_maskCrossBleed():Float {
		return _viewport.crossBleed;
	}

	public var isSpinning(get, never):Bool;

	function get_isSpinning():Bool {
		return _controller.isSpinning;
	}

	public var reelCount(get, never):Int;

	function get_reelCount():Int {
		return _reelCount;
	}

	public function getReel(index:Int):Reel {
		return _reels[index];
	}

	/** Frame-clock tween driver (spotlight / WinPresenter waits share this). */
	public var tweens(get, never):TweenDriver;

	function get_tweens():TweenDriver {
		return _tweens;
	}

	/** Win celebration primitive (dim + promote + playWin). */
	public var spotlight(get, never):SymbolSpotlight;

	function get_spotlight():SymbolSpotlight {
		return _spotlight;
	}

	/**
	 * Axis-aligned bounds of a visible cell in ReelSet/viewport-local pixels.
	 * On a curved reel this is the projected quad's bounding box.
	 */
	public function getCellBounds(reel:Int, cell:Int):CellBounds {
		ensureAlive();
		if (reel < 0 || reel >= _reels.length) {
			throw 'getCellBounds: reel $reel out of range [0, ${_reels.length})';
		}
		var target = _reels[reel];
		if (cell < 0 || cell >= target.visibleCells) {
			throw 'getCellBounds: cell $cell out of range [0, ${target.visibleCells})';
		}
		var axis = target.axis;
		var flatMain = cell * target.slotPitch;
		var hostCross = axis.crossProp == "x" ? target.host.x : target.host.y;
		var hostMain = target.restHostMain;
		var origin = axis.toScreen(hostCross, hostMain + flatMain);
		var cellCross = _orientation == Vertical ? target.symbolWidth : target.symbolHeight;
		var cellMain = _orientation == Vertical ? target.symbolHeight : target.symbolWidth;
		var flat = axis.toScreen(cellCross, cellMain);

		var curve = target.curve;
		if (curve == null || curve.isFlat) {
			return {
				x: origin.x,
				y: origin.y,
				width: flat.x,
				height: flat.y
			};
		}
		var quad = curve.quadFor(flatMain);
		if (quad == null) {
			return {
				x: origin.x,
				y: origin.y,
				width: flat.x,
				height: flat.y
			};
		}
		var minX = Math.min(Math.min(quad.x0, quad.x1), Math.min(quad.x2, quad.x3));
		var maxX = Math.max(Math.max(quad.x0, quad.x1), Math.max(quad.x2, quad.x3));
		var minY = Math.min(Math.min(quad.y0, quad.y1), Math.min(quad.y2, quad.y3));
		var maxY = Math.max(Math.max(quad.y0, quad.y1), Math.max(quad.y2, quad.y3));
		return {
			x: origin.x + minX,
			y: origin.y + minY,
			width: maxX - minX,
			height: maxY - minY
		};
	}

	public function getVisibleGrid():Array<Array<String>> {
		return [for (r in _reels) r.getVisibleIds()];
	}

	/**
	 * MultiWays: set per-reel visible cell counts for the current spin.
	 * Call after `spin()` and BEFORE `setResult()`.
	 */
	public function setShape(cellsPerReel:Array<Int>):Void {
		ensureAlive();
		assertNoNudgeInFlight("setShape");
		if (_multiways == null) {
			throw "ReelSet.setShape: requires ReelSetBuilder.multiways()";
		}
		if (_resultSetForCurrentSpin) {
			throw "ReelSet.setShape: must be called BEFORE setResult() in the same spin";
		}
		if (cellsPerReel.length != _reelCount) {
			throw 'ReelSet.setShape: length ${cellsPerReel.length} must equal reel count $_reelCount';
		}
		var mw = _multiways;
		var unchanged = true;
		for (i in 0...cellsPerReel.length) {
			var n = cellsPerReel[i];
			if (n < mw.minCells || n > mw.maxCells) {
				throw 'ReelSet.setShape: cells[$i]=$n out of range [${mw.minCells}, ${mw.maxCells}]';
			}
			if (n != _reels[i].visibleCells) unchanged = false;
		}
		if (unchanged) return;
		_targetShape = cellsPerReel.copy();
		for (i in 0...cellsPerReel.length) {
			migratePinsForReel(i, cellsPerReel[i]);
		}
		events.emit(ReelEvents.SHAPE_CHANGED, [_targetShape.copy()]);
	}

	function expectedVisibleCells(reelIndex:Int):Int {
		if (_targetShape != null && reelIndex < _targetShape.length) {
			return _targetShape[reelIndex];
		}
		return _reels[reelIndex].visibleCells;
	}

	function mainGap():Float {
		return _orientation == Vertical ? _symbolGapY : _symbolGapX;
	}

	function applyReshapeForReel(reelIndex:Int, targetCells:Int):Void {
		var reel = _reels[reelIndex];
		var from = reel.visibleCells;
		var oldCellMain = _orientation == Vertical ? reel.symbolHeight : reel.symbolWidth;
		var oldCross = _orientation == Vertical ? reel.symbolWidth : reel.symbolHeight;
		var cellMain = MultiWaysMath.cellMain(_multiways.reelExtent, targetCells, mainGap());
		events.emit(ReelEvents.ADJUST_START, [{
			reelIndex: reelIndex,
			fromCells: from,
			toCells: targetCells
		}]);

		// Capture overlay poses BEFORE geometry commit (pixi buildPinOverlayTweens).
		var overlays:Array<PinOverlayEntry> = [];
		for (entry in _pinOverlays) {
			if (entry.pin.reel == reelIndex) overlays.push(entry);
		}

		reel.reshape(targetCells, cellMain, reel.bufferStart, reel.bufferEnd);
		refreshCurveInset();

		// Tween overlays: main position + cell size (pixi AdjustPhase / pinMigrationDuration).
		// Do NOT snap via refreshPinOverlaysForReel — that was the sticky jump.
		var newPitch = reel.slotPitch;
		var newCellMain = _orientation == Vertical ? reel.symbolHeight : reel.symbolWidth;
		var newCross = _orientation == Vertical ? reel.symbolWidth : reel.symbolHeight;
		var dur = _adjustDurationMs;
		var ease = Easing.quadInOut;
		for (entry in overlays) {
			var toMain = entry.pin.cell * newPitch;
			// Hold pre-reshape visual size until the tween (or snap) finishes.
			entry.displayCellMain = oldCellMain;
			entry.cellCross = oldCross;
			if (dur <= 0) {
				entry.displayMain = toMain;
				entry.displayCellMain = newCellMain;
				entry.cellCross = newCross;
			} else {
				if (Math.abs(toMain - entry.displayMain) >= 1e-6) {
					_pinOverlayTweens.push(_tweens.to(
						function() return entry.displayMain,
						function(v) entry.displayMain = v,
						toMain,
						dur,
						ease
					));
				} else {
					entry.displayMain = toMain;
				}
				if (Math.abs(newCellMain - oldCellMain) >= 1e-6) {
					_pinOverlayTweens.push(_tweens.to(
						function() return entry.displayCellMain,
						function(v) entry.displayCellMain = v,
						newCellMain,
						dur,
						ease,
						function() {
							entry.cellCross = newCross;
						}
					));
				} else {
					entry.displayCellMain = newCellMain;
					entry.cellCross = newCross;
				}
			}
		}
		syncPinOverlayViews();

		events.emit(ReelEvents.ADJUST_COMPLETE, [{
			reelIndex: reelIndex,
			fromCells: from,
			toCells: targetCells
		}]);
	}

	/** Slam / AdjustPhase skip: finish in-flight overlay tweens for one reel. */
	function snapPinOverlaysForReel(reelIndex:Int):Void {
		killPinOverlayTweens();
		var reel = _reels[reelIndex];
		var cellMain = _orientation == Vertical ? reel.symbolHeight : reel.symbolWidth;
		var cellCross = _orientation == Vertical ? reel.symbolWidth : reel.symbolHeight;
		for (entry in _pinOverlays) {
			if (entry.pin.reel != reelIndex) continue;
			entry.displayMain = entry.pin.cell * reel.slotPitch;
			entry.displayCellMain = cellMain;
			entry.cellCross = cellCross;
		}
		syncPinOverlayViews();
	}

	function refreshCurveInset():Void {
		var maxInset = 0.;
		var minCellMain = Math.POSITIVE_INFINITY;
		for (reel in _reels) {
			var cellMain = _orientation == Vertical ? reel.symbolHeight : reel.symbolWidth;
			if (cellMain < minCellMain) minCellMain = cellMain;
			var c = reel.curve;
			if (c == null) continue;
			if (c.edgeInsetMain > maxInset) maxInset = c.edgeInsetMain;
		}
		// MultiWays: cell height changes per reel. A viewport-wide inset sized
		// for the strongest curve can swallow outer cells of taller rows —
		// and a sticky pin overlay (unmasked) then looks like the only survivor.
		if (_multiways != null && minCellMain < Math.POSITIVE_INFINITY) {
			var cap = minCellMain * 0.35;
			if (maxInset > cap) maxInset = cap;
		}
		_viewport.setMainInset(maxInset, _orientation == Vertical);
	}

	/**
	 * Start spinning. With `.tumble()`: Fall → wait → Place → DropIn.
	 */
	public function spin(?options:SpinOptions, ?onComplete:SpinResult->Void):Void {
		ensureAlive();
		assertNoNudgeInFlight("spin");
		var hold = options != null ? options.holdReels : null;
		_controller.spin(hold, function(result) {
			if (onComplete != null) onComplete(result);
		});
	}

	public function setResult(grid:Array<ColumnTarget>):Void {
		ensureAlive();
		assertNoNudgeInFlight("setResult");
		ColumnTargets.assertColumnTargets(grid, "ReelSet.setResult");
		if (grid.length != _reelCount) {
			throw 'ReelSet.setResult: expected ${_reelCount} columns, got ${grid.length}';
		}
		for (i in 0...grid.length) {
			var expected = expectedVisibleCells(i);
			if (grid[i].visible.length != expected) {
				throw 'ReelSet.setResult: column $i visible length ${grid[i].visible.length} != $expected';
			}
		}
		_resultSetForCurrentSpin = true;
		var decorated = BigSymbolCoord.coordinate(
			applyPinsToGrid(cloneTargets(grid)),
			function(id) return _factory.getSize(id),
			function(i) return expectedVisibleCells(i),
			_reels[0].bufferStart,
			_reels[0].bufferEnd
		);
		_controller.setResult(decorated);
	}

	/**
	 * Footprint of the block covering (reel, cell). Resolves OCCUPIED stubs
	 * to the anchor id. Default 1×1 when no big metadata.
	 */
	public function getSymbolFootprint(
		reel:Int,
		cell:Int
	):{reel:Int, cell:Int, reels:Int, cells:Int, symbolId:String} {
		ensureAlive();
		if (reel < 0 || reel >= _reelCount) {
			throw 'getSymbolFootprint: reel $reel out of range';
		}
		var r = _reels[reel];
		if (cell < 0 || cell >= r.visibleCells) {
			throw 'getSymbolFootprint: cell $cell out of range';
		}
		var anchorCell = r.getAnchorCell(cell);
		var symbolId = r.getVisibleIds()[anchorCell];
		var size = _factory.getSize(symbolId);
		var anchorReel = reel;
		// Cross-reel: walk left for an anchor whose block covers this cell.
		if (size.reels <= 1 && size.cells <= 1) {
			for (rr in 0...(reel + 1)) {
				var other = _reels[rr];
				var oids = other.getVisibleIds();
				for (cc in 0...other.visibleCells) {
					var sid = oids[cc];
					var sz = _factory.getSize(sid);
					if (!BigSymbolCoord.isBig(sz)) continue;
					if (rr <= reel && reel < rr + sz.reels
						&& cc <= cell && cell < cc + sz.cells) {
						anchorReel = rr;
						anchorCell = cc;
						symbolId = sid;
						size = sz;
					}
				}
			}
		}
		return {
			reel: anchorReel,
			cell: anchorCell,
			reels: size.reels,
			cells: size.cells,
			symbolId: symbolId
		};
	}

	/**
	 * Shift one reel by `distance` positions while at rest (fruit-machine nudge).
	 * Callback style. Emits `nudge:start` / `nudge:complete` / `nudge:cancelled`.
	 */
	public function nudge(
		reel:Int,
		options:NudgeOptions,
		?onComplete:(symbols:Array<String>) -> Void
	):Void {
		ensureAlive();
		if (_controller.isSpinning) {
			throw "nudge: cannot nudge while a spin or refill is in progress.";
		}
		if (reel < 0 || reel >= _reelCount) {
			throw 'nudge: reel $reel out of range [0, $_reelCount).';
		}
		if (_reels[reel].bufferEnd < 1) {
			throw "nudge: requires bufferEnd >= 1.";
		}
		for (pin in _pins) {
			if (pin.reel == reel) {
				throw 'nudge: reel $reel has an active pin at cell ${pin.cell}. '
					+ 'Call unpin($reel, ${pin.cell}) first if you intend to nudge through it.';
			}
		}

		_nudgesInFlight++;
		var settled = false;
		function settle():Void {
			if (settled) return;
			settled = true;
			_nudgesInFlight--;
		}

		_reels[reel].nudge(
			options,
			_tweens,
			function() {
				events.emit(ReelEvents.NUDGE_START, [
					{
						reelIndex: reel,
						distance: options.distance,
						direction: options.direction
					}
				]);
			},
			function(symbols) {
				settle();
				events.emit(ReelEvents.NUDGE_COMPLETE, [
					{
						reelIndex: reel,
						distance: options.distance,
						direction: options.direction,
						symbols: symbols
					}
				]);
				if (onComplete != null) onComplete(symbols);
			},
			function(reason) {
				settle();
				if (!_destroyed) {
					events.emit(ReelEvents.NUDGE_CANCELLED, [
						{
							reelIndex: reel,
							distance: options.distance,
							direction: options.direction,
							reason: reason
						}
					]);
				}
			}
		);
	}

	/** Fast-forward in-flight nudge(s). Omit reel to skip all. */
	public function skipNudge(?reel:Null<Int>):Void {
		ensureAlive();
		if (reel == null) {
			for (r in _reels) {
				if (r.isNudging) r.skipNudge();
			}
			return;
		}
		if (reel < 0 || reel >= _reelCount) {
			throw 'skipNudge: reel $reel out of range [0, $_reelCount).';
		}
		_reels[reel].skipNudge();
	}

	function assertNoNudgeInFlight(method:String):Void {
		if (_nudgesInFlight > 0) {
			throw 'ReelSet.$method: cannot be called while nudge() is in flight. '
				+ 'Await the nudge callback before calling $method.';
		}
	}

	/**
	 * Pin a symbol to a grid cell. Idle → apply visually now; mid-spin → overlay.
	 * Same (reel, cell) replaces silently (no pin:expired).
	 */
	public function pin(reel:Int, cell:Int, symbolId:String, ?options:CellPinOptions):CellPin {
		ensureAlive();
		assertNoNudgeInFlight("pin");
		if (reel < 0 || reel >= _reelCount) {
			throw 'pin(): reel $reel out of range [0, $_reelCount)';
		}
		var target = _reels[reel];
		if (cell < 0 || cell >= target.visibleCells) {
			throw 'pin(): cell $cell out of range [0, ${target.visibleCells})';
		}
		if (options == null) options = {};
		var migration = CellPin.parseMigration(options.migration);
		var turns = CellPin.parseTurns(options.turns);
		var origin = options.originCell != null ? options.originCell : cell;
		var pin = new CellPin(reel, cell, symbolId, origin, migration, turns, options.payload);

		var key = CellPin.pinKey(reel, cell);
		if (_pins.exists(key)) {
			destroyPinOverlay(key);
		}
		_pins.set(key, pin);

		if (!_controller.isSpinning) {
			applyPinVisually(reel, cell, symbolId);
		} else {
			ensurePinOverlay(pin);
		}

		events.emit(ReelEvents.PIN_PLACED, [pin]);
		return pin;
	}

	/** Remove pin at (reel, cell). No-op if absent. Fires pin:expired explicit. */
	public function unpin(reel:Int, cell:Int):Void {
		ensureAlive();
		var key = CellPin.pinKey(reel, cell);
		var pin = _pins.get(key);
		if (pin == null) return;
		_pins.remove(key);
		destroyPinOverlay(key);
		events.emit(ReelEvents.PIN_EXPIRED, [pin, PinExpireReason.Explicit]);
	}

	/**
	 * Move a pin from one cell to another with a flight animation (walking wild).
	 * Idle only — throws if spinning or a flight is already in progress.
	 * Callback style (pixi returns a Promise).
	 */
	public function movePin(
		from:CellCoord,
		to:CellCoord,
		?opts:MovePinOptions,
		?onComplete:() -> Void
	):Void {
		ensureAlive();
		assertNoNudgeInFlight("movePin");
		if (_controller.isSpinning) {
			throw "movePin(): cannot move pin while spinning";
		}
		if (_pinFlightActive) {
			throw "movePin(): flight already in progress";
		}

		var fromKey = CellPin.pinKey(from.reel, from.cell);
		var pin = _pins.get(fromKey);
		if (pin == null) {
			throw 'movePin(): no pin at (${from.reel}, ${from.cell})';
		}
		if (to.reel < 0 || to.reel >= _reelCount) {
			throw 'movePin(): to reel ${to.reel} out of range [0, $_reelCount)';
		}
		var toReel = _reels[to.reel];
		if (to.cell < 0 || to.cell >= toReel.visibleCells) {
			throw 'movePin(): to cell ${to.cell} out of range [0, ${toReel.visibleCells})';
		}

		if (from.reel == to.reel && from.cell == to.cell) {
			events.emit(ReelEvents.PIN_MOVED, [pin, {reel: from.reel, cell: from.cell}]);
			if (onComplete != null) onComplete();
			return;
		}

		var toKey = CellPin.pinKey(to.reel, to.cell);
		if (_pins.exists(toKey)) {
			throw 'movePin(): a pin already exists at (${to.reel}, ${to.cell})';
		}

		_pins.remove(fromKey);
		pin.reel = to.reel;
		pin.cell = to.cell;
		pin.originCell = to.cell;
		_pins.set(toKey, pin);

		destroyPinOverlay(fromKey);

		var fromReel = _reels[from.reel];
		var fromPoint = pinOverlayScreenPoint(fromReel, from.cell);
		var toPoint = pinOverlayScreenPoint(toReel, to.cell);

		var backfill = opts != null && opts.backfill != null
			? opts.backfill
			: fromReel.randomFillerId();
		fromReel.setVisibleSymbol(from.cell, backfill);
		fromReel.revealAllVisible();

		var flight = _factory.acquire(pin.symbolId);
		flight.resize(fromReel.symbolWidth, fromReel.symbolHeight);
		var fd = flight.displayObject;
		if (fd != null) {
			fd.x = fromPoint.x;
			fd.y = fromPoint.y;
			_viewport.unmasked.addChild(fd);
		} else {
			flight.x = fromPoint.x;
			flight.y = fromPoint.y;
		}

		_pinFlightActive = true;
		_pinFlight = flight;

		try {
			if (opts != null && opts.onFlightCreated != null) opts.onFlightCreated(flight);
		} catch (e:Dynamic) {
			// Pixi parity: hook throw must not abort the flight / leak the symbol.
			trace('movePin onFlightCreated threw: $e');
		}

		var duration = opts != null && opts.duration != null ? opts.duration : 400.;
		var easeName = opts != null && opts.easing != null ? opts.easing : "power2.inOut";
		var ease = Easing.resolve(easeName);

		function finishFlight():Void {
			try {
				if (opts != null && opts.onFlightCompleted != null) opts.onFlightCompleted(flight);
			} catch (e:Dynamic) {
				trace('movePin onFlightCompleted threw: $e');
			}

			toReel.setVisibleSymbol(to.cell, pin.symbolId);
			toReel.revealAllVisible();

			if (fd != null && fd.parent != null) fd.parent.removeChild(fd);
			_factory.release(flight);
			_pinFlight = null;
			_pinFlightActive = false;
			_pinFlightTweens = [];

			events.emit(ReelEvents.PIN_MOVED, [pin, {reel: from.reel, cell: from.cell}]);
			if (onComplete != null) onComplete();
		}

		if (duration <= 0) {
			if (fd != null) {
				fd.x = toPoint.x;
				fd.y = toPoint.y;
			} else {
				flight.x = toPoint.x;
				flight.y = toPoint.y;
			}
			finishFlight();
			return;
		}

		var flightX = fromPoint.x;
		var flightY = fromPoint.y;
		var fromMain = from.cell * fromReel.slotPitch;
		var toMain = to.cell * toReel.slotPitch;
		var curveReel = toReel; // bend toward destination drum
		var pending = 2;
		function oneDone():Void {
			pending--;
			if (pending <= 0) {
				flight.applyCellQuad(null);
				finishFlight();
			}
		}
		function projectFlight(t:Float):Void {
			var main = fromMain + (toMain - fromMain) * t;
			var curve = curveReel.curve;
			if (curve != null && !curve.isFlat) {
				flight.applyCellQuad(curve.quadFor(main, flight.cellInset));
			} else {
				flight.applyCellQuad(null);
			}
		}
		projectFlight(0);
		var progress = 0.;
		_pinFlightTweens.push(_tweens.to(
			function() return progress,
			function(p) {
				progress = p;
				flightX = fromPoint.x + (toPoint.x - fromPoint.x) * p;
				flightY = fromPoint.y + (toPoint.y - fromPoint.y) * p;
				if (fd != null) {
					fd.x = flightX;
					fd.y = flightY;
				} else {
					flight.x = flightX;
					flight.y = flightY;
				}
				projectFlight(p);
			},
			1,
			duration,
			ease,
			function() {
				pending = 0;
				flight.applyCellQuad(null);
				finishFlight();
			}
		));
	}

	public var pins(get, never):Map<String, CellPin>;

	function get_pins():Map<String, CellPin> {
		return _pins;
	}

	public function getPin(reel:Int, cell:Int):Null<CellPin> {
		return _pins.get(CellPin.pinKey(reel, cell));
	}

	/**
	 * Reposition pin overlays on a reel after layout mutation outside MultiWays.
	 * Engine calls this after reshape; apps rarely need it.
	 */
	public function refreshPinOverlaysForReel(reelIndex:Int):Void {
		if (reelIndex < 0 || reelIndex >= _reelCount) return;
		var reel = _reels[reelIndex];
		var cellMain = _orientation == Vertical ? reel.symbolHeight : reel.symbolWidth;
		var cellCross = _orientation == Vertical ? reel.symbolWidth : reel.symbolHeight;
		for (entry in _pinOverlays) {
			if (entry.pin.reel != reelIndex) continue;
			entry.displayMain = entry.pin.cell * reel.slotPitch;
			entry.displayCellMain = cellMain;
			entry.cellCross = cellCross;
		}
		syncPinOverlayViews();
	}

	/** Moment B cascade refill (requires `.tumble()`). Mode: combined only. */
	public function refill(opts:RefillOptions, onComplete:RefillResult->Void):Void {
		ensureAlive();
		ColumnTargets.assertColumnTargets(opts.grid, "ReelSet.refill");
		if (opts.grid.length != _reelCount) {
			throw 'ReelSet.refill: expected ${_reelCount} columns, got ${opts.grid.length}';
		}
		for (i in 0...opts.grid.length) {
			var expected = _reels[i].visibleCells;
			if (opts.grid[i].visible.length != expected) {
				throw 'ReelSet.refill: column $i visible length ${opts.grid[i].visible.length} != $expected';
			}
		}
		// Sticky / expanding wilds: force pin ids into the refill grid the same
		// way setResult does. Without this the strip lands a random symbol under
		// the pin and the next spin's overlay floats WILD on top of it.
		var pinned:RefillOptions = {
			winners: filterUnpinnedWinners(opts.winners),
			grid: applyPinsToGrid(cloneTargets(opts.grid)),
			mode: opts.mode,
			gravityHoldMs: opts.gravityHoldMs,
			gravityHold: opts.gravityHold,
			onGravityComplete: opts.onGravityComplete
		};
		_controller.refill(pinned, onComplete);
	}

	/**
	 * Animate winners out (alpha collapse). Empty list is a no-op (no events).
	 * Pinned cells are skipped — sticky symbols must not fade mid-cascade.
	 */
	public function destroySymbols(
		cells:Array<Cell>,
		?opts:DestroySymbolsOptions,
		?onComplete:() -> Void
	):Void {
		ensureAlive();
		if (cells.length == 0) {
			if (onComplete != null) onComplete();
			return;
		}

		for (cell in cells) {
			if (cell.reel < 0 || cell.reel >= _reelCount) {
				throw 'destroySymbols: cell.reel ${cell.reel} out of range [0, $_reelCount)';
			}
			var reel = _reels[cell.reel];
			if (cell.cell < 0 || cell.cell >= reel.visibleCells) {
				throw 'destroySymbols: cell.cell ${cell.cell} out of range [0, ${reel.visibleCells}) for reel ${cell.reel}';
			}
		}

		var targets = filterUnpinnedWinners(cells);
		if (targets.length == 0) {
			if (onComplete != null) onComplete();
			return;
		}

		var baseDelay = opts != null && opts.delay != null ? opts.delay : 0.;
		var stagger = opts != null && opts.staggerMs != null ? opts.staggerMs : 0.;
		var duration = opts != null && opts.durationMs != null ? opts.durationMs : 200.;

		events.emit(ReelEvents.CASCADE_DESTROY_START, [targets]);
		var pending = targets.length;
		function oneDone():Void {
			pending--;
			if (pending <= 0) {
				events.emit(ReelEvents.CASCADE_DESTROY_END, [targets]);
				if (onComplete != null) onComplete();
			}
		}

		for (i in 0...targets.length) {
			var cell = targets[i];
			var sym = _reels[cell.reel].getVisibleSymbol(cell.cell);
			var delay = baseDelay + stagger * i;
			sym.playDestroy({delay: delay, duration: duration}, oneDone, _tweens);
		}
	}

	/**
	 * Canonical cascade loop: detect → present → destroy → pause → refill → …
	 * until `detectWinners` returns empty (or maxChain / skip).
	 */
	public function runCascade(opts:RunCascadeOptions, onComplete:RunCascadeResult->Void):Void {
		ensureAlive();
		if (!_cascade) throw "runCascade() requires ReelSetBuilder.tumble()";
		if (_cascadeRunning) throw "runCascade() already in progress";
		if (_controller.isSpinning) throw "runCascade() called while spin/refill is active";

		_cascadeRunning = true;
		var pauseMs = opts.pauseAfterDestroyMs != null ? opts.pauseAfterDestroyMs : 250.;
		var maxChain = opts.maxChain != null ? opts.maxChain : 32;
		var wasSkipped = false;
		function skipListener(_:Array<Dynamic>):Void {
			wasSkipped = true;
		}
		events.on(ReelEvents.SKIP_REQUESTED, skipListener);

		var chainLength = 0;
		var totalWinners = 0;
		var current = getVisibleGrid();
		var step:() -> Void = null;

		function finish():Void {
			events.off(ReelEvents.SKIP_REQUESTED, skipListener);
			_cascadeRunning = false;
			onComplete({
				chainLength: chainLength,
				totalWinners: totalWinners,
				finalGrid: current,
				wasSkipped: wasSkipped
			});
		}

		function afterPause(winners:Array<Cell>, stage:Int):Void {
			if (wasSkipped) {
				finish();
				return;
			}
			var next = opts.nextGrid(current, winners, chainLength);
			ColumnTargets.assertColumnTargets(next, "runCascade(): nextGrid");
			if (next.length != _reelCount) {
				throw 'runCascade(): nextGrid expected $_reelCount columns, got ${next.length}';
			}
			refill({
				winners: winners.copy(),
				grid: next,
				mode: opts.refillMode != null ? opts.refillMode : "combined",
				gravityHoldMs: opts.gravityHoldMs,
				gravityHold: opts.gravityHold,
				onGravityComplete: opts.onGravityComplete
			}, function(_) {
				chainLength += 1;
				current = getVisibleGrid();
				events.emit(ReelEvents.CASCADE_CHAIN_END, [{
					chain: stage,
					winners: winners,
					nextGrid: current
				}]);
				step();
			});
		}

		function afterDestroy(winners:Array<Cell>, stage:Int):Void {
			if (wasSkipped) {
				finish();
				return;
			}
			if (opts.onCascade != null) opts.onCascade(stage, winners);
			if (wasSkipped) {
				finish();
				return;
			}
			if (pauseMs > 0) {
				_tweens.to(function() return 0., function(_) {}, 1, pauseMs, Easing.linear, function() {
					afterPause(winners, stage);
				});
			} else {
				afterPause(winners, stage);
			}
		}

		step = function():Void {
			if (wasSkipped || chainLength >= maxChain) {
				finish();
				return;
			}
			var winners = opts.detectWinners(current, chainLength);
			if (winners.length == 0) {
				finish();
				return;
			}
			totalWinners += winners.length;
			var stage = chainLength + 1;
			events.emit(ReelEvents.CASCADE_CHAIN_START, [{
				chain: stage,
				winners: winners,
				currentGrid: current
			}]);

			if (opts.presentWinners != null) {
				opts.presentWinners(stage, winners);
				if (wasSkipped) {
					finish();
					return;
				}
			}

			destroySymbols(winners, opts.destroyOptions, function() {
				afterDestroy(winners, stage);
			});
		};

		step();
	}

	public function setAnticipation(indices:Array<Int>):Void {
		_controller.setAnticipation(indices);
	}

	public function setStopDelays(delays:Array<Float>):Void {
		_controller.setStopDelays(delays);
	}

	public function skipSpin():Void {
		_controller.skipSpin();
	}

	public function slamStop(?opts:SlamOptions):Void {
		_controller.slamStop(opts);
	}

	public function setSpeed(name:String):Void {
		speed.setSpeed(name);
		_controller.notifyManualSpeedChange();
	}

	function onTick(deltaMs:Float):Void {
		if (_destroyed) return;
		_tweens.update(deltaMs);
		_controller.update(deltaMs);
		// Pin overlays stay at restHostMain (sticky) — sync for MW size/main tweens,
		// not StopPhase bounce (following bounce leaks bottom pins past the mask).
		if (_pinOverlays.keys().hasNext()) syncPinOverlayViews();
		// Warp textures must refresh every frame (win pulses, cascade, rest).
		for (reel in _reels) reel.updateWarp();
	}

	function ensureAlive():Void {
		if (_destroyed) throw "ReelSet used after destroy()";
	}

	public function destroy():Void {
		if (_destroyed) return;
		_destroyed = true;
		_cascadeRunning = false;
		_clock.remove(_onTick);
		abortPinFlight();
		if (_spotlight != null) _spotlight.destroy();
		_tweens.killAll();
		destroyAllPinOverlays();
		clearUnmaskedChildren();
		_pins.clear();
		for (r in _reels) r.destroy();
		_factory.destroy();
		_viewport.destroy();
		events.removeAllListeners();
	}

	// ─── Pin internals ────────────────────────────────────────

	function cloneTargets(grid:Array<ColumnTarget>):Array<ColumnTarget> {
		return [
			for (col in grid) {
				visible: col.visible.copy(),
				bufferStart: col.bufferStart != null ? col.bufferStart.copy() : null,
				bufferEnd: col.bufferEnd != null ? col.bufferEnd.copy() : null
			}
		];
	}

	function applyPinsToGrid(symbols:Array<ColumnTarget>):Array<ColumnTarget> {
		for (pin in _pins) {
			if (pin.reel < 0 || pin.reel >= symbols.length) continue;
			var reel = symbols[pin.reel];
			if (pin.cell >= 0 && pin.cell < reel.visible.length) {
				reel.visible[pin.cell] = pin.symbolId;
			}
		}
		return symbols;
	}

	/** Drop pinned cells from a winner list so cascade gravity leaves stickies put. */
	function filterUnpinnedWinners(cells:Array<Cell>):Array<Cell> {
		if (cells == null || cells.length == 0) return cells != null ? cells : [];
		if (!_pins.keys().hasNext()) return cells;
		return [
			for (c in cells)
				if (_pins.get(CellPin.pinKey(c.reel, c.cell)) == null) c
		];
	}

	function applyPinVisually(reel:Int, cell:Int, symbolId:String):Void {
		var target = _reels[reel];
		if (cell < 0 || cell >= target.visibleCells) return;
		// Always go through setVisibleSymbol — same-id path reseats the DO
		// onto the strip host (overlay addChild may have stolen it).
		target.setVisibleSymbol(cell, symbolId);
		target.revealAllVisible();
	}

	function reapplyAllPinVisuals():Void {
		for (pin in _pins) {
			applyPinVisually(pin.reel, pin.cell, pin.symbolId);
		}
	}

	function pinsOnReel(reelIndex:Int):Array<CellPin> {
		var result:Array<CellPin> = [];
		for (pin in _pins) {
			if (pin.reel == reelIndex) result.push(pin);
		}
		result.sort(function(a, b) return a.cell - b.cell);
		return result;
	}

	/**
	 * MultiWays: relocate pins for a new visible-cell count (eager on setShape).
	 */
	function migratePinsForReel(reelIndex:Int, newCells:Int):Void {
		var reelPins = pinsOnReel(reelIndex);
		var occupied = new Map<Int, Bool>();
		var movers:Array<{
			pin:CellPin,
			fromCell:Int,
			target:Int,
			clamped:Bool,
			nextOriginCell:Int
		}> = [];

		for (pin in reelPins) {
			var fromCell = pin.cell;
			var target:Int;
			var clamped:Bool;
			var nextOriginCell = pin.originCell;
			if (pin.migration == PinMigration.Frozen) {
				if (fromCell < newCells) {
					target = fromCell;
					clamped = false;
				} else {
					target = newCells - 1;
					clamped = true;
					nextOriginCell = target;
				}
			} else {
				target = Std.int(Math.min(pin.originCell, newCells - 1));
				clamped = target != pin.originCell;
			}

			if (target == fromCell && nextOriginCell == pin.originCell) {
				occupied.set(fromCell, true);
				continue;
			}
			movers.push({
				pin: pin,
				fromCell: fromCell,
				target: target,
				clamped: clamped,
				nextOriginCell: nextOriginCell
			});
		}

		for (m in movers) {
			var fromKey = CellPin.pinKey(m.pin.reel, m.fromCell);
			if (occupied.exists(m.target)) {
				_pins.remove(fromKey);
				destroyPinOverlay(fromKey);
				events.emit(ReelEvents.PIN_EXPIRED, [m.pin, PinExpireReason.Collision]);
				continue;
			}
			occupied.set(m.target, true);

			var toKey = CellPin.pinKey(m.pin.reel, m.target);
			_pins.remove(fromKey);
			m.pin.cell = m.target;
			m.pin.originCell = m.nextOriginCell;
			_pins.set(toKey, m.pin);

			var overlayEntry = _pinOverlays.get(fromKey);
			if (overlayEntry != null) {
				_pinOverlays.remove(fromKey);
				// Remap key only — keep displayMain / size so the sticky stays put
				// until AdjustPhase tweens it (pixi parity).
				_pinOverlays.set(toKey, {
					pin: m.pin,
					overlay: overlayEntry.overlay,
					displayMain: overlayEntry.displayMain,
					displayCellMain: overlayEntry.displayCellMain,
					cellCross: overlayEntry.cellCross
				});
			}

			events.emit(ReelEvents.PIN_MIGRATED, [m.pin, {
				fromCell: m.fromCell,
				toCell: m.target,
				clamped: m.clamped,
				reelIndex: reelIndex
			}]);
		}
	}

	function onPinSpinStart():Void {
		_resultSetForCurrentSpin = false;

		if (_pins.keys().hasNext()) {
			var expired:Array<CellPin> = [];
			for (pin in _pins) {
				if (CellPin.isEval(pin.turns)) expired.push(pin);
			}
			for (pin in expired) {
				var key = CellPin.pinKey(pin.reel, pin.cell);
				_pins.remove(key);
				events.emit(ReelEvents.PIN_EXPIRED, [pin, PinExpireReason.Eval]);
			}
		}

		for (pin in _pins) {
			ensurePinOverlay(pin);
		}
	}

	function onPinSpinLanded():Void {
		// Collect pin reels before overlay teardown — strip DOs may still be
		// parented under unmasked after MultiWays reshape / overlay addChild.
		var pinReels:Array<Int> = [];
		var seen = new Map<Int, Bool>();
		for (pin in _pins) {
			if (!seen.exists(pin.reel)) {
				seen.set(pin.reel, true);
				pinReels.push(pin.reel);
			}
		}

		destroyAllPinOverlays();

		// Reseat first (reclaim any strip DO stolen onto unmasked), then drop
		// leftover overlay sprites. clear-without-reseat caused MW sticky holes;
		// reseat-without-clear left a second WILD floating on top of Q/J.
		for (reelIndex in pinReels) {
			_reels[reelIndex].reseatStripDisplay();
		}
		if (_multiways != null) {
			for (i in 0..._reelCount) {
				if (!seen.exists(i)) _reels[i].reseatStripDisplay();
			}
		}
		clearUnmaskedChildren();

		for (pin in _pins) {
			applyPinVisually(pin.reel, pin.cell, pin.symbolId);
		}

		if (!_pins.keys().hasNext()) return;

		var expired:Array<CellPin> = [];
		for (pin in _pins) {
			if (CellPin.isNumeric(pin.turns)) {
				var next = Std.int(pin.turns) - 1;
				pin.turns = next;
				if (next <= 0) expired.push(pin);
			}
		}
		for (pin in expired) {
			_pins.remove(CellPin.pinKey(pin.reel, pin.cell));
			events.emit(ReelEvents.PIN_EXPIRED, [pin, PinExpireReason.Turns]);
		}
	}

	/**
	 * Sticky pin overlays stay at restHostMain + displayMain (pixi parity).
	 * Do NOT bake StopPhase/StartPhase host bounce — unmasked has no clip, so
	 * a bottom-cell pin would leak past the drum edge during overshoot.
	 */
	function syncPinOverlayViews():Void {
		for (entry in _pinOverlays) {
			var reel = _reels[entry.pin.reel];
			var w = _orientation == Vertical ? entry.cellCross : entry.displayCellMain;
			var h = _orientation == Vertical ? entry.displayCellMain : entry.cellCross;
			entry.overlay.resize(w, h);

			var hostCross = reel.axis.crossProp == "x" ? reel.host.x : reel.host.y;
			var hostMain = reel.restHostMain;
			var screen = reel.axis.toScreen(hostCross, hostMain + entry.displayMain);
			var d = entry.overlay.displayObject;
			if (d != null) {
				d.x = screen.x;
				d.y = screen.y;
			} else {
				entry.overlay.x = screen.x;
				entry.overlay.y = screen.y;
			}
			var curve = reel.curve;
			if (curve != null && !curve.isFlat) {
				entry.overlay.applyCellQuad(curve.quadFor(entry.displayMain, entry.overlay.cellInset));
			} else {
				entry.overlay.applyCellQuad(null);
			}
		}
	}

	function pinOverlayScreenPoint(reel:Reel, cell:Int):{x:Float, y:Float} {
		var hostCross = reel.axis.crossProp == "x" ? reel.host.x : reel.host.y;
		return reel.axis.toScreen(hostCross, reel.restHostMain + cell * reel.slotPitch);
	}

	function ensurePinOverlay(pin:CellPin):Void {
		var key = CellPin.pinKey(pin.reel, pin.cell);
		if (_pinOverlays.exists(key)) return;

		var reel = _reels[pin.reel];
		var overlay = _factory.acquire(pin.symbolId);
		var cellMain = _orientation == Vertical ? reel.symbolHeight : reel.symbolWidth;
		var cellCross = _orientation == Vertical ? reel.symbolWidth : reel.symbolHeight;
		overlay.resize(reel.symbolWidth, reel.symbolHeight);
		var displayMain = pin.cell * reel.slotPitch;
		_pinOverlays.set(key, {
			pin: pin,
			overlay: overlay,
			displayMain: displayMain,
			displayCellMain: cellMain,
			cellCross: cellCross
		});
		var d = overlay.displayObject;
		if (d != null) {
			_viewport.unmasked.addChild(d);
		}
		syncPinOverlayViews();
		events.emit(ReelEvents.PIN_OVERLAY_CREATED, [pin, overlay]);
	}

	function destroyPinOverlay(key:String):Void {
		var entry = _pinOverlays.get(key);
		if (entry == null) return;
		_pinOverlays.remove(key);
		entry.overlay.applyCellQuad(null);
		var d = entry.overlay.displayObject;
		if (d != null && d.parent != null) {
			d.parent.removeChild(d);
		}
		_factory.release(entry.overlay);
		events.emit(ReelEvents.PIN_OVERLAY_DESTROYED, [entry.pin, entry.overlay]);
	}

	function destroyAllPinOverlays():Void {
		killPinOverlayTweens();
		var keys = [for (k in _pinOverlays.keys()) k];
		for (key in keys) destroyPinOverlay(key);
		// Unmasked sweep happens in onPinSpinLanded AFTER reseatStripDisplay.
	}

	function killPinOverlayTweens():Void {
		for (h in _pinOverlayTweens) {
			if (h.alive) h.completeNow();
			_tweens.kill(h);
		}
		_pinOverlayTweens = [];
	}

	function abortPinFlight():Void {
		for (h in _pinFlightTweens) {
			_tweens.kill(h);
		}
		_pinFlightTweens = [];
		if (_pinFlight != null) {
			var d = _pinFlight.displayObject;
			if (d != null && d.parent != null) d.parent.removeChild(d);
			_factory.release(_pinFlight);
			_pinFlight = null;
		}
		_pinFlightActive = false;
	}

	function clearUnmaskedChildren():Void {
		var layer = _viewport.unmasked;
		while (layer.numChildren > 0) {
			layer.removeChildAt(0);
		}
	}
}
