package reels.cascade;

import reels.core.Direction;

/**
 * Tumble cascade timing + gravity helpers (pixi-reels ADR 010 / 016).
 */
class TumbleConfigUtil {
	public static final DEFAULT_GRAVITY:Direction = Forward;

	public static function resolveTumbleConfig(?config:TumbleConfig):ResolvedTumbleConfig {
		var fall = config != null ? config.fall : null;
		var drop = config != null ? config.dropIn : null;
		return {
			gravity: config != null && config.gravity != null ? config.gravity : "auto",
			fall: {
				duration: fall != null && fall.duration != null ? fall.duration : 300,
				ease: fall != null && fall.ease != null ? fall.ease : "power1.in",
				cellStagger: fall != null && fall.cellStagger != null ? fall.cellStagger : 0,
				cellOrder: fall != null && fall.cellOrder != null ? fall.cellOrder : "auto"
			},
			dropIn: {
				duration: drop != null && drop.duration != null ? drop.duration : 600,
				ease: drop != null && drop.ease != null ? drop.ease : "power2.out",
				cellStagger: drop != null && drop.cellStagger != null ? drop.cellStagger : 60,
				cellOrder: drop != null && drop.cellOrder != null ? drop.cellOrder : "auto",
				distance: drop != null && drop.distance != null ? drop.distance : "perHole"
			}
		};
	}

	public static function resolveGravity(gravity:String, direction:Direction):Direction {
		if (gravity == "auto" || gravity == null) return direction;
		return gravity == "reverse" ? Reverse : Forward;
	}

	public static function gravitySign(gravity:Direction):Int {
		return gravity == Forward ? 1 : -1;
	}

	public static function resolveCellOrder(cellOrder:String, gravity:Direction):String {
		if (cellOrder != "auto" && cellOrder != null) return cellOrder;
		return gravity == Forward ? "endFirst" : "startFirst";
	}
}
