package reels.pins;

/** How a pin behaves when MultiWays reshape changes cell count. */
enum abstract PinMigration(String) from String to String {
	var Origin = "origin";
	var Frozen = "frozen";
}
