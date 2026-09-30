package reels.spin.phases;

import reels.cascade.ResolvedFallConfig;
import reels.cascade.TumbleConfigUtil;
import reels.config.SpeedProfile;
import reels.core.Direction;
import reels.core.Reel;
import reels.events.EventEmitter;
import reels.events.ReelEvents;
import reels.tween.Easing;

/**
 * Fall-out: visible symbols leave toward the gravity-exit edge.
 * Replaces StartPhase when builder used `.tumble()`.
 */
class CascadeFallPhase extends ReelPhase {
	var _fall:ResolvedFallConfig;
	var _gravitySetting:String;
	var _events:Null<EventEmitter>;
	var _elapsed:Float = 0;
	var _delay:Float = 0;
	var _started:Bool = false;
	var _jobs:Array<{cell:Int, from:Float, to:Float, startAt:Float, done:Bool}> = [];
	var _duration:Float = 1;
	var _ease:Float->Float;

	public function new(
		reel:Reel,
		speed:SpeedProfile,
		fall:ResolvedFallConfig,
		gravitySetting:String
	) {
		super(reel, speed);
		_fall = fall;
		_gravitySetting = gravitySetting;
	}

	override function get_name():String {
		return "cascade:fall";
	}

	override function onEnter(config:Dynamic):Void {
		_elapsed = 0;
		_started = false;
		_jobs = [];
		_delay = config != null && config.delay != null ? config.delay : 0;
		_events = config != null ? config.events : null;
		_duration = Math.max(1, _fall.duration);
		_ease = Easing.resolve(_fall.ease);

		// Keep curve projection on (pixi symbol-mode parity). Flattening the
		// whole board here made curve+tumble flash flat→curve on every spin;
		// setVisibleMain re-keystones each cell as it travels.

		if (_delay <= 0 && _fall.duration <= 0) {
			hideAllAndComplete();
			return;
		}
		if (_delay <= 0) beginFall();
	}

	override function update(deltaMs:Float):Void {
		if (!_active) return;
		_elapsed += deltaMs;

		if (!_started) {
			if (_elapsed >= _delay) beginFall();
			else return;
		}

		var allDone = true;
		var localT = _elapsed - _delay;
		for (job in _jobs) {
			if (job.done) continue;
			var t = (localT - job.startAt) / _duration;
			if (t >= 1) {
				_reel.setVisibleMain(job.cell, job.to);
				_reel.setVisibleAlpha(job.cell, 0);
				job.done = true;
			} else if (t > 0) {
				allDone = false;
				var e = _ease(t);
				// Solid fall (pixi parity): hide only when the tween ends.
				_reel.setVisibleMain(job.cell, job.from + (job.to - job.from) * e);
			} else {
				allDone = false;
			}
		}
		if (allDone) {
			emitEnd();
			complete();
		}
	}

	function beginFall():Void {
		_started = true;
		var gravity = TumbleConfigUtil.resolveGravity(_gravitySetting, _reel.axis.direction);
		var order = TumbleConfigUtil.resolveCellOrder(_fall.cellOrder, gravity);
		var sign = TumbleConfigUtil.gravitySign(gravity);
		var pitch = _reel.slotPitch;
		var n = _reel.visibleCells;
		// Clear past the exit-edge buffer so symbols leave the mask (pixi parity).
		var exitBuffer = sign > 0 ? _reel.bufferEnd : _reel.bufferStart;
		var fallDist = pitch * (n + exitBuffer + 1);

		var orderCells:Array<Int> = [];
		if (order == "startFirst") {
			for (c in 0...n) orderCells.push(c);
		} else {
			var c = n - 1;
			while (c >= 0) {
				orderCells.push(c);
				c--;
			}
		}

		if (_events != null) _events.emit(ReelEvents.CASCADE_FALL_START, [_reel.index]);

		for (i in 0...orderCells.length) {
			var cell = orderCells[i];
			var from = _reel.getVisibleMain(cell);
			_jobs.push({
				cell: cell,
				from: from,
				to: from + sign * fallDist,
				startAt: _fall.cellStagger * i,
				done: false
			});
		}

		if (_jobs.length == 0 || _fall.duration <= 0) {
			hideAllAndComplete();
		}
	}

	function hideAllAndComplete():Void {
		for (c in 0..._reel.visibleCells) {
			_reel.setVisibleAlpha(c, 0);
		}
		emitEnd();
		complete();
	}

	function emitEnd():Void {
		if (_events != null) _events.emit(ReelEvents.CASCADE_FALL_END, [_reel.index]);
		_events = null;
	}

	override function onSkip():Void {
		for (c in 0..._reel.visibleCells) {
			_reel.setVisibleAlpha(c, 0);
		}
		emitEnd();
	}
}
