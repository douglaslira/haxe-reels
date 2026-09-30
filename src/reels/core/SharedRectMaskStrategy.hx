package reels.core;

import openfl.display.Shape;

/**
 * Single bounding-box mask covering the whole viewport. Ignores per-reel
 * `rects` (pyramid peek is acceptable — covered by frame art in production).
 *
 * Use when symbols may overrun a per-reel clip (BoardGrid 1×1 cells, big
 * symbols across a cross-axis gap). Cross-axis `bleed` expands the box.
 */
class SharedRectMaskStrategy implements MaskStrategy {
	public function new() {}

	public var version(get, never):Int;

	function get_version():Int {
		return MaskStrategyVersion.V2;
	}

	public function build(ctx:MaskContext):Shape {
		var g = new Shape();
		draw(g, ctx);
		return g;
	}

	public function update(shape:Shape, ctx:MaskContext):Void {
		draw(shape, ctx);
	}

	function draw(g:Shape, ctx:MaskContext):Void {
		var bleed = ctx.bleed != null ? ctx.bleed : 0.;
		var inset = ctx.mainInset != null ? ctx.mainInset : 0.;
		var x = 0.;
		var y = 0.;
		var w = ctx.width;
		var h = ctx.height;
		if (ctx.verticalMain) {
			x = -bleed;
			w = ctx.width + 2 * bleed;
			if (inset > 0) {
				y = inset;
				h = Math.max(0, ctx.height - 2 * inset);
			}
		} else {
			y = -bleed;
			h = ctx.height + 2 * bleed;
			if (inset > 0) {
				x = inset;
				w = Math.max(0, ctx.width - 2 * inset);
			}
		}
		g.graphics.clear();
		g.graphics.beginFill(0xFFFFFF, 1);
		g.graphics.drawRect(x, y, w, h);
		g.graphics.endFill();
	}
}
