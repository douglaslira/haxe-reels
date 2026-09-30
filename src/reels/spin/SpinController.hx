package reels.spin;

import reels.cascade.Cell;
import reels.cascade.RefillOptions;
import reels.cascade.RefillResult;
import reels.cascade.ResolvedTumbleConfig;
import reels.config.SpeedProfile;
import reels.config.SlamOptions;
import reels.core.Reel;
import reels.core.StopSequencer;
import reels.events.EventEmitter;
import reels.events.ReelEvents;
import reels.events.SpinResult;
import reels.frame.ColumnTarget;
import reels.spin.phases.AdjustPhase;
import reels.spin.phases.AnticipationPhase;
import reels.spin.phases.CascadeDropInPhase;
import reels.spin.phases.CascadeFallPhase;
import reels.spin.phases.CascadePlacePhase;
import reels.spin.phases.ReelPhase;
import reels.spin.phases.SpinPhase;
import reels.spin.phases.StartPhase;
import reels.spin.phases.StopPhase;
import reels.speed.SpeedManager;
import reels.spin.MultiWaysHooks;

private enum ReelStage {
	Idle;
	Starting;
	Spinning;
	Anticipating;
	Stopping;
	Landed;
}

private typedef ReelRuntime = {
	reel:Reel,
	stage:ReelStage,
	phase:Null<ReelPhase>,
	spinPhase:Null<SpinPhase>,
	held:Bool,
	anticipate:Bool
};

/**
 * Orchestrates per-reel phase chains for spin (standard or cascade) and refill.
 */
class SpinController {
	var _reels:Array<Reel>;
	var _speed:SpeedManager;
	var _events:EventEmitter;
	var _runtimes:Array<ReelRuntime> = [];
	var _active:Bool = false;
	var _wasSkipped:Bool = false;
	var _clockElapsed:Float = 0;
	var _stopDelays:Array<Float> = [];
	var _anticipation:Array<Int> = [];
	var _sequencer:Null<StopSequencer>;
	var _resultGrid:Null<Array<ColumnTarget>>;
	var _stoppingStarted:Bool = false;
	var _onComplete:Null<SpinResult->Void>;
	var _landedCount:Int = 0;
	var _expectedLandings:Int = 0;
	var _skipPreviousSpeedName:Null<String> = null;
	var _skipBoostApplied:Bool = false;
	var _manualSpeedSinceBoost:Bool = false;

	var _tumble:Null<ResolvedTumbleConfig>;
	var _cascadeMode:Bool = false;
	var _refilling:Bool = false;
	var _refillOnComplete:Null<RefillResult->Void>;
	var _refillWinners:Array<Cell> = [];
	var _refillGrid:Null<Array<ColumnTarget>>;
	/** After skip in cascade: future refill() land instantly (pixi `_autoSlamRefills`). */
	var _autoSlamRefills:Bool = false;
	/** Two-stage refill bookkeeping. */
	var _twoStage:Bool = false;
	var _stage1Done:Int = 0;
	var _holdRemaining:Float = -1;
	var _onHoldDone:Null<() -> Void> = null;
	var _refillGravityHold:Null<() -> Void> = null;
	var _refillOnGravityComplete:Null<() -> Void> = null;
	var _refillGravityHoldMs:Float = 250;
	var _multiways:MultiWaysHooks;

	public function new(
		reels:Array<Reel>,
		speed:SpeedManager,
		events:EventEmitter,
		?tumble:ResolvedTumbleConfig,
		?multiways:MultiWaysHooks
	) {
		_reels = reels;
		_speed = speed;
		_events = events;
		_tumble = tumble;
		_cascadeMode = tumble != null;
		_multiways = multiways != null ? multiways : {
			isMultiWays: false,
			peekTargetShape: function() return null,
			clearTargetShape: function() {},
			applyReshape: function(_, __) {},
			snapPinOverlaysForReel: function(_) {},
			adjustDurationMs: 0
		};
	}

	public var isSpinning(get, never):Bool;

