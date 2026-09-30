package reels.symbols;

import reels.config.Defaults;
import reels.pool.ObjectPool;
import reels.util.IDisposable;

/**
 * Creates and pools ReelSymbol instances keyed by symbol id.
 */
class SymbolFactory implements IDisposable {
	var _registry:SymbolRegistry;
	var _pool:ObjectPool<ReelSymbol>;
	var _destroyed:Bool = false;
	var _cellW:Float;
	var _cellH:Float;

	public function new(registry:SymbolRegistry, cellW:Float, cellH:Float, maxPerKey:Int = Defaults.MAX_POOL_PER_KEY) {
		_registry = registry;
		_cellW = cellW;
		_cellH = cellH;
		_pool = new ObjectPool(
			function(key) {
				var s = _registry.create(key);
				s.resize(_cellW, _cellH);
				return s;
			},
			function(item) {
				item.resize(_cellW, _cellH);
			},
			function(item) {
				item.destroy();
			},
			maxPerKey
		);
	}

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	public var isDestroyed(get, never):Bool;

	public function has(id:String):Bool {
		return _registry.has(id);
	}

	public function getSize(id:String):reels.symbols.SymbolSize {
		return _registry.getSize(id);
	}

	public function acquire(symbolId:String):ReelSymbol {
		var s = _pool.acquire(symbolId);
		s.resize(_cellW, _cellH);
		s.activate(symbolId);
		return s;
	}

	public function release(symbol:ReelSymbol):Void {
		if (_destroyed || symbol == null) return;
		// Always detach — a pooled symbol left on a DisplayObjectContainer
		// will be stolen on the next acquire/addChild (silent blank cells).
		var d = symbol.displayObject;
		if (d != null && d.parent != null) {
			d.parent.removeChild(d);
		}
		var id = symbol.symbolId;
		symbol.deactivate();
		if (id == "") id = "_empty";
		_pool.release(id, symbol);
	}

	public function setCellSize(w:Float, h:Float):Void {
		_cellW = w;
		_cellH = h;
	}

	public function destroy():Void {
		if (_destroyed) return;
		_destroyed = true;
		_pool.destroy();
	}
}
