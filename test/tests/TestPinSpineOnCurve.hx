package tests;

import reels.ReelSetBuilder;
import reels.clock.FakeClock;
import reels.config.SpeedPresets;
import reels.spine.MockSpineFactory;
import reels.spine.SpineReelSymbol;
import reels.symbols.HeadlessSymbol;
import utest.Assert;
import utest.Test;

/**
 * Sticky pin overlay + Spine affine fit under curveMode('symbol').
 */
class TestPinSpineOnCurve extends Test {
	function build(clock:FakeClock) {
		var factory = new MockSpineFactory();
		return new ReelSetBuilder()
			.reels(1)
			.visibleCells(3)
			.symbolSize(80, 80)
			.curve(0.55)
			.clock(clock)
			.speed("normal", SpeedPresets.NORMAL)
			.symbols(function(r) {
				r.register("WILD", function() {
					return new SpineReelSymbol({
						factory: factory,
						spineMap: ["WILD" => {skeleton: "w", atlas: "w"}]
					});
				});
				r.register("a", function() return new HeadlessSymbol());
			})
			.weights(["WILD" => 1., "a" => 1.])
			.initialFrame([{visible: ["a", "a", "a"]}])
			.build();
	}

	public function testSpinPinOverlayIsSpineAndScaled() {
		var clock = new FakeClock();
		var set = build(clock);
		set.pin(0, 0, "WILD", {turns: "permanent"});
		set.spin();
		clock.advance(32);

		Assert.isTrue(set.viewport.unmasked.numChildren >= 1, "pin overlay on unmasked");
		var reel = set.getReel(0);
		Assert.notNull(reel.curve);
		var probe = new SpineReelSymbol({
			factory: new MockSpineFactory(),
			spineMap: ["WILD" => {skeleton: "w", atlas: "w"}]
		});
		probe.resize(80, 80);
		probe.activate("WILD");
		probe.applyCellQuad(reel.curve.quadFor(0));
		Assert.isTrue(probe.curveFitScale != 1);
		probe.destroy();

		set.slamStop();
		clock.advance(2000);
		set.destroy();
	}

	public function testMovePinFlightUsesUnmasked() {
		var clock = new FakeClock();
		var set = build(clock);
		set.pin(0, 0, "WILD", {turns: "permanent"});
		var done = false;
		set.movePin(
			{reel: 0, cell: 0},
			{reel: 0, cell: 2},
			{duration: 200, backfill: "a"},
			function() done = true
		);
		clock.advance(16);
		Assert.isTrue(set.viewport.unmasked.numChildren >= 1);
		clock.advance(300);
		Assert.isTrue(done);
		Assert.equals("WILD", set.getReel(0).getVisibleIds()[2]);
		set.destroy();
	}
}
