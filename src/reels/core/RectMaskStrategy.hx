package reels.core;

import openfl.display.Shape;

/**
 * Default: one rect per entry in `ctx.rects`. Empty `rects` → single bounding
 * box (with optional mainInset / cross bleed), matching the pre-strategy viewport.
 */
class RectMaskStrategy implements MaskStrategy {
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
		g.graphics.clear();
		g.graphics.beginFill(0xFFFFFF, 1);
		if (ctx.rects == null || ctx.rects.length == 0) {
			drawBounds(g, ctx);
		} else {
			for (r in ctx.rects) {
				g.graphics.drawRect(r.x, r.y, r.width, r.height);
			}
		}
		g.graphics.endFill();
	}

	static function drawBounds(g:Shape, ctx:MaskContext):Void {
		var bleed = ctx.bleed != null ? ctx.bleed : 0.;
		var inset = ctx.mainInset != null ? ctx.mainInset : 0.;
		var x = 0.;
		var y = 0.;
		var w = ctx.width;
		var h = ctx.height;
		if (inset > 0 || bleed > 0) {
			if (ctx.verticalMain) {
				y = inset;
				h = Math.max(0, ctx.height - 2 * inset);
				x = -bleed;
				w = ctx.width + 2 * bleed;
			} else {
				x = inset;
				w = Math.max(0, ctx.width - 2 * inset);
				y = -bleed;
				h = ctx.height + 2 * bleed;
			}
		}
		g.graphics.drawRect(x, y, w, h);
	}
}
