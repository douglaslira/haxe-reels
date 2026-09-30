package reels.spin.modes;

import reels.config.SpeedProfile;

interface SpinningMode {
	function deltaPixels(speed:SpeedProfile, deltaMs:Float, multiplier:Float):Float;
}

class StandardMode implements SpinningMode {
	public function new() {}

	public function deltaPixels(speed:SpeedProfile, deltaMs:Float, multiplier:Float):Float {
		return speed.spinSpeed * multiplier * deltaMs * 0.06;
	}
}
