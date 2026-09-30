package reels.util;

/**
 * Contract for objects that allocate resources and need cleanup.
 */
interface IDisposable {
	function destroy():Void;
	var isDestroyed(get, never):Bool;
}