	function get_isSpinning():Bool {
		return _active;
	}

	public var isCascade(get, never):Bool;

	function get_isCascade():Bool {
		return _cascadeMode;
	}

	public function setStopDelays(delays:Array<Float>):Void {
		_stopDelays = delays.copy();
	}

	public function setAnticipation(indices:Array<Int>):Void {
		_anticipation = indices.copy();
	}

	public function spin(?holdReels:Array<Int>, onComplete:SpinResult->Void):Void {
		if (_active) throw "spin() called while already spinning";

		if (_skipPreviousSpeedName != null) {
			var prev = _skipPreviousSpeedName;
			_skipPreviousSpeedName = null;
			if (!_manualSpeedSinceBoost && _speed.current.name != prev) {
				_speed.setSpeed(prev);
			}
		}
		_manualSpeedSinceBoost = false;
		_skipBoostApplied = false;
		_autoSlamRefills = false;
		_refilling = false;
		_refillOnComplete = null;

		_active = true;
		_wasSkipped = false;
		_clockElapsed = 0;
		_resultGrid = null;
		_stoppingStarted = false;
		_sequencer = null;
		_onComplete = onComplete;
		_landedCount = 0;

		var held = normalizeHoldReels(holdReels);

		_runtimes = [];
		_expectedLandings = 0;
		for (reel in _reels) {
			var isHeld = held.exists(reel.index);
			_runtimes.push({
				reel: reel,
				stage: isHeld ? Landed : Idle,
				phase: null,
				spinPhase: null,
				held: isHeld,
				anticipate: false
			});
			// Count only non-held landings — held start as Landed and never
			// call markLanded. Pre-incrementing _landedCount by held count
			// made finish() fire after the first non-held reel landed.
			if (!isHeld) _expectedLandings++;
		}

		for (i in _anticipation) {
			if (i >= 0 && i < _runtimes.length && !_runtimes[i].held) {
				_runtimes[i].anticipate = true;
			}
		}

		_events.emit(ReelEvents.SPIN_START);
		var profile = _speed.current;
		for (rt in _runtimes) {
			if (rt.held) continue;
			if (_cascadeMode) enterFall(rt, profile);
			else enterStart(rt, profile);
		}
		_events.emit(ReelEvents.SPIN_ALL_STARTED);

		if (_expectedLandings == 0) {
			finish();
		}
	}

	/**
	 * Drop out-of-range / non-integer indices; dedupe via Map keys.
	 * Matches pixi `_normalizeHoldReels`.
	 */
	function normalizeHoldReels(input:Null<Array<Int>>):Map<Int, Bool> {
		var out = new Map<Int, Bool>();
		if (input == null) return out;
		var n = _reels.length;
		for (i in input) {
			if (i != i) continue; // NaN
			if (i != Std.int(i)) continue;
			if (i < 0 || i >= n) continue;
			out.set(i, true);
		}
		return out;
	}

	public function setResult(grid:Array<ColumnTarget>):Void {
		if (!_active || _refilling) return;
		_resultGrid = grid;
		for (i in 0..._runtimes.length) {
			var rt = _runtimes[i];
			if (rt.held) continue;
			if (i < grid.length) rt.reel.setPendingResult(grid[i]);
		}
		beginStopSequence();
	}

