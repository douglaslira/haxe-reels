package reels.board;

/** Feature phase of {@link HoldAndWinState}. */
enum abstract HwPhase(String) from String to String {
	var Idle = "idle";
	var Active = "active";
	var Spinning = "spinning";
}
