package reels.spin.phases;

import reels.config.SpeedProfile;
import reels.core.Reel;
import reels.tween.Easing;

/**
 * Brief reverse tug before continuous spin.
 *
 * Nudges the reel HOST (not strip travel) so ReelCurve symbols stay on their
 * drum slots — same idea as StopPhase bounce.
 */
class StartPhase extends ReelPhase {
	var _elapsed:Float = 0;
	var _duration:Float = 0;
	var _pull:Float = 0;
	var _baseHostMain:Float = 0;

	public function new(reel:Reel, speed:SpeedProfile) {
		super(reel, speed);
	}

	override function get_name():String {
		return "start";
	}

	override function get_skippable():Bool {
		return true;
	}

	override function onEnter(_config:Dynamic):Void {
		_elapsed = 0;
		_baseHostMain = _reel.getHostMain();
		// Pixi gates the start step-back on bounceDistance > 0 — same here.
		// With ReelCurve the host tug reads as a landing bounce even when
		// StopPhase correctly skips bounce at 0.
		if (_speed.bounceDistance <= 0) {
			_duration = 0;
			_pull = 0;
			complete();
			return;
		}
		_duration = Math.max(1, _speed.accelerationDuration * 0.35);
		_pull = _reel.slotPitch * 0.15;
	}

	override function update(deltaMs:Float):Void {
		if (!_active) return;
		if (_pull <= 0) {
			complete();
			return;
		}
		_elapsed += deltaMs;
		var t = _elapsed / _duration;
		// Tug opposite to travel, then ease back to base.
		var polarity = _reel.axisPolarity();
		if (t >= 1) {
			_reel.setHostMain(_baseHostMain);
			complete();
			return;
		}
		// 0..0.5 pull back, 0.5..1 return
		var local:Float;
		var amt:Float;
		if (t < 0.5) {
			local = t / 0.5;
			amt = _pull * Easing.quadOut(local);
		} else {
			local = (t - 0.5) / 0.5;
			amt = _pull * (1 - Easing.quadIn(local));
		}
		_reel.setHostMain(_baseHostMain - polarity * amt);
	}

	override function onSkip():Void {
		_reel.setHostMain(_baseHostMain);
		_reel.snapToGrid();
	}
}