	/**
	 * Moment B: place + dropIn. Modes: `combined` (default) or `gravity-then-drop`.
	 */
	public function refill(opts:RefillOptions, onComplete:RefillResult->Void):Void {
		if (!_cascadeMode || _tumble == null) {
			throw "refill() requires ReelSetBuilder.tumble()";
		}
		if (_active) throw "refill() called while spin/refill is active";
		var mode = opts.mode != null ? opts.mode : "combined";
		if (mode != "combined" && mode != "gravity-then-drop") {
			throw 'refill mode "$mode" not supported (use combined or gravity-then-drop)';
		}

		_refilling = true;
		_active = true;
		_wasSkipped = false;
		_clockElapsed = 0;
		_refillOnComplete = onComplete;
		_refillWinners = opts.winners != null ? opts.winners.copy() : [];
		_refillGrid = opts.grid;
		_resultGrid = opts.grid;
		_landedCount = 0;
		_expectedLandings = _reels.length;
		_onComplete = null;
		_twoStage = mode == "gravity-then-drop";
		_stage1Done = 0;
		_holdRemaining = -1;
		_onHoldDone = null;
		_refillGravityHold = opts.gravityHold;
		_refillOnGravityComplete = opts.onGravityComplete;
		_refillGravityHoldMs = opts.gravityHoldMs != null ? opts.gravityHoldMs : 250;

		var profile = _speed.current;
		_runtimes = [];
		for (reel in _reels) {
			_runtimes.push({
				reel: reel,
				stage: Stopping,
				phase: null,
				spinPhase: null,
				held: false,
				anticipate: false
			});
		}

		// Skip pressed earlier in the round: bypass place+dropIn and land now.
		if (_autoSlamRefills) {
			_wasSkipped = true;
			_twoStage = false;
			for (i in 0..._runtimes.length) {
				var rt = _runtimes[i];
				if (i < _resultGrid.length) {
					rt.reel.forceResult(_resultGrid[i]);
					rt.reel.revealAllVisible();
				} else {
					rt.reel.snapToGrid();
					rt.reel.revealAllVisible();
				}
				markLanded(rt);
			}
			return;
		}

		// Pixi parity: refill emits spin:start so pin overlays cover stickies
		// while survivors slide / new symbols drop in.
		_events.emit(ReelEvents.SPIN_START);

		if (_twoStage) {
			for (rt in _runtimes) {
				enterCascadePlaceTwoStage(rt, profile);
			}
		} else {
			for (rt in _runtimes) {
				enterCascadePlace(rt, profile, false);
			}
		}
	}

	public function skipSpin():Void {
		if (!_active) return;
		_wasSkipped = true;
		slamInternal(null);
		if (_cascadeMode) {
			// Cascade phase durations ignore spinSpeed; auto-slam refills instead.
			_autoSlamRefills = true;
		} else if (!_refilling) {
			applySkipBoostOnce();
		}
	}

	public function slamStop(?opts:SlamOptions):Void {
		if (!_active) return;
		_wasSkipped = true;
		slamInternal(opts);
	}

	public function notifyManualSpeedChange():Void {
		if (_skipPreviousSpeedName != null) _manualSpeedSinceBoost = true;
	}

	function applySkipBoostOnce():Void {
		if (_skipBoostApplied) return;
		_skipBoostApplied = true;
		var fastest = _speed.getFastest();
		if (fastest.name == _speed.current.name) return;
		var previous = _speed.current;
		_skipPreviousSpeedName = previous.name;
		_speed.setSpeed(fastest.name);
		_events.emit(ReelEvents.SKIP_BOOSTED, [{previous: previous, current: _speed.current}]);
	}

	function slamInternal(opts:Null<SlamOptions>):Void {
		var targets = resolveSlamTargets(opts);
		_events.emit(ReelEvents.SKIP_REQUESTED, [{reels: targets, partial: targets.length < _expectedLandings}]);

		// Cancel in-flight two-stage hold.
		_holdRemaining = -1;
		_onHoldDone = null;
		_twoStage = false;

		if (_resultGrid == null) {
			_resultGrid = [for (rt in _runtimes) {visible: rt.reel.getVisibleIds()}];
		}

		for (i in targets) {
			var rt = _runtimes[i];
			if (rt.held || rt.stage == Landed) continue;
			killPhase(rt);
			applyPendingReshape(rt.reel.index);
			if (i < _resultGrid.length) {
				rt.reel.forceResult(_resultGrid[i]);
				rt.reel.revealAllVisible();
			} else {
				rt.reel.snapToGrid();
				rt.reel.revealAllVisible();
			}
			rt.reel.setCurveVisuals(true);
			markLanded(rt);
		}

		_events.emit(ReelEvents.SKIP_COMPLETED, [{reels: targets, partial: _landedCount < _reels.length}]);
		if (_landedCount >= _expectedLandings) finish();
	}

