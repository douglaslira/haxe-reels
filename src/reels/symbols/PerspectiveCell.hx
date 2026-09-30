package reels.symbols;

import openfl.Vector;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import reels.config.CellTypes.ReelCellQuad;

/**
 * Draws a BitmapData through a projected quad (keystone).
 * Flat path keeps the plain Bitmap visible.
 *
 * Vertices are already in screen/view space (ReelCurve did the projection),
 * so UVs are plain pairs — UVT `t` would re-project and break the quad.
 */
class PerspectiveCell {
	static inline var VERTICES:Int = 8;

	var _view:Sprite;
	var _flat:Bitmap;
	var _mesh:Sprite;
	var _active:Bool = false;
	var _boundBd:Null<BitmapData> = null;
	var _lastKey:String = "";

	public function new(view:Sprite, flat:Bitmap) {
		_view = view;
		_flat = flat;
		_mesh = new Sprite();
		_mesh.visible = false;
		_view.addChild(_mesh);
	}

	public var isActive(get, never):Bool;

	function get_isActive():Bool {
		return _active;
	}

	/**
	 * @return true when the mesh is driving (view must stay identity).
	 */
	public function apply(quad:Null<ReelCellQuad>, bd:Null<BitmapData>):Bool {
		if (quad == null || bd == null) {
			// Always restore the flat bitmap — even if we thought we were
			// already inactive. A stale `_flat.visible = false` left holes
			// after pin-overlay / MultiWays hand-off on Flat boards.
			_active = false;
			_flat.visible = true;
			_mesh.visible = false;
			_mesh.graphics.clear();
			_boundBd = null;
			_lastKey = "";
			return false;
		}

		var key = quadKey(quad) + ":" + bd.width + "x" + bd.height;
		if (key != _lastKey || _boundBd != bd) {
			drawQuad(quad, bd);
			_lastKey = key;
			_boundBd = bd;
		}

		if (!_active) {
			_active = true;
			_flat.visible = false;
			_mesh.visible = true;
		}
		return true;
	}

	public function destroy():Void {
		_mesh.graphics.clear();
		if (_mesh.parent != null) _mesh.parent.removeChild(_mesh);
		_active = false;
		_boundBd = null;
		_lastKey = "";
	}

	function quadKey(q:ReelCellQuad):String {
		return '${q.x0},${q.y0},${q.x1},${q.y1},${q.x2},${q.y2},${q.x3},${q.y3}';
	}

	function drawQuad(quad:ReelCellQuad, bd:BitmapData):Void {
		var g = _mesh.graphics;
		g.clear();
		g.beginBitmapFill(bd, null, false, true);

		var span = VERTICES - 1;
		var verts = new Vector<Float>();
		var uvs = new Vector<Float>();
		var indices = new Vector<Int>();

		for (j in 0...VERTICES) {
			var v = j / span;
			for (i in 0...VERTICES) {
				var u = i / span;
				var tl = (1 - u) * (1 - v);
				var tr = u * (1 - v);
				var br = u * v;
				var bl = (1 - u) * v;
				verts.push(tl * quad.x0 + tr * quad.x1 + br * quad.x2 + bl * quad.x3);
				verts.push(tl * quad.y0 + tr * quad.y1 + br * quad.y2 + bl * quad.y3);
				uvs.push(u);
				uvs.push(v);
			}
		}

		for (j in 0...span) {
			for (i in 0...span) {
				var a = j * VERTICES + i;
				var b = a + 1;
				var c = a + VERTICES;
				var d = c + 1;
				indices.push(a);
				indices.push(b);
				indices.push(d);
				indices.push(a);
				indices.push(d);
				indices.push(c);
			}
		}

		g.drawTriangles(verts, indices, uvs);
		g.endFill();
	}
}
