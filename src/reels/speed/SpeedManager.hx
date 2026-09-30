package reels.speed;

import reels.config.SpeedPresets;
import reels.config.SpeedProfile;
import reels.events.EventEmitter;
import reels.events.ReelEvents;

class SpeedManager {
	var _profiles:Map<String, SpeedProfile> = new Map();
	var _current:SpeedProfile;
	var _events:EventEmitter;

	public function new(events:EventEmitter) {
		_events = events;
		addProfile(SpeedPresets.NORMAL);
		addProfile(SpeedPresets.TURBO);
		addProfile(SpeedPresets.SUPER_TURBO);
		_current = SpeedPresets.NORMAL;
	}

	public var current(get, never):SpeedProfile;

	function get_current():SpeedProfile {
		return _current;
	}

	public function addProfile(profile:SpeedProfile):Void {
		_profiles.set(profile.name, profile);
	}

	public function setSpeed(name:String):Void {
		var next = _profiles.get(name);
		if (next == null) throw 'Unknown speed profile: $name';
		if (next == _current) return;
		var previous = _current;
		_current = next;
		_events.emit(ReelEvents.SPEED_CHANGED, [next, previous]);
	}

	public function getFastest():SpeedProfile {
		var best:SpeedProfile = _current;
		for (p in _profiles) {
			if (p.spinSpeed > best.spinSpeed) best = p;
		}
		return best;
	}

	public function has(name:String):Bool {
		return _profiles.exists(name);
	}
}