	function resolveSlamTargets(opts:Null<SlamOptions>):Array<Int> {
		var out:Array<Int> = [];
		if (opts != null && opts.reels != null) {
			for (i in opts.reels) {
				if (i >= 0 && i < _runtimes.length) out.push(i);
			}
			return out;
		}
		var except = new Map<Int, Bool>();
		if (opts != null && opts.except != null) {
			for (i in opts.except) except.set(i, true);
		}
		for (i in 0..._runtimes.length) {
			if (except.exists(i)) continue;
			if (_runtimes[i].held || _runtimes[i].stage == Landed) continue;
			out.push(i);
		}
		return out;
	}

	public function update(deltaMs:Float):Void {
		if (!_active) return;
		_clockElapsed += deltaMs;

		if (_holdRemaining >= 0) {
			_holdRemaining -= deltaMs;
			if (_holdRemaining <= 0) {
				_holdRemaining = -1;
				var holdCb = _onHoldDone;
				_onHoldDone = null;
				if (holdCb != null) holdCb();
			}
		}

		if (_sequencer != null && !_sequencer.isDone) {
			_sequencer.update(deltaMs);
		}

		for (rt in _runtimes) {
			if (rt.phase != null && rt.phase.isActive) {
				rt.phase.update(deltaMs);
			}
		}
	}

	function beginStopSequence():Void {
		if (_stoppingStarted || !_active) return;
		_stoppingStarted = true;

		var profile = _speed.current;
		var delays:Array<Float> = [];
		for (i in 0..._runtimes.length) {
			if (_runtimes[i].held) {
				delays.push(0);
				continue;
			}
			var d = i < _stopDelays.length ? _stopDelays[i] : profile.stopDelay * i;
			delays.push(d);
		}

		_sequencer = new StopSequencer(delays, function(i) {
			var rt = _runtimes[i];
			if (rt.held || rt.stage == Landed || rt.stage == Stopping || rt.stage == Anticipating) return;
			_events.emit(ReelEvents.SPIN_STOPPING, [i]);
			if (rt.spinPhase != null) rt.spinPhase.requestStop();
			else proceedToStopChain(rt);
		});
	}

	function enterFall(rt:ReelRuntime, profile:SpeedProfile):Void {
		rt.stage = Starting;
		var tumble = _tumble;
		var phase = new CascadeFallPhase(rt.reel, profile, tumble.fall, tumble.gravity);
		rt.phase = phase;
		var delay = spinDelayFor(rt.reel.index, profile);
		phase.run({delay: delay, events: _events}, function() {
			enterSpin(rt, profile, true);
		});
	}

	function enterStart(rt:ReelRuntime, profile:SpeedProfile):Void {
		rt.stage = Starting;
		var phase = new StartPhase(rt.reel, profile);
		rt.phase = phase;
		phase.run(null, function() {
			enterSpin(rt, profile, false);
		});
	}

	function enterSpin(rt:ReelRuntime, profile:SpeedProfile, cascadeWait:Bool):Void {
		rt.stage = Spinning;
		var phase = new SpinPhase(rt.reel, profile);
		rt.phase = phase;
		rt.spinPhase = phase;
		phase.run({cascadeWait: cascadeWait}, function() {
			rt.spinPhase = null;
			if (_cascadeMode) {
				enterCascadePlace(rt, profile, true);
			} else {
				enterAdjustThenStop(rt, profile);
			}
		});
		if (_resultGrid != null) phase.requestStop();
	}

