package reels.cascade;

/**
 * Options for {@link reels.ReelSet.destroySymbols}.
 * `delay` is a flat ms before every cell starts; `staggerMs` adds `i * staggerMs`.
 * `durationMs` defaults to 200 (alpha collapse).
 */
typedef DestroySymbolsOptions = {
	?delay:Float,
	?staggerMs:Float,
	?durationMs:Float
};
