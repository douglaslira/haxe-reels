package reels.config;

import reels.util.AbortToken;

/**
 * Options for {@link reels.ReelSet.nudge} / {@link reels.core.Reel.nudge}.
 * Post-stop strip shift by `distance` positions with caller-supplied symbols.
 */
typedef NudgeOptions = {
	/** Full symbol positions to shift (>= 1, < strip capacity). */
	distance:Int,
	/** Relative to the reel's own axis: `forward` | `reverse`. */
	direction:String,
	/**
	 * Symbol ids in start-to-end order of their final on-strip position.
	 * Length must equal `distance`.
	 */
	incoming:Array<String>,
	/** Total animation duration in ms. Defaults to `200 * distance`. */
	?duration:Float,
	/** Easing name (`power2.out` default). */
	?ease:String,
	/** Delay (ms) before strip mutation + tween. */
	?startDelay:Float,
	/** Abort mid-flight (lands deterministically, fires `nudge:cancelled`). */
	?abort:AbortToken
};
