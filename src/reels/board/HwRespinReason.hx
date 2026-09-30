package reels.board;

/** Why the respin counter changed — disambiguates a `respins:changed` effect. */
enum abstract HwRespinReason(String) from String to String {
	var Seed = "seed";
	var HitReset = "hit-reset";
	var Miss = "miss";
}
