package reels.spin.phases;

import reels.config.SpeedProfile;
import reels.core.Reel;

/** Slow-down tease before stop. */
class AnticipationPhase extends ReelPhase {
	var _elapsed:Float = 0;
	var _hold:Float = 0;
	var _mul:Float = 0.3;

	public function new(reel:Reel, speed:SpeedProfile) {
		super(reel, speed);
	}

	override function get_name():String {
		return "anticipation";
	}

	override function get_skippable():Bool {
		return true;
	}

	override function onEnter(config:Dynamic):Void {
		_elapsed = 0;
		_hold = _speed.anticipationDelay;
		if (config != null && Reflect.hasField(config, "hold")) {
			_hold = Reflect.field(config, "hold");
		}
		if (config != null && Reflect.hasField(config, "mul")) {
			_mul = Reflect.field(config, "mul");
		}
		_reel.beginBlur();
	}

	override function update(deltaMs:Float):Void {
		if (!_active) return;
		_elapsed += deltaMs;
		var pxPerMs = _speed.spinSpeed * _mul;
		_reel.advance(pxPerMs * deltaMs * 0.06);
		if (_elapsed >= _hold) {
			_reel.endBlur();
			complete();
		}
	}

	override function onSkip():Void {
		_reel.endBlur();
	}
}
