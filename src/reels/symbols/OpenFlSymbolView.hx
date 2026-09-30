package reels.symbols;

import openfl.display.DisplayObject;
import openfl.display.Sprite;

class OpenFlSymbolView implements ISymbolView {
	var _target:Sprite;

	public function new(target:Sprite) {
		_target = target;
	}

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var visible(get, set):Bool;
	public var alpha(get, set):Float;

	function get_x():Float return _target.x;
	function set_x(v:Float):Float return _target.x = v;
	function get_y():Float return _target.y;
	function set_y(v:Float):Float return _target.y = v;
	function get_visible():Bool return _target.visible;
	function set_visible(v:Bool):Bool return _target.visible = v;
	function get_alpha():Float return _target.alpha;
	function set_alpha(v:Float):Float return _target.alpha = v;

	public function getDisplayObject():Null<DisplayObject> {
		return _target;
	}

	public function destroy():Void {}
}
