package reels.wins;

import reels.config.WinTypes.Win;

/** Non-mutating sort by `value` descending; missing value sorts as 0. */
class WinSort {
	public static function sortByValueDesc(wins:Array<Win>):Array<Win> {
		var out = wins.copy();
		out.sort(function(a, b) {
			var va = a.value != null ? a.value : 0.;
			var vb = b.value != null ? b.value : 0.;
			if (vb > va) return 1;
			if (vb < va) return -1;
			return 0;
		});
		return out;
	}
}
