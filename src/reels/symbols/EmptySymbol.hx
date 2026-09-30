package reels.symbols;

/**
 * A {@link ReelSymbol} that renders nothing and never animates.
 *
 * Register it for an id that needs to occupy a grid slot without producing
 * any visual — the blank rest state of a {@link reels.board.HoldAndWinBoard}
 * cell. {@link reels.board.HoldAndWinBuilder} / {@link reels.board.BoardGrid}
 * auto-register one under their `emptyId` so callers never have to.
 */
class EmptySymbol extends ReelSymbol {
	public function new() {
		super(new HeadlessView());
	}

	override function onActivate(_symbolId:String):Void {}

	override function onDeactivate():Void {}

	override public function playWin(onComplete:() -> Void):Void {
		onComplete();
	}

	override public function stopAnimation():Void {}

	override public function resize(_width:Float, _height:Float):Void {}
}
