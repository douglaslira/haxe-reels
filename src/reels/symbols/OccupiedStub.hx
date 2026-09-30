package reels.symbols;

/**
 * Invisible placeholder for non-anchor cells of a big-symbol block.
 * Not pooled through SymbolFactory — allocated by Reel.
 */
class OccupiedStub extends ReelSymbol {
	public static inline var SENTINEL = "__OCCUPIED__";

	public function new() {
		super(new HeadlessView());
	}

	override function onActivate(_symbolId:String):Void {
		visible = false;
		alpha = 0;
	}

	override function onDeactivate():Void {
		visible = false;
	}

	override public function playWin(onComplete:() -> Void):Void {
		onComplete();
	}

	override public function stopAnimation():Void {}

	override function onResize(_w:Float, _h:Float):Void {}
}
