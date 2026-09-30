package reels.frame;

import reels.frame.ColumnTarget;

class ColumnTargets {
	public static function getTargetSlot(target:ColumnTarget, cell:Int):Null<String> {
		if (cell < 0) {
			var above = target.bufferStart;
			return above == null ? null : above[-1 - cell];
		}
		if (cell < target.visible.length) return target.visible[cell];
		var below = target.bufferEnd;
		return below == null ? null : below[cell - target.visible.length];
	}

	/**
	 * Write a strip-relative cell on a ColumnTarget (mutates). Negative =
	 * bufferStart; past visible = bufferEnd. Extends buffer arrays as needed.
	 */
	public static function setTargetSlot(target:ColumnTarget, cell:Int, id:String):Void {
		if (cell < 0) {
			if (target.bufferStart == null) target.bufferStart = [];
			var idx = -1 - cell;
			while (target.bufferStart.length <= idx) target.bufferStart.push(null);
			target.bufferStart[idx] = id;
		} else if (cell < target.visible.length) {
			target.visible[cell] = id;
		} else {
			if (target.bufferEnd == null) target.bufferEnd = [];
			var idx = cell - target.visible.length;
			while (target.bufferEnd.length <= idx) target.bufferEnd.push(null);
			target.bufferEnd[idx] = id;
		}
	}

	public static function columnTargetToStrip(target:ColumnTarget, bufferStart:Int):Array<Null<String>> {
		var belowLength = target.bufferEnd == null ? 0 : target.bufferEnd.length;
		var strip:Array<Null<String>> = [];
		var len = bufferStart + target.visible.length + belowLength;
		for (i in 0...len) {
			strip.push(getTargetSlot(target, i - bufferStart));
		}
		return strip;
	}

	public static function cloneColumnTarget(target:ColumnTarget):ColumnTarget {
		return {
			visible: target.visible.copy(),
			bufferStart: target.bufferStart == null ? null : target.bufferStart.copy(),
			bufferEnd: target.bufferEnd == null ? null : target.bufferEnd.copy()
		};
	}

	public static function assertColumnTargets(grid:Dynamic, callerLabel:String):Void {
		if (!Std.isOfType(grid, Array)) {
			throw '$callerLabel: expected ColumnTarget[], got ${Type.typeof(grid)}';
		}
		var arr:Array<Dynamic> = cast grid;
		for (c in 0...arr.length) {
			var item = arr[c];
			if (Std.isOfType(item, Array)) {
				throw '$callerLabel: column $c is a plain Array. Wrap each column: { visible: [...] }.';
			}
			if (item == null || item.visible == null || !Std.isOfType(item.visible, Array)) {
				throw '$callerLabel: column $c has no visible array.';
			}
		}
	}

	public static function fromVisibleGrid(grid:Array<Array<String>>):Array<ColumnTarget> {
		return [for (col in grid) {visible: col}];
	}
}
