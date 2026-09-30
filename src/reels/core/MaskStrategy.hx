package reels.core;

import openfl.display.Shape;

/**
 * Strategy for building the viewport clip mask.
 * Pass a custom implementation to {@link reels.ReelSetBuilder.maskStrategy}.
 */
interface MaskStrategy {
	var version(get, never):Int;
	/** Build (or rebuild) the mask shape. */
	function build(ctx:MaskContext):Shape;
	/** Update an existing mask shape when the viewport resizes. */
	function update(shape:Shape, ctx:MaskContext):Void;
}
