package reels.pins;

/** Why a pin left the map (`pin:expired`). */
enum abstract PinExpireReason(String) from String to String {
	var Turns = "turns";
	var Explicit = "explicit";
	var Eval = "eval";
	var Collision = "collision";
}
