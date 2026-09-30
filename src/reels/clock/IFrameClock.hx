package reels.clock;

/**
 * Frame clock abstraction. Domain depends on this, not OpenFL Stage.
 */
interface IFrameClock {
	function add(callback:Float->Void):Void;
	function remove(callback:Float->Void):Void;
	function destroy():Void;
	var isDestroyed(get, never):Bool;
}
