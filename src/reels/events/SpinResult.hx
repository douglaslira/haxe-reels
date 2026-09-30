package reels.events;

/** Result returned when a spin completes. */
typedef SpinResult = {
	symbols:Array<Array<String>>,
	wasSkipped:Bool,
	duration:Float
};
