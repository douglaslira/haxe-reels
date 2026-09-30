package reels.symbols;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import reels.config.CellTypes.ReelCellQuad;

/**
 * Sprite-backed symbol using OpenFL Bitmap.
 * On a curved reel, draws through PerspectiveCell (real keystone).
 */
class BitmapReelSymbol extends ReelSymbol {
	var _host:Sprite;
	var _bitmap:Bitmap;
	var _options:BitmapSymbolOptions;
	var _map:Map<String, BitmapData>;
	var _perspective:PerspectiveCell;

	public function new(?options:BitmapSymbolOptions) {
		_options = options != null ? options : {};
		_map = _options.bitmapDataMap != null ? _options.bitmapDataMap : new Map();
		_host = new Sprite();
		_bitmap = new Bitmap();
		_host.addChild(_bitmap);
		_perspective = new PerspectiveCell(_host, _bitmap);
		super(new OpenFlSymbolView(_host));
		if (_options.bitmapData != null) {
			_bitmap.bitmapData = _options.bitmapData;
		}
	}

	override function onActivate(symbolId:String):Void {
		var bd = _map.get(symbolId);
		if (bd == null && _options.bitmapData != null) bd = _options.bitmapData;
		if (bd != null) _bitmap.bitmapData = bd;
		layout();
	}

	override function onDeactivate():Void {
		_perspective.apply(null, null);
		_bitmap.scaleX = 1;
		_bitmap.scaleY = 1;
	}

	override function onResize(width:Float, height:Float):Void {
		layout();
	}

	override public function applyCellQuad(quad:Null<ReelCellQuad>):Void {
		var bd = _bitmap.bitmapData;
		if (quad == null) {
			_perspective.apply(null, null);
			_host.scaleX = 1;
			_host.scaleY = 1;
			layout();
			return;
		}
		if (_perspective.apply(quad, bd)) {
			_host.scaleX = 1;
			_host.scaleY = 1;
			return;
		}
		layout();
	}

	function layout():Void {
		if (_bitmap.bitmapData == null) return;
		if (_perspective.isActive) return;
		var bw = _bitmap.bitmapData.width;
		var bh = _bitmap.bitmapData.height;
		if (bw <= 0 || bh <= 0) return;
		// Fill the cell (stretch). MultiWays reshape changes cell aspect while
		// atlas bitmaps stay at build-time size — "contain" letterboxing left
		// black gaps between facets (looked like missing cells).
		_bitmap.visible = true;
		if (_cellWidth > 0 && _cellHeight > 0) {
			_bitmap.scaleX = _cellWidth / bw;
			_bitmap.scaleY = _cellHeight / bh;
			_bitmap.x = 0;
			_bitmap.y = 0;
		}
	}

	override function onDestroy():Void {
		_perspective.destroy();
		if (_host.parent != null) _host.parent.removeChild(_host);
		_bitmap.bitmapData = null;
	}
}
