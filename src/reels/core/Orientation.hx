package reels.core;

/** Strip travels on Y (reels along X) or X (reels along Y). */
enum abstract Orientation(String) from String to String {
	var Vertical = "vertical";
	var Horizontal = "horizontal";
}
