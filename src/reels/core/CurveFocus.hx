package reels.core;

/**
 * Where the camera sits across the strip (pixi `CurveFocus`).
 * - `Reel`: each reel its own drum (default)
 * - `SetLean`: halfway lean toward board centre
 * - `SetFocus`: one camera at the middle of the board
 */
enum abstract CurveFocus(String) from String to String {
	var Reel = "reel";
	var SetLean = "set-lean";
	var SetFocus = "set";

	/** How far each focus mode leans from the reel centreline toward the set. */
	public static function weight(focus:CurveFocus):Float {
		return switch (focus) {
			case Reel: 0;
			case SetLean: 0.5;
			case SetFocus: 1;
		};
	}

	public static function parse(raw:String):CurveFocus {
		if (raw == SetLean) return SetLean;
		if (raw == SetFocus) return SetFocus;
		if (raw == Reel) return Reel;
		throw 'curveFocus(): unknown focus "$raw". Expected reel | set-lean | set';
	}
}
