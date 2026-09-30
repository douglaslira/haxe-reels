package reels.symbols;

import openfl.display.Sprite;
import reels.config.CellTypes.ReelCellQuad;

/**
 * Affine contain-fit for symbols that cannot draw a real keystone (Spine,
 * composite subtrees). Parity with pixi {@code ReelSymbol.applyCellQuad}
 * default: uniform scale inside the projected footprint + center on the quad.
 *
 * OpenFL has no pivot like Pixi — callers keep a nested {@code fit} Sprite
 * under the reel-positioned slot; this helper only mutates {@code fit}.
 */
class AffineCellFit {
	/** Reset fit to identity (flat cell). */
	public static function clear(fit:Sprite):Void {
		fit.scaleX = 1;
		fit.scaleY = 1;
		fit.x = 0;
		fit.y = 0;
	}

	/**
	 * Scale {@code fit} uniformly to sit inside {@code quad}, centred on the
	 * trapezoid. Art is assumed laid out in the flat cell box
	 * {@code (0,0)-(cellW,cellH)} with its visual centre at mid-cell.
	 */
	public static function apply(fit:Sprite, quad:ReelCellQuad, cellW:Float, cellH:Float):Void {
		if (quad == null || cellW <= 0 || cellH <= 0) {
			clear(fit);
			return;
		}
		var nearWidth = Math.sqrt(sq(quad.x1 - quad.x0) + sq(quad.y1 - quad.y0));
		var farWidth = Math.sqrt(sq(quad.x2 - quad.x3) + sq(quad.y2 - quad.y3));
		var across = (nearWidth + farWidth) * 0.5;
		var midNearX = (quad.x0 + quad.x1) * 0.5;
		var midNearY = (quad.y0 + quad.y1) * 0.5;
		var midFarX = (quad.x3 + quad.x2) * 0.5;
		var midFarY = (quad.y3 + quad.y2) * 0.5;
		var along = Math.sqrt(sq(midFarX - midNearX) + sq(midFarY - midNearY));
		var scale = 1.;
		if (quad.width > 0 && quad.height > 0) {
			scale = Math.min(across / quad.width, along / quad.height);
		}
		var cx = (quad.x0 + quad.x1 + quad.x2 + quad.x3) * 0.25;
		var cy = (quad.y0 + quad.y1 + quad.y2 + quad.y3) * 0.25;
		fit.scaleX = scale;
		fit.scaleY = scale;
		// After uniform scale about (0,0), mid-cell lands at (cellW/2*s, cellH/2*s).
		fit.x = cx - (cellW * 0.5) * scale;
		fit.y = cy - (cellH * 0.5) * scale;
	}

	static inline function sq(v:Float):Float {
		return v * v;
	}
}
