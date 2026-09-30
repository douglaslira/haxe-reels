package reels.core;

import openfl.Vector;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import reels.util.IDisposable;

/**
 * Bend a whole reel, whatever is inside it.
 *
 * {@link ReelCurve}'s per-symbol projection only keystones texture cells.
 * This renders the reel host to a BitmapData and draws it through a mesh
 * whose vertices carry the same projection — fall/drop-in ride the drum
 * without per-cell re-keystone.
 *
 * Caller keeps {@link source} OFF the scene graph; only {@link view} is shown.
 * Bounce / start-tug stay on the source and are baked into the texture via
 * {@link update}; {@link view} stays at the resting layout pose so the drum
 * silhouette does not translate.
 */
class ReelWarp implements IDisposable {
	static inline var GRID:Int = 16;

	public final view:Sprite = new Sprite();

	var _source:Sprite;
	var _curve:ReelCurve;
	var _axis:ReelAxis;
	var _margin:Float;
	var _bleed:Float;
	var _width:Int;
	var _height:Int;
	var _bd:BitmapData;
	var _mesh:Sprite = new Sprite();
	var _verts:Vector<Float> = new Vector<Float>();
	var _uvs:Vector<Float> = new Vector<Float>();
	var _indices:Vector<Int> = new Vector<Int>();
	var _destroyed:Bool = false;
	var _clearRect:Rectangle = new Rectangle();
	var _drawMatrix:Matrix = new Matrix();

	/**
	 * @param source reel host (drawn off-screen each tick)
	 * @param curve projection for vertex displace
	 * @param axis travel / cross mapping
	 * @param width reel window width (screen)
	 * @param height reel window height (screen)
	 * @param margin buffer slack on main (usually slotPitch)
	 * @param bleed cross-axis overflow room (curveBleed)
	 */
	public function new(
		source:Sprite,
		curve:ReelCurve,
		axis:ReelAxis,
		width:Float,
		height:Float,
		margin:Float = 0,
		bleed:Float = 0
	) {
		_source = source;
		_curve = curve;
		_axis = axis;
		_margin = margin > 0 ? margin : 0;
		_bleed = bleed > 0 ? bleed : 0;

		var grown = _axis.toScreen(_bleed * 2, _margin * 2);
		_width = Std.int(Math.max(1, Math.ceil(width + Math.abs(grown.x))));
		_height = Std.int(Math.max(1, Math.ceil(height + Math.abs(grown.y))));
		_bd = new BitmapData(_width, _height, true, 0);
		_clearRect.setTo(0, 0, _width, _height);

		view.addChild(_mesh);
		rebuildGeometry();
		update(0);
	}

	public var isDestroyed(get, never):Bool;

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	public var textureWidth(get, never):Int;

	function get_textureWidth():Int {
		return _width;
	}

	public var textureHeight(get, never):Int;

	function get_textureHeight():Int {
		return _height;
	}

	public var bleed(get, never):Float;

	function get_bleed():Float {
		return _bleed;
	}

	public var margin(get, never):Float;

	function get_margin():Float {
		return _margin;
	}

	/** Swap projection (reshape / setCurve) and re-displace. */
	public function setCurve(curve:ReelCurve):Void {
		if (_destroyed || curve == null) return;
		_curve = curve;
		rebuildGeometry();
	}

	/**
	 * Redraw the reel into its texture and refresh the mesh fill.
	 * @param sourceMainNudge host bounce / start-tug along main (rest = 0).
	 *   Baked into the capture so motion rides the drum; view stays put.
	 */
	public function update(sourceMainNudge:Float = 0):Void {
		if (_destroyed) return;

		// Zero the host transform and apply shift via Matrix. Off-stage sprites
		// (warp keeps host out of the graph) are unreliable with x/y alone on
		// some OpenFL targets — missing bleed shift left-offsets every reel.
		var savedX = _source.x;
		var savedY = _source.y;
		_source.x = 0;
		_source.y = 0;

		var shift = _axis.toScreen(_bleed, _margin + sourceMainNudge);
		_drawMatrix.identity();
		_drawMatrix.translate(shift.x, shift.y);

		_bd.fillRect(_clearRect, 0);
		_bd.draw(_source, _drawMatrix);

		_source.x = savedX;
		_source.y = savedY;

		paintMesh();
	}

	/** Re-measure after reshape; re-displace when size changes. */
	public function resize(width:Float, height:Float):Void {
		if (_destroyed) return;
		var grown = _axis.toScreen(_bleed * 2, _margin * 2);
		var w = Std.int(Math.max(1, Math.ceil(width + Math.abs(grown.x))));
		var h = Std.int(Math.max(1, Math.ceil(height + Math.abs(grown.y))));
		if (w == _width && h == _height) return;
		_width = w;
		_height = h;
		_bd.dispose();
		_bd = new BitmapData(_width, _height, true, 0);
		_clearRect.setTo(0, 0, _width, _height);
		rebuildGeometry();
	}

	public function destroy():Void {
		if (_destroyed) return;
		_destroyed = true;
		_mesh.graphics.clear();
		if (_mesh.parent != null) _mesh.parent.removeChild(_mesh);
		if (view.parent != null) view.parent.removeChild(view);
		_bd.dispose();
		_verts = null;
		_uvs = null;
		_indices = null;
	}

	function rebuildGeometry():Void {
		_verts.length = 0;
		_uvs.length = 0;
		_indices.length = 0;

		var span = GRID - 1;
		var focus = _curve.focusCross;
		for (j in 0...GRID) {
			var gy = j / span;
			for (i in 0...GRID) {
				var gx = i / span;
				var texel = _axis.toLocal(gx * _width, gy * _height);
				var main = texel.main - _margin;
				var cross = texel.cross - _bleed;
				var scale = _curve.scaleAt(main);
				var screen = _axis.toScreen(
					focus + (cross - focus) * scale,
					_curve.mapMain(main)
				);
				_verts.push(screen.x);
				_verts.push(screen.y);
				_uvs.push(gx);
				_uvs.push(gy);
			}
		}

		for (j in 0...span) {
			for (i in 0...span) {
				var a = j * GRID + i;
				var b = a + 1;
				var c = a + GRID;
				var d = c + 1;
				_indices.push(a);
				_indices.push(b);
				_indices.push(d);
				_indices.push(a);
				_indices.push(d);
				_indices.push(c);
			}
		}

		paintMesh();
	}

	function paintMesh():Void {
		var g = _mesh.graphics;
		g.clear();
		g.beginBitmapFill(_bd, null, false, true);
		g.drawTriangles(_verts, _indices, _uvs);
		g.endFill();
	}
}
