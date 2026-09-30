package reels.spine;

import openfl.display.DisplayObject;

/**
 * Minimal Spine instance surface used by SpineReelSymbol.
 * Implement against your OpenFL Spine binding — the core never imports Spine.
 */
interface ISpineInstance {
	var displayObject(get, never):DisplayObject;

	function hasAnimation(name:String):Bool;
	function setAnimation(track:Int, name:String, loop:Bool):Void;
	function clearTracks():Void;
	function setToSetupPose():Void;
	function setSkinByName(skin:String):Void;
	function setVisible(v:Bool):Void;
	function setPosition(x:Float, y:Float):Void;
	function setScale(s:Float):Void;
	/** Apply pose / flush pending one-shot completes (mock + real). */
	function update(delta:Float):Void;
	function addCompleteListener(cb:Int->Void):Void;
	function removeCompleteListener(cb:Int->Void):Void;
	function destroy():Void;
}
