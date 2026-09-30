package reels.tween;

class Easing {
	public static function linear(t:Float):Float {
		return t;
	}

	public static function quadIn(t:Float):Float {
		return t * t;
	}

	public static function quadOut(t:Float):Float {
		return t * (2 - t);
	}

	public static function quadInOut(t:Float):Float {
		return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
	}

	public static function resolve(name:String):Float->Float {
		return switch (name) {
			case "power1.in", "power2.in": quadIn;
			case "power1.out", "power2.out": quadOut;
			case "power1.inOut", "power2.inOut": quadInOut;
			default: linear;
		};
	}
}
