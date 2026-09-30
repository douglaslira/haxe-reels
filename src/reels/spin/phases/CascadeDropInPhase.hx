package reels.spin.phases;

import reels.cascade.DropOffset;
import reels.cascade.ResolvedDropInConfig;
import reels.cascade.TumbleAlgorithm;
import reels.cascade.TumbleConfigUtil;
import reels.config.SpeedProfile;
import reels.core.Reel;
import reels.events.EventEmitter;
import reels.events.ReelEvents;
import reels.tween.Easing;

/**
 * Drop-in: animate movers from origin to grid (ADR 010).
 * `role`: `all` (combined), `gravity` (survivors only), `new` (arrivals only).
 */
class CascadeDropInPhase extends ReelPhase {
	var _drop:ResolvedDropInConfig;
	var _gravitySetting:String;
	var _events:Null<EventEmitter>;
	var _elapsed:Float = 0;
	var _delay:Float = 0;
	var _started:Bool = false;
	var _jobs:Array<{
		cell:Int,
		from:Float,
		to:Float,
		startAt:Float,
		done:Bool
	}> = [];
	var _duration:Float = 1;
	var _ease:Float->Float;
	var _winnerCells:Array<Int> = [];
	var _initial:Bool = false;
	var _finished:Bool = false;
	var _role:String = "all";
	var _endEvent:String = ReelEvents.CASCADE_DROPIN_END;
	var _startEmitted:Bool = false;

	public function new(
		reel:Reel,
		speed:SpeedProfile,
		drop:ResolvedDropInConfig,
		gravitySetting:String
	) {
		super(reel, speed);
		_drop = drop;
		_gravitySetting = gravitySetting;
	}

	override function get_name():String {
		return _role == "gravity" ? "cascade:gravity" : "cascade:dropIn";
	}

	override function onEnter(config:Dynamic):Void {
		_elapsed = 0;
		_finished = false;
		_started = false;
		_jobs = [];
		_startEmitted = false;
		_events = config != null ? config.events : null;
		_winnerCells = config != null && config.winnerCells != null ? config.winnerCells : [];
		_initial = config != null && config.initial == true;
		_delay = config != null && config.delay != null ? config.delay : 0;
		_role = config != null && config.role != null ? Std.string(config.role) : "all";
		if (_role != "gravity" && _role != "new") _role = "all";
		_endEvent = _role == "gravity" ? ReelEvents.CASCADE_GRAVITY_END : ReelEvents.CASCADE_DROPIN_END;
		_duration = Math.max(1, _drop.duration);
		_ease = Easing.resolve(_drop.ease);

		// Keep curve on while travelling (see CascadeFallPhase). Restore on
		// settle in case a prior path left projection off.

		if (_delay <= 0) beginDrop();
	}

	override function update(deltaMs:Float):Void {
		if (!_active || _finished) return;
		_elapsed += deltaMs;

		if (!_started) {
			if (_elapsed >= _delay) beginDrop();
			else return;
		}

		var allDone = true;
		var localT = _elapsed - _delay;
		for (job in _jobs) {
			if (job.done) continue;
			var t = (localT - job.startAt) / _duration;
			if (t >= 1) {
				_reel.setVisibleMain(job.cell, job.to);
				job.done = true;
			} else if (t > 0) {
				allDone = false;
				var e = _ease(t);
				_reel.setVisibleMain(job.cell, job.from + (job.to - job.from) * e);
			} else {
				allDone = false;
			}
		}
		if (allDone) finishNow();
	}

