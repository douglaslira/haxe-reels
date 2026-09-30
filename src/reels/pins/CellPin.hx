package reels.pins;

/**
 * Lifetime of a pin:
 * - Int → countdown after each completed spin; removed at 0
 * - `"eval"` → cleared at next spin:start
 * - `"permanent"` → until unpin()
 */
typedef PinTurns = Dynamic;

typedef CellPinOptions = {
	?turns:PinTurns,
	?payload:Dynamic,
	?originCell:Int,
	?migration:PinMigration
};

/**
 * Claim on a grid cell. Forced onto `setResult` and persists per `turns`.
 * Engine may mutate `turns` / `cell` / `originCell` during lifetime / reshape.
 */
class CellPin {
	public var reel:Int;
	public var cell:Int;
	public var symbolId:String;
	public var originCell:Int;
	public var migration:PinMigration;
	public var turns:PinTurns;
	public var payload:Null<Dynamic>;

	public function new(
		reel:Int,
		cell:Int,
		symbolId:String,
		originCell:Int,
		migration:PinMigration,
		turns:PinTurns,
		?payload:Dynamic
	) {
		this.reel = reel;
		this.cell = cell;
		this.symbolId = symbolId;
		this.originCell = originCell;
		this.migration = migration;
		this.turns = turns;
		this.payload = payload;
	}

	public static inline function pinKey(reel:Int, cell:Int):String {
		return '$reel:$cell';
	}

	public static function isEval(turns:PinTurns):Bool {
		return Std.isOfType(turns, String) && Std.string(turns) == "eval";
	}

	public static function isPermanent(turns:PinTurns):Bool {
		return Std.isOfType(turns, String) && Std.string(turns) == "permanent";
	}

	public static function isNumeric(turns:PinTurns):Bool {
		return Std.isOfType(turns, Int) || Std.isOfType(turns, Float);
	}

	public static function parseMigration(raw:Null<PinMigration>):PinMigration {
		if (raw == null) return PinMigration.Origin;
		if (raw == PinMigration.Frozen) return PinMigration.Frozen;
		return PinMigration.Origin;
	}

	public static function parseTurns(raw:Null<PinTurns>):PinTurns {
		if (raw == null) return "permanent";
		if (isEval(raw) || isPermanent(raw)) return Std.string(raw);
		if (isNumeric(raw)) return Std.int(raw);
		throw 'pin(): invalid turns "$raw" (expected number | eval | permanent)';
	}
}