	/**
	 * MultiWays: reshape (+ optional AdjustPhase hold) then anticipation/stop.
	 */
	function enterAdjustThenStop(rt:ReelRuntime, profile:SpeedProfile):Void {
		applyPendingReshape(rt.reel.index);
		var duration = _multiways.isMultiWays ? _multiways.adjustDurationMs : 0;
		if (duration > 0) {
			rt.stage = Stopping;
			var phase = new AdjustPhase(rt.reel, profile, duration);
			rt.phase = phase;
			var reelIndex = rt.reel.index;
			phase.run({
				snapPinOverlays: function() {
					_multiways.snapPinOverlaysForReel(reelIndex);
				}
			}, function() {
				continueAfterAdjust(rt, profile);
			});
		} else {
			if (_multiways.isMultiWays) {
				_multiways.snapPinOverlaysForReel(rt.reel.index);
			}
			continueAfterAdjust(rt, profile);
		}
	}

	function continueAfterAdjust(rt:ReelRuntime, profile:SpeedProfile):Void {
		if (!_cascadeMode && rt.anticipate && profile.anticipationDelay > 0) {
			enterAnticipation(rt, profile);
		} else {
			enterStop(rt, profile);
		}
	}

	function applyPendingReshape(reelIndex:Int):Void {
		if (!_multiways.isMultiWays) return;
		var pending = _multiways.peekTargetShape();
		var target = pending != null && reelIndex < pending.length
			? pending[reelIndex]
			: _reels[reelIndex].visibleCells;
		if (target != _reels[reelIndex].visibleCells) {
			_multiways.applyReshape(reelIndex, target);
		}
	}

	function enterAnticipation(rt:ReelRuntime, profile:SpeedProfile):Void {
		rt.stage = Anticipating;
		var phase = new AnticipationPhase(rt.reel, profile);
		rt.phase = phase;
		phase.run({hold: profile.anticipationDelay, mul: 0.3}, function() {
			enterStop(rt, profile);
		});
	}

	function enterStop(rt:ReelRuntime, profile:SpeedProfile):Void {
		rt.stage = Stopping;
		var phase = new StopPhase(rt.reel, profile);
		rt.phase = phase;
		phase.run(null, function() {
			markLanded(rt);
		});
	}

	function enterCascadePlace(rt:ReelRuntime, profile:SpeedProfile, initial:Bool):Void {
		rt.stage = Stopping;
		var tumble = _tumble;
		var phase = new CascadePlacePhase(rt.reel, profile, tumble.gravity);
		rt.phase = phase;
		var idx = rt.reel.index;
		var target = _resultGrid != null && idx < _resultGrid.length ? _resultGrid[idx] : {visible: rt.reel.getVisibleIds()};
		var winners = initial ? [] : winnersForReel(idx);
		// Place stagger uses stopDelay (pixi parity) for Moment A and combined refill.
		var delay = stopDelayFor(idx, profile);
		phase.run({
			target: target,
			winnerCells: winners,
			initial: initial,
			events: _events,
			delay: delay
		}, function() {
			enterCascadeDropIn(rt, profile, initial, winners, "all", 0, function() {
				markLanded(rt);
			});
		});
	}

	/** Stage 1 of gravity-then-drop: place (delay 0) + gravity survivors. */
	function enterCascadePlaceTwoStage(rt:ReelRuntime, profile:SpeedProfile):Void {
		rt.stage = Stopping;
		var tumble = _tumble;
		var phase = new CascadePlacePhase(rt.reel, profile, tumble.gravity);
		rt.phase = phase;
		var idx = rt.reel.index;
		var target = _resultGrid != null && idx < _resultGrid.length ? _resultGrid[idx] : {visible: rt.reel.getVisibleIds()};
		var winners = winnersForReel(idx);
		phase.run({
			target: target,
			winnerCells: winners,
			initial: false,
			events: _events,
			delay: 0
		}, function() {
			enterCascadeDropIn(rt, profile, false, winners, "gravity", 0, function() {
				onTwoStageGravityDone();
			});
		});
	}

