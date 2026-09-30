package reels.spine;

import reels.spine.SpineTypes.SpineSymbolSource;

/** Builds ISpineInstance from a SpineSymbolSource. */
interface ISpineFactory {
	function create(source:SpineSymbolSource):ISpineInstance;
}
