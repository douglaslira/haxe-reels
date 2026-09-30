package reels.spin.phases;

import reels.config.SpeedProfile;
import reels.core.Reel;

/** Continuous strip motion until stop is requested. */
class SpinPhase extends ReelPhase {
	var _elapsed:Float = 0;
	var _speedMul:Float = 1;
	var _minTime:Float = 0;
	var _stopRequested:Bool = false;

	public function new(reel:Reel, speed:SpeedProfile) {
		super(reel, speed);
	}

	override function get_name():String {
		return "spin";
	}

	override function get_skippable():Bool {
		return true;
	}

	override function onEnter(config:Dynamic):Void {
		_elapsed = 0;
		_minTime = _speed.minimumSpinTime;
		_stopRequested = false;
		// Cascade Moment A: strip is empty after fall — hold at rest (no blur).
		var cascadeWait = config != null && config.cascadeWait == true;
		_speedMul = cascadeWait ? 0 : 1;
		if (!cascadeWait) _reel.beginBlur();
	}

	public function requestStop():Void {
		_stopRequested = true;
	}

	public function setSpeedMultiplier(m:Float):Void {
		_speedMul = m;
	}

	override function update(deltaMs:Float):Void {
		if (!_active) return;
		_elapsed += deltaMs;
		var pxPerMs = _speed.spinSpeed * _speedMul;
		_reel.advance(pxPerMs * deltaMs * 0.06);
		if (_stopRequested && _elapsed >= _minTime) {
			complete();
		}
	}

	override function onSkip():Void {
		_reel.endBlur();
	}

	override function complete():Void {
		_reel.endBlur();
		super.complete();
	}
}
