package tests;

import reels.spine.MockSpineFactory;
import reels.spine.MockSpineInstance;
import reels.spine.SpineReelSymbol;
import reels.spine.SpineTypes.SpineSymbolSource;
import utest.Assert;
import utest.Test;

class TestSpineReelSymbol extends Test {
	static function wildMap():Map<String, SpineSymbolSource> {
		return ["wild" => {skeleton: "wild-skel", atlas: "wild-atlas", skin: "wild"}];
	}

	static function makeSymbol(?overrides:Map<String, Map<String, String>>):SpineReelSymbol {
		return new SpineReelSymbol({
			factory: new MockSpineFactory(),
			spineMap: wildMap(),
			animations: overrides
		});
	}

	public function testActivatePlaysIdle() {
		var s = makeSymbol();
		s.resize(100, 100);
		s.activate("wild");
		Assert.notNull(s.spine);
		var mock:MockSpineInstance = cast s.spine;
		Assert.equals("idle", mock.currentAnimation);
		Assert.floatEquals(50, mock.displayObject.x, 0.01);
		Assert.floatEquals(50, mock.displayObject.y, 0.01);
		s.destroy();
	}

	public function testPlayWinThenReturnsToIdle() {
		var s = makeSymbol();
		s.resize(80, 80);
		s.activate("wild");
		var done = false;
		s.playWin(function() done = true);
		Assert.isTrue(done);
		var mock:MockSpineInstance = cast s.spine;
		Assert.equals("idle", mock.currentAnimation);
		s.destroy();
	}

	public function testPlayOutDoesNotReturnToIdle() {
		var s = makeSymbol();
		s.activate("wild");
		var done = false;
		s.playOut(function() done = true);
		Assert.isTrue(done);
		var mock:MockSpineInstance = cast s.spine;
		Assert.equals("disintegration", mock.currentAnimation);
		s.destroy();
	}

	public function testMissingAnimIsNoop() {
		var s = new SpineReelSymbol({
			factory: new MockSpineFactory(["idle"]), // no win
			spineMap: wildMap()
		});
		s.activate("wild");
		var done = false;
		s.playWin(function() done = true);
		Assert.isTrue(done);
		var mock:MockSpineInstance = cast s.spine;
		Assert.equals("idle", mock.currentAnimation);
		s.destroy();
	}

	public function testAnimOverride() {
		var s = makeSymbol(["wild" => ["idle" => "ide", "win" => "bigwin"]]);
		// Mock only has standard names — override to missing means playWin no-ops
		// unless we register the override names on the factory.
		s.destroy();

		var factory = new MockSpineFactory(["ide", "bigwin", "disintegration"]);
		var s2 = new SpineReelSymbol({
			factory: factory,
			spineMap: wildMap(),
			animations: ["wild" => ["idle" => "ide", "win" => "bigwin"]]
		});
		s2.activate("wild");
		var mock:MockSpineInstance = cast s2.spine;
		Assert.equals("ide", mock.currentAnimation);
		var done = false;
		s2.playWin(function() done = true);
		Assert.isTrue(done);
		Assert.equals("ide", mock.currentAnimation); // returnToIdle uses override
		s2.destroy();
	}

	public function testPlayDestroyUsesOutWhenPresent() {
		var s = makeSymbol();
		s.activate("wild");
		var done = false;
		s.playDestroy({}, function() done = true, null);
		Assert.isTrue(done);
		Assert.floatEquals(0, s.alpha, 0.001);
		s.destroy();
	}

	public function testDeactivateResetsAndHides() {
		var s = makeSymbol();
		s.activate("wild");
		var mock:MockSpineInstance = cast s.spine;
		s.playBlur();
		Assert.equals("blur", mock.currentAnimation);
		s.deactivate();
		Assert.isNull(s.spine);
		Assert.isFalse(mock.displayObject.visible);
		s.destroy();
	}

	public function testStopAnimationReturnsIdle() {
		var s = makeSymbol();
		s.activate("wild");
		s.playBlur();
		s.stopAnimation();
		var mock:MockSpineInstance = cast s.spine;
		Assert.equals("idle", mock.currentAnimation);
		s.destroy();
	}

	public function testUnknownSymbolActivateIsSafe() {
		var s = makeSymbol();
		s.activate("missing");
		Assert.isNull(s.spine);
		var done = false;
		s.playWin(function() done = true);
		Assert.isTrue(done);
		s.destroy();
	}

	public function testPlayWinSettledWhenRecycledMidShot() {
		var s = makeSymbol();
		s.activate("wild");
		// Start win but recycle before natural complete by resolving via deactivate.
		var settled = 0;
		// Force a pending one-shot without flushing: use a factory that doesn't auto-complete.
		var holdFactory = new HoldCompleteFactory();
		var s2 = new SpineReelSymbol({
			factory: holdFactory,
			spineMap: wildMap()
		});
		s2.activate("wild");
		s2.playWin(function() settled++);
		Assert.equals(0, settled);
		s2.deactivate(); // must settle dangling playWin
		Assert.equals(1, settled);
		s.destroy();
		s2.destroy();
	}
}

/** Factory whose instances never auto-complete one-shots until destroy/clear. */
private class HoldCompleteFactory implements reels.spine.ISpineFactory {
	public function new() {}

	public function create(source:SpineSymbolSource):reels.spine.ISpineInstance {
		return new HoldCompleteInstance(source);
	}
}

private class HoldCompleteInstance implements reels.spine.ISpineInstance {
	var _host = new openfl.display.Sprite();
	var _listeners:Array<Int->Void> = [];
	var _name = "";

	public function new(source:SpineSymbolSource) {
		_host.graphics.beginFill(0x888888);
		_host.graphics.drawRect(-10, -10, 20, 20);
		_host.graphics.endFill();
	}

	public var displayObject(get, never):openfl.display.DisplayObject;
	function get_displayObject() return _host;

	public function hasAnimation(name:String):Bool return true;
	public function setAnimation(track:Int, name:String, loop:Bool):Void _name = name;
	public function clearTracks():Void {}
	public function setToSetupPose():Void {}
	public function setSkinByName(skin:String):Void {}
	public function setVisible(v:Bool):Void _host.visible = v;
	public function setPosition(x:Float, y:Float):Void { _host.x = x; _host.y = y; }
	public function setScale(s:Float):Void { _host.scaleX = s; _host.scaleY = s; }
	public function update(_):Void {}
	public function addCompleteListener(cb:Int->Void):Void _listeners.push(cb);
	public function removeCompleteListener(cb:Int->Void):Void _listeners.remove(cb);
	public function destroy():Void {
		_listeners = [];
		if (_host.parent != null) _host.parent.removeChild(_host);
	}
}