	function onTwoStageGravityDone():Void {
		if (!_active || !_twoStage) return;
		_stage1Done++;
		if (_stage1Done < _expectedLandings) return;

		// Gravity-end: fire hold side-effect, then wait gravityHoldMs.
		if (_refillGravityHold != null) {
			_refillGravityHold();
		}

		function afterHold():Void {
			if (!_active || !_twoStage) return;
			if (_refillOnGravityComplete != null) {
				_refillOnGravityComplete();
			}
			startTwoStageDropIn();
		}

		if (_refillGravityHoldMs <= 0) {
			afterHold();
		} else {
			_holdRemaining = _refillGravityHoldMs;
			_onHoldDone = afterHold;
		}
	}

	function startTwoStageDropIn():Void {
		var profile = _speed.current;
		for (rt in _runtimes) {
			if (rt.stage == Landed) continue;
			var winners = winnersForReel(rt.reel.index);
			var delay = stopDelayFor(rt.reel.index, profile);
			enterCascadeDropIn(rt, profile, false, winners, "new", delay, function() {
				markLanded(rt);
			});
		}
	}

	function enterCascadeDropIn(
		rt:ReelRuntime,
		profile:SpeedProfile,
		initial:Bool,
		winners:Array<Int>,
		role:String,
		delay:Float,
		onDone:() -> Void
	):Void {
		var tumble = _tumble;
		var phase = new CascadeDropInPhase(rt.reel, profile, tumble.dropIn, tumble.gravity);
		rt.phase = phase;
		phase.run({
			winnerCells: winners,
			initial: initial,
			events: _events,
			role: role,
			delay: delay
		}, onDone);
	}

	function winnersForReel(reelIndex:Int):Array<Int> {
		var out:Array<Int> = [];
		for (w in _refillWinners) {
			if (w.reel == reelIndex) out.push(w.cell);
		}
		return out;
	}

	function stopDelayFor(index:Int, profile:SpeedProfile):Float {
		if (index < _stopDelays.length) return _stopDelays[index];
		return profile.stopDelay * index;
	}

	function spinDelayFor(index:Int, profile:SpeedProfile):Float {
		return profile.spinDelay * index;
	}

	function proceedToStopChain(rt:ReelRuntime):Void {
		if (rt.stage == Spinning && rt.spinPhase != null) {
			rt.spinPhase.requestStop();
		}
	}

	function markLanded(rt:ReelRuntime):Void {
		if (rt.stage == Landed) return;
		rt.stage = Landed;
		rt.phase = null;
		rt.spinPhase = null;
		_landedCount++;
		var symbols = rt.reel.getVisibleIds();
		_events.emit(ReelEvents.SPIN_REEL_LANDED, [rt.reel.index, symbols]);
		if (_landedCount >= _expectedLandings) finish();
	}

	function killPhase(rt:ReelRuntime):Void {
		if (rt.phase != null && rt.phase.isActive) {
			rt.phase.abort();
		}
		rt.phase = null;
		rt.spinPhase = null;
	}

	function finish():Void {
		if (!_active) return;
		_active = false;
		_multiways.clearTargetShape();
		var symbols:Array<Array<String>> = [];
		for (rt in _runtimes) {
			symbols.push(rt.reel.getVisibleIds());
		}

		if (_refilling) {
			var winnersCount = _refillWinners.length;
			var result:RefillResult = {
				winnersRefilled: winnersCount,
				finalGrid: symbols,
				wasSkipped: _wasSkipped,
				duration: _clockElapsed
			};
			_refilling = false;
			_twoStage = false;
			_holdRemaining = -1;
			_onHoldDone = null;
			var cb = _refillOnComplete;
			_refillOnComplete = null;
			_events.emit(ReelEvents.SPIN_ALL_LANDED, [result]);
			if (cb != null) cb(result);
			return;
		}

		var spinResult:SpinResult = {
			symbols: symbols,
			wasSkipped: _wasSkipped,
			duration: _clockElapsed
		};
		_events.emit(ReelEvents.SPIN_ALL_LANDED, [spinResult]);
		_events.emit(ReelEvents.SPIN_COMPLETE, [spinResult]);
		var scb = _onComplete;
		_onComplete = null;
		if (scb != null) scb(spinResult);
	}
}
