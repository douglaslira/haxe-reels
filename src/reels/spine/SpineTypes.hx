package reels.spine;

/**
 * One Spine source: skeleton/atlas aliases + optional skin.
 * Consumer's factory resolves these against its loaded assets.
 */
typedef SpineSymbolSource = {
	skeleton:String,
	atlas:String,
	?skin:String
};

/** Canonical Bonbon-style roles (ADR 011 vocabulary). */
enum abstract SpineAnimRole(String) from String to String {
	var Idle = "idle";
	var Landing = "landing";
	var Win = "win";
	var Out = "out";
	var Blur = "blur";
}

/** Per-symbol animation name overrides (patch asset typos). */
typedef SymbolAnimOverrides = Map<String, Map<String, String>>;

typedef SpineReelSymbolOptions = {
	/** Creates ISpineInstance from a source — inject real OpenFL Spine here. */
	factory:ISpineFactory,
	/** symbolId -> spine source. */
	spineMap:Map<String, SpineSymbolSource>,
	?idleAnimation:String,
	?winAnimation:String,
	?landingAnimation:String,
	/** Cascade pop / disintegrate. Default "disintegration". */
	?outAnimation:String,
	?blurAnimation:String,
	?animations:SymbolAnimOverrides,
	?scale:Float
};
