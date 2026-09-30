package reels.spin.phases;

import reels.config.SpeedProfile;
import reels.core.Reel;
import reels.tween.Easing;

/**
 * Natural stop: keep spinning while StopFrameQueue feeds target symbols
 * through wraps, then snap + optional bounce.
 *
 * Bounce moves the reel HOST (container), not the strip travel — matches
 * pixi-reels. Advancing the strip through a ReelCurve would slide symbols
 * across the drum and look like the board sinks, then pops back on snap.
 */
class StopPhase extends ReelPhase {
	var _elapsed:Float = 0;
	var _bounceMs:Float = 0;
	var _bounceDist:Float = 0;
	/** 0 = spin-out, 1 = bounce out, 2 = bounce back */
	var _stage:Int = 0;
	var _baseHostMain:Float = 0;
	var _appliedBounce:Float = 0;

	public function new(reel:Reel, speed:SpeedProfile) {
		super(reel, speed);
	}

	override function get_name():String {
		return "stop";
	}

	override function get_skippable():Bool {
		return true;
	}

	override function onEnter(_config:Dynamic):Void {
		_elapsed = 0;
		_appliedBounce = 0;
		_bounceMs = Math.max(1, _speed.bounceDuration * 0.5);
		_bounceDist = _speed.bounceDistance;
		_baseHostMain = _reel.getHostMain();

		_reel.armStopFromPending();
		_reel.endBlur();
		_stage = 0;

		if (!_reel.stopQueueHasRemaining) {
			landAndBounce();
		}
	}

	override function update(deltaMs:Float):Void {
		if (!_active) return;
		_elapsed += deltaMs;

		if (_stage == 0) {
			var pxPerMs = _speed.spinSpeed;
			_reel.advance(pxPerMs * deltaMs * 0.06);
			if (!_reel.stopQueueHasRemaining) {
				landAndBounce();
			}
			return;
		}

		var polarity = _reel.axisPolarity();

		if (_stage == 1) {
			var t1 = _elapsed / _bounceMs;
			if (t1 >= 1) {
				_reel.setHostMain(_baseHostMain + polarity * _bounceDist);
				_stage = 2;
				_elapsed = 0;
				_appliedBounce = 0;
				return;
			}
			var target1 = _bounceDist * Easing.quadOut(t1);
			_appliedBounce = target1;
			_reel.setHostMain(_baseHostMain + polarity * target1);
			return;
		}

		// bounce back — host returns to resting main
		var t2 = _elapsed / _bounceMs;
		if (t2 >= 1) {
			_reel.setHostMain(_baseHostMain);
			_reel.snapToGrid();
			_reel.clearPendingResult();
			complete();
			return;
		}
		var target2 = _bounceDist * (1 - Easing.quadOut(t2));
		_appliedBounce = _bounceDist - target2;
		_reel.setHostMain(_baseHostMain + polarity * target2);
	}

	function landAndBounce():Void {
		_reel.isStopping = false;
		_reel.snapToGrid();
		_reel.setHostMain(_baseHostMain);
		_elapsed = 0;
		_appliedBounce = 0;
		if (_bounceDist <= 0) {
			_reel.clearPendingResult();
			complete();
			return;
		}
		_stage = 1;
	}

	override function onSkip():Void {
		_reel.setHostMain(_baseHostMain);
		_reel.forcePendingResult();
	}
}
