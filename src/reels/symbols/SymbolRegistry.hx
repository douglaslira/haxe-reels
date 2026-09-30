package reels.symbols;

/**
 * Registers symbol factories by id and creates pooled instances.
 */
class SymbolRegistry {
	var _factories:Map<String, () -> ReelSymbol> = new Map();
	var _meta:Map<String, SymbolMeta> = new Map();
	var _mainAxis:String = "y";

	public function new() {}

	public function bindMainAxis(prop:String):Void {
		_mainAxis = prop;
	}

	/** Register a factory. Preferred for headless / custom symbols. */
	public function register(id:String, factory:() -> ReelSymbol, ?meta:SymbolMeta):Void {
		_factories.set(id, factory);
		if (meta != null) _meta.set(id, meta);
	}

	/**
	 * Register a class constructor. Passes `options` as the sole constructor
	 * argument when non-null; otherwise calls a zero-arg constructor.
	 */
	public function registerClass(
		id:String,
		ctor:Class<ReelSymbol>,
		?options:Dynamic,
		?meta:SymbolMeta
	):Void {
		_factories.set(id, function() {
			var symbol:ReelSymbol = options != null
				? Type.createInstance(ctor, [options])
				: Type.createInstance(ctor, []);
			return symbol;
		});
		if (meta != null) _meta.set(id, meta);
	}

	/** Declare / override size + unmask after register. */
	public function setMeta(id:String, meta:SymbolMeta):Void {
		_meta.set(id, meta);
	}

	public function getSize(id:String):SymbolSize {
		var m = _meta.get(id);
		if (m == null || m.size == null) return BigSymbolCoord.unit();
		return m.size;
	}

	public function getUnmask(id:String):Bool {
		var m = _meta.get(id);
		return m != null && m.unmask == true;
	}

	public function hasBigSymbols():Bool {
		for (id in _factories.keys()) {
			if (BigSymbolCoord.isBig(getSize(id))) return true;
		}
		return false;
	}

	public function hasUnmaskedSymbols():Bool {
		for (id in _factories.keys()) {
			if (getUnmask(id)) return true;
		}
		return false;
	}

	public function has(id:String):Bool {
		return _factories.exists(id);
	}

	public function ids():Array<String> {
		return [for (k in _factories.keys()) k];
	}

	public function create(id:String):ReelSymbol {
		var factory = _factories.get(id);
		if (factory == null) throw 'Symbol not registered: $id';
		var symbol = factory();
		symbol.bindMainAxis(_mainAxis);
		return symbol;
	}
}
