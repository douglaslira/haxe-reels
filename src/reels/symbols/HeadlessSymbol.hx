package reels.symbols;

/** Headless symbol for FakeClock tests — no textures. */
class HeadlessSymbol extends ReelSymbol {
	public function new() {
		super(new HeadlessView());
	}

	override function onActivate(symbolId:String):Void {
		// identity only; no art
	}
}
