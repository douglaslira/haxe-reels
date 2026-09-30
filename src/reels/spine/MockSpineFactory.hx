package reels.spine;

import reels.spine.SpineTypes.SpineSymbolSource;

/**
 * Fake Spine factory for utest + sample without a Spine lib.
 */
class MockSpineFactory implements ISpineFactory {
	var _anims:Array<String>;

	public function new(?animationNames:Array<String>) {
		_anims = animationNames != null
			? animationNames.copy()
			: ["idle", "landing", "win", "disintegration", "blur"];
	}

	public function create(source:SpineSymbolSource):ISpineInstance {
		return new MockSpineInstance(_anims, source);
	}
}
