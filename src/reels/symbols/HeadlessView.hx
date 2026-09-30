package reels.symbols;

import openfl.display.DisplayObject;
import openfl.display.Sprite;
import reels.core.IPositionable;

/**
 * Headless view with a real Sprite so promote/parent invariants can be tested
 * under FakeClock without textures.
 */
class HeadlessView implements ISymbolView {
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var visible(get, set):Bool;
	public var alpha(get, set):Float;

	var _sprite:Sprite = new Sprite();

	public function new() {}

	function get_x():Float return _sprite.x;
	function set_x(v:Float):Float return _sprite.x = v;
	function get_y():Float return _sprite.y;
	function set_y(v:Float):Float return _sprite.y = v;
	function get_visible():Bool return _sprite.visible;
	function set_visible(v:Bool):Bool return _sprite.visible = v;
	function get_alpha():Float return _sprite.alpha;
	function set_alpha(v:Float):Float return _sprite.alpha = v;

	public function getDisplayObject():Null<DisplayObject> {
		return _sprite;
	}

	public function destroy():Void {
		if (_sprite.parent != null) _sprite.parent.removeChild(_sprite);
	}
}
