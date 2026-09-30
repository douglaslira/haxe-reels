package reels.core;

/** Travel toward larger (`forward`) or smaller (`reverse`) coordinate. */
enum abstract Direction(String) from String to String {
	var Forward = "forward";
	var Reverse = "reverse";
}
