package reels.config;

/** Timing / speed profile for a spin. */
typedef SpeedProfile = {
	name:String,
	spinDelay:Float,
	spinSpeed:Float,
	stopDelay:Float,
	anticipationDelay:Float,
	bounceDistance:Float,
	bounceDuration:Float,
	accelerationEase:String,
	decelerationEase:String,
	accelerationDuration:Float,
	minimumSpinTime:Float
};
