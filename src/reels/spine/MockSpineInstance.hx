package reels.spine;

import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import reels.spine.SpineTypes.SpineSymbolSource;

/**
 * Fake Spine instance. One-shot (non-loop) animations complete on `update(0)`.
 */
class MockSpineInstance implements ISpineInstance {
	var _host:Sprite = new Sprite();
	var _label:TextField;
	var _anims:Map<String, Bool> = new Map();
	var _listeners:Array<Int->Void> = [];
	var _pendingCompleteTrack:Int = -1;
	var _currentName:String = "";
	var _source:SpineSymbolSource;

	public function new(animationNames:Array<String>, source:SpineSymbolSource) {
		_source = source;
		for (a in animationNames) _anims.set(a, true);
		_host.graphics.beginFill(0x2ECC71, 0.85);
		_host.graphics.drawRoundRect(-50, -40, 100, 80, 8);
		_host.graphics.endFill();
		_label = new TextField();
		_label.defaultTextFormat = new TextFormat(
			"_sans", 14, 0xFFFFFF, true, null, null, null, null, TextFormatAlign.CENTER
		);
		_label.width = 100;
		_label.height = 24;
		_label.x = -50;
		_label.y = -12;
		_label.mouseEnabled = false;
		_label.text = source.skin != null ? source.skin : source.skeleton;
		_host.addChild(_label);
	}

	public var displayObject(get, never):DisplayObject;

	function get_displayObject():DisplayObject {
		return _host;
	}

	/** Last animation name set on track 0 (tests). */
	public var currentAnimation(get, never):String;

	function get_currentAnimation():String {
		return _currentName;
	}

	public function hasAnimation(name:String):Bool {
		return _anims.exists(name);
	}

	public function setAnimation(track:Int, name:String, loop:Bool):Void {
		if (!_anims.exists(name)) return;
		_currentName = name;
		// Keep skin/skeleton on the face so sample smoke stays identifiable
		// (animation name alone looked like "stuck on idle").
		_label.text = _source.skin != null ? _source.skin : _source.skeleton;
		_pendingCompleteTrack = loop ? -1 : track;
	}

	public function clearTracks():Void {
		_pendingCompleteTrack = -1;
		_currentName = "";
	}

	public function setToSetupPose():Void {
		_currentName = "";
		_label.text = _source.skin != null ? _source.skin : _source.skeleton;
	}

	public function setSkinByName(skin:String):Void {
		_source = {
			skeleton: _source.skeleton,
			atlas: _source.atlas,
			skin: skin
		};
		_label.text = skin;
	}

	public function setVisible(v:Bool):Void {
		_host.visible = v;
	}

	public function setPosition(x:Float, y:Float):Void {
		_host.x = x;
		_host.y = y;
	}

	public function setScale(s:Float):Void {
		_host.scaleX = s;
		_host.scaleY = s;
	}

	public function update(_delta:Float):Void {
		if (_pendingCompleteTrack < 0) return;
		var track = _pendingCompleteTrack;
		_pendingCompleteTrack = -1;
		var list = _listeners.copy();
		for (cb in list) cb(track);
	}

	public function addCompleteListener(cb:Int->Void):Void {
		if (_listeners.indexOf(cb) < 0) _listeners.push(cb);
	}

	public function removeCompleteListener(cb:Int->Void):Void {
		_listeners.remove(cb);
	}

	public function destroy():Void {
		_listeners = [];
		_pendingCompleteTrack = -1;
		if (_host.parent != null) _host.parent.removeChild(_host);
		_host.removeChildren();
	}
}
