package reels.frame;

/**
 * Per-reel target for `setResult` / `initialFrame`.
 */
typedef ColumnTarget = {
	visible:Array<String>,
	?bufferStart:Array<Null<String>>,
	?bufferEnd:Array<Null<String>>
};
