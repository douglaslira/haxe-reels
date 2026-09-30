package reels.spin.phases;

import reels.config.SpeedProfile;
import reels.core.Reel;

/**
 * Timed hold between SPIN and STOP after a MultiWays reshape.
 * Geometry is already committed in {@link reels.ReelSet.applyReshapeForReel};
 * pin-overlay position/size tweens run on the shared TweenDriver for
 * `pinMigrationDuration` / `adjustDuration`. This phase waits that window
 * and snaps overlays on skip.
 */
class AdjustPhase extends ReelPhase {
	var _elapsed:Float = 0;
	var _duration:Float = 0;
	var _snapPinOverlays:Null<() -> Void>;

	public function new(reel:Reel, speed:SpeedProfile, durationMs:Float) {
		super(reel, speed);
		_duration = durationMs < 0 ? 0 : durationMs;
	}

	override function get_name():String {
		return "adjust";
	}

	override function get_skippable():Bool {
		return true;
	}

	override function onEnter(config:Dynamic):Void {
		_elapsed = 0;
		_snapPinOverlays = config != null ? config.snapPinOverlays : null;
		if (_duration <= 0) {
			if (_snapPinOverlays != null) _snapPinOverlays();
			complete();
		}
	}

	override function update(deltaMs:Float):Void {
		if (!_active) return;
		_elapsed += deltaMs;
		if (_elapsed >= _duration) complete();
	}

	override function onSkip():Void {
		if (_snapPinOverlays != null) _snapPinOverlays();
	}
}
