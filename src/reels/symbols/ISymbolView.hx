package reels.symbols;

import openfl.display.DisplayObject;
import reels.core.IPositionable;

/** Display-agnostic view surface for a symbol. */
interface ISymbolView extends IPositionable {
	var visible(get, set):Bool;
	var alpha(get, set):Float;
	function getDisplayObject():Null<DisplayObject>;
	function destroy():Void;
}