	function beginDrop():Void {
		_started = true;
		var gravity = TumbleConfigUtil.resolveGravity(_gravitySetting, _reel.axis.direction);
		var order = TumbleConfigUtil.resolveCellOrder(_drop.cellOrder, gravity);
		var offsets = TumbleAlgorithm.computeDropOffsets(
			_reel.visibleCells,
			_winnerCells,
			{initial: _initial, gravity: gravity}
		);

		var startEvent = _role == "gravity"
			? ReelEvents.CASCADE_GRAVITY_START
			: ReelEvents.CASCADE_DROPIN_START;
		if (_events != null) {
			_events.emit(startEvent, [_reel.index]);
			_startEmitted = true;
		}

		var pitch = _reel.slotPitch;
		var movers:Array<DropOffset> = [];
		for (o in offsets) {
			if (o.offsetCells == 0) {
				_reel.setVisibleAlpha(o.cell, 1);
				continue;
			}

			var skipForRole = (_role == "gravity" && o.isNew) || (_role == "new" && !o.isNew);
			if (skipForRole) {
				if (_role == "gravity" && o.isNew) {
					// Park new arrivals invisible at final grid for stage 2.
					_reel.setVisibleMain(o.cell, o.cell * pitch);
					_reel.setVisibleAlpha(o.cell, 0);
				} else if (_role == "new" && !o.isNew) {
					_reel.setVisibleMain(o.cell, o.cell * pitch);
					_reel.setVisibleAlpha(o.cell, 1);
				}
				continue;
			}
			movers.push(o);
		}

		if (order == "startFirst") {
			movers.sort(function(a, b) return a.cell - b.cell);
		} else {
			movers.sort(function(a, b) return b.cell - a.cell);
		}

		var sign = TumbleConfigUtil.gravitySign(gravity);
		var n = _reel.visibleCells;
		var distMode = resolveDistanceMode(_drop.distance);

		for (i in 0...movers.length) {
			var o = movers[i];
			var finalMain = o.cell * pitch;
			var startMain = startMainFor(o, distMode, finalMain, pitch, sign, n);

			_reel.setVisibleMain(o.cell, startMain);
			_reel.setVisibleAlpha(o.cell, 1);
			_jobs.push({
				cell: o.cell,
				from: startMain,
				to: finalMain,
				startAt: _drop.cellStagger * i,
				done: false
			});
		}

		if (_jobs.length == 0 || _drop.duration <= 0) {
			finishNow();
		}
	}

	function finishNow():Void {
		if (_finished) return;
		_finished = true;
		_reel.snapToGrid();
		// Gravity stage keeps new symbols alpha 0 for stage 2 drop-in.
		if (_role != "gravity") {
			_reel.revealAllVisible();
			_reel.setCurveVisuals(true);
		}
		emitEnd();
		complete();
	}

	override function onSkip():Void {
		_reel.snapToGrid();
		// Skip reveals everything (pixi parity) even mid-gravity.
		_reel.revealAllVisible();
		_reel.setCurveVisuals(true);
		if (_startEmitted) emitEnd();
	}

	function emitEnd():Void {
		if (_events != null) {
			_events.emit(_endEvent, [_reel.index]);
			_events = null;
		}
	}

	/**
	 * Resolve start main for a mover.
	 * - `perHole`: from `originalCell * pitch` (survivor slide / exact hole depth)
	 * - `auto`: full visible height for new/initial; perHole for Moment B survivors
	 * - number: fixed pixel distance against gravity
	 */
	function startMainFor(
		o:DropOffset,
		distMode:DistanceMode,
		finalMain:Float,
		pitch:Float,
		sign:Int,
		visible:Int
	):Float {
		return switch (distMode) {
			case Auto:
				if (!_initial && !o.isNew) {
					o.originalCell * pitch;
				} else {
					finalMain - sign * visible * pitch;
				}
			case PerHole:
				o.originalCell * pitch;
			case Fixed(px):
				finalMain - sign * px;
		};
	}

	function resolveDistanceMode(raw:Dynamic):DistanceMode {
		if (Std.isOfType(raw, Float) || Std.isOfType(raw, Int)) {
			return Fixed(cast raw);
		}
		var s = Std.string(raw);
		if (s == "auto") return Auto;
		if (s == "perHole") return PerHole;
		var n = Std.parseFloat(s);
		if (!Math.isNaN(n) && s != "perHole" && s != "auto") return Fixed(n);
		return PerHole;
	}
}

private enum DistanceMode {
	Auto;
	PerHole;
	Fixed(px:Float);
}
