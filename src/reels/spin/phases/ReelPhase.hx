package reels.spin.phases;

import reels.config.SpeedProfile;
import reels.core.Reel;
import reels.events.ReelEvents;

/**
 * Abstract base for reel spin phases: START → SPIN → ANTICIPATION → STOP.
 */
class ReelPhase {
	public var name(get, never):String;
	public var skippable(get, never):Bool;
	public var isActive(get, never):Bool;
	public var reel(get, never):Reel;

	var _reel:Reel;
	var _speed:SpeedProfile;
	var _resolve:Null<() -> Void>;
	var _active:Bool = false;

	public function new(reel:Reel, speed:SpeedProfile) {
		_reel = reel;
		_speed = speed;
	}

	function get_name():String {
		return "phase";
	}

	function get_skippable():Bool {
		return true;
	}

	function get_isActive():Bool {
		return _active;
	}

	function get_reel():Reel {
		return _reel;
	}

	public function run(?config:Dynamic, onComplete:() -> Void):Void {
		_active = true;
		_reel.events.emit(ReelEvents.PHASE_ENTER, [name]);
		_resolve = function() {
			_active = false;
			_reel.events.emit(ReelEvents.PHASE_EXIT, [name]);
			onComplete();
		};
		onEnter(config);
	}

	public function skip():Void {
		if (!skippable || !_active) return;
		onSkip();
		complete();
	}

	public function forceComplete():Void {
		if (!_active) return;
		onSkip();
		complete();
	}

	/**
	 * Abort without invoking the run() continuation. Used by slam/teardown
	 * so StartPhase does not chain into SpinPhase after a hard land.
	 */
	public function abort():Void {
		if (!_active) return;
		onSkip();
		_active = false;
		_resolve = null;
		_reel.events.emit(ReelEvents.PHASE_EXIT, [name]);
	}

	public function update(deltaMs:Float):Void {}

	function onEnter(config:Dynamic):Void {}

	function onSkip():Void {}

	function complete():Void {
		if (_resolve != null) {
			var r = _resolve;
			_resolve = null;
			r();
		}
	}
}
