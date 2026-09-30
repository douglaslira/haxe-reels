package reels.spin.phases;

import reels.cascade.TumbleAlgorithm;
import reels.cascade.TumbleConfigUtil;
import reels.config.SpeedProfile;
import reels.core.Reel;
import reels.events.EventEmitter;
import reels.events.ReelEvents;
import reels.frame.ColumnTarget;

/**
 * Identity swap for tumble. Survivors visible; movers alpha 0 until DropIn.
 */
class CascadePlacePhase extends ReelPhase {
	var _gravitySetting:String;
	var _events:Null<EventEmitter>;
	var _delay:Float = 0;
	var _elapsed:Float = 0;
	var _done:Bool = false;
	var _target:Null<ColumnTarget>;
	var _winnerCells:Array<Int> = [];
	var _initial:Bool = false;

	public function new(reel:Reel, speed:SpeedProfile, gravitySetting:String) {
		super(reel, speed);
		_gravitySetting = gravitySetting;
	}

	override function get_name():String {
		return "cascade:place";
	}

	override function onEnter(config:Dynamic):Void {
		_elapsed = 0;
		_done = false;
		_delay = config != null && config.delay != null ? config.delay : 0;
		_events = config != null ? config.events : null;
		_target = config != null ? config.target : null;
		_winnerCells = config != null && config.winnerCells != null ? config.winnerCells : [];
		_initial = config != null && config.initial == true;

		if (_delay <= 0) doPlace();
	}

	override function update(deltaMs:Float):Void {
		if (!_active || _done) return;
		_elapsed += deltaMs;
		if (_elapsed >= _delay) doPlace();
	}

	function doPlace():Void {
		if (_done) return;
		_done = true;
		if (_target == null) {
			complete();
			return;
		}

		var gravity = TumbleConfigUtil.resolveGravity(_gravitySetting, _reel.axis.direction);
		var offsets = TumbleAlgorithm.computeDropOffsets(
			_reel.visibleCells,
			_winnerCells,
			{initial: _initial, gravity: gravity}
		);
		var movers:Array<Int> = [];
		for (o in offsets) {
			if (o.offsetCells != 0) movers.push(o.cell);
		}

		_reel.placeVisible(_target, movers);
		if (_events != null) _events.emit(ReelEvents.CASCADE_PLACE_END, [_reel.index]);
		complete();
	}

	override function onSkip():Void {
		if (!_done) doPlace();
	}
}
