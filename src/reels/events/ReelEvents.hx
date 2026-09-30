package reels.events;

/** Common ReelSet event names (colon-namespaced). */
class ReelEvents {
	public static inline var SPIN_START = "spin:start";
	public static inline var SPIN_ALL_STARTED = "spin:allStarted";
	public static inline var SPIN_STOPPING = "spin:stopping";
	public static inline var SPIN_REEL_LANDED = "spin:reelLanded";
	public static inline var SPIN_ALL_LANDED = "spin:allLanded";
	public static inline var SPIN_COMPLETE = "spin:complete";
	public static inline var SKIP_REQUESTED = "skip:requested";
	public static inline var SKIP_COMPLETED = "skip:completed";
	public static inline var SKIP_BOOSTED = "skip:boosted";
	public static inline var SPEED_CHANGED = "speed:changed";
	public static inline var PHASE_ENTER = "phase:enter";
	public static inline var PHASE_EXIT = "phase:exit";
	public static inline var CASCADE_FALL_START = "cascade:fall:start";
	public static inline var CASCADE_FALL_END = "cascade:fall:end";
	public static inline var CASCADE_PLACE_END = "cascade:place:end";
	public static inline var CASCADE_DROPIN_START = "cascade:dropIn:start";
	public static inline var CASCADE_DROPIN_END = "cascade:dropIn:end";
	public static inline var CASCADE_GRAVITY_START = "cascade:gravity:start";
	public static inline var CASCADE_GRAVITY_END = "cascade:gravity:end";
	public static inline var CASCADE_DESTROY_START = "cascade:destroy:start";
	public static inline var CASCADE_DESTROY_END = "cascade:destroy:end";
	public static inline var CASCADE_CHAIN_START = "cascade:chain:start";
	public static inline var CASCADE_CHAIN_END = "cascade:chain:end";
	public static inline var SHAPE_CHANGED = "shape:changed";
	public static inline var ADJUST_START = "adjust:start";
	public static inline var ADJUST_COMPLETE = "adjust:complete";
	public static inline var PIN_PLACED = "pin:placed";
	public static inline var PIN_EXPIRED = "pin:expired";
	public static inline var PIN_MIGRATED = "pin:migrated";
	public static inline var PIN_MOVED = "pin:moved";
	public static inline var PIN_OVERLAY_CREATED = "pin:overlayCreated";
	public static inline var PIN_OVERLAY_DESTROYED = "pin:overlayDestroyed";
	public static inline var SPOTLIGHT_START = "spotlight:start";
	public static inline var SPOTLIGHT_END = "spotlight:end";
	public static inline var WIN_START = "win:start";
	public static inline var WIN_GROUP = "win:group";
	public static inline var WIN_SYMBOL = "win:symbol";
	public static inline var WIN_END = "win:end";
	public static inline var NUDGE_START = "nudge:start";
	public static inline var NUDGE_COMPLETE = "nudge:complete";
	public static inline var NUDGE_CANCELLED = "nudge:cancelled";
}
