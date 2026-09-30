package tests;

import reels.events.ReelEvents;
import reels.frame.ColumnTarget;
import reels.pins.CellPin;
import reels.pins.PinExpireReason;
import reels.pins.PinMigration;
import reels.testing.TestHarness;
import utest.Assert;
import utest.Test;

class TestPins extends Test {
	static function makeHarness() {
		return TestHarness.createTestReelSet({
			reels: 5,
			visibleCells: 3,
			symbolIds: ["a", "b", "c", "wild", "coin"],
			symbolWidth: 100,
			symbolHeight: 100
		});
	}

	static function abcGrid():Array<ColumnTarget> {
		return [
			for (_ in 0...5) ({visible: ["a", "b", "c"]}:ColumnTarget)
		];
	}

	public function testNoPinBaseline() {
		var h = makeHarness();
		h.spinAndLand(abcGrid(), function(_) {});
		Assert.same(["a", "b", "c"], h.reelSet.getReel(2).getVisibleIds());
		Assert.equals(0, [for (k in h.reelSet.pins.keys()) k].length);
		h.destroy();
	}

	public function testPinForcesSetResultCell() {
		var h = makeHarness();
		h.reelSet.pin(2, 1, "wild", {turns: "permanent"});
		h.spinAndLand(abcGrid(), function(_) {});
		Assert.equals("wild", h.reelSet.getReel(2).getVisibleIds()[1]);
		Assert.equals("a", h.reelSet.getReel(2).getVisibleIds()[0]);
		Assert.equals("c", h.reelSet.getReel(2).getVisibleIds()[2]);
		h.destroy();
	}

	public function testSetResultDoesNotMutateInput() {
		var h = makeHarness();
		h.reelSet.pin(0, 0, "wild");
		var target = abcGrid();
		var snapshot = target[0].visible.copy();
		h.spinAndLand(target, function(_) {});
		Assert.same(snapshot, target[0].visible);
		h.destroy();
	}

	public function testIdlePinAppliesVisually() {
		var h = makeHarness();
		h.reelSet.pin(1, 0, "wild", {turns: 2});
		Assert.equals("wild", h.reelSet.getReel(1).getVisibleIds()[0]);
		Assert.equals("wild", h.reelSet.getPin(1, 0).symbolId);
		h.destroy();
	}

	public function testTurnsCountdownExpires() {
		var h = makeHarness();
		var expired:Array<{pin:CellPin, reason:String}> = [];
		h.reelSet.events.on(ReelEvents.PIN_EXPIRED, function(args) {
			expired.push({pin: args[0], reason: Std.string(args[1])});
		});
		h.reelSet.pin(0, 0, "wild", {turns: 2});
		h.spinAndLand(abcGrid(), function(_) {});
		Assert.equals(1, h.reelSet.getPin(0, 0).turns);
		Assert.equals(0, expired.length);

		h.spinAndLand(abcGrid(), function(_) {});
		Assert.isNull(h.reelSet.getPin(0, 0));
		Assert.equals(1, expired.length);
		Assert.equals(PinExpireReason.Turns, expired[0].reason);
		h.destroy();
	}

	public function testEvalClearedOnNextSpinStart() {
		var h = makeHarness();
		var reasons:Array<String> = [];
		h.reelSet.events.on(ReelEvents.PIN_EXPIRED, function(args) {
			reasons.push(Std.string(args[1]));
		});
		// Eval is for post-landing placement (expanding wild reveal).
		h.spinAndLand(abcGrid(), function(_) {});
		h.reelSet.pin(2, 1, "wild", {turns: "eval"});
		Assert.notNull(h.reelSet.getPin(2, 1));
		Assert.equals("wild", h.reelSet.getReel(2).getVisibleIds()[1]);

		h.spinAndLand(abcGrid(), function(_) {});
		Assert.isNull(h.reelSet.getPin(2, 1));
		Assert.isTrue(reasons.indexOf(PinExpireReason.Eval) >= 0);
		Assert.equals("b", h.reelSet.getReel(2).getVisibleIds()[1]);
		h.destroy();
	}

	public function testPermanentSurvivesSpins() {
		var h = makeHarness();
		h.reelSet.pin(3, 2, "coin", {turns: "permanent", payload: {value: 50}});
		h.spinAndLand(abcGrid(), function(_) {});
		h.spinAndLand(abcGrid(), function(_) {});
		var pin = h.reelSet.getPin(3, 2);
		Assert.notNull(pin);
		Assert.equals("permanent", pin.turns);
		Assert.equals(50, Reflect.field(pin.payload, "value"));
		h.destroy();
	}

	public function testUnpinExplicit() {
		var h = makeHarness();
		var reason:String = null;
		h.reelSet.events.on(ReelEvents.PIN_EXPIRED, function(args) {
			reason = Std.string(args[1]);
		});
		h.reelSet.pin(1, 1, "wild");
		h.reelSet.unpin(1, 1);
		Assert.isNull(h.reelSet.getPin(1, 1));
		Assert.equals(PinExpireReason.Explicit, reason);
		h.reelSet.unpin(1, 1); // no-op
		h.destroy();
	}

	public function testReplaceSilentNoExpired() {
		var h = makeHarness();
		var expired = 0;
		h.reelSet.events.on(ReelEvents.PIN_EXPIRED, function(_) expired++);
		h.reelSet.pin(0, 0, "wild", {turns: 3});
		h.reelSet.pin(0, 0, "coin", {turns: 5});
		Assert.equals(0, expired);
		Assert.equals("coin", h.reelSet.getPin(0, 0).symbolId);
		Assert.equals(5, h.reelSet.getPin(0, 0).turns);
		h.destroy();
	}

	public function testPinBoundsThrow() {
		var h = makeHarness();
		Assert.raises(function() h.reelSet.pin(-1, 0, "wild"));
		Assert.raises(function() h.reelSet.pin(0, 9, "wild"));
		h.destroy();
	}

	public function testOverlayCreatedMidSpin() {
		var h = makeHarness();
		var created = 0;
		h.reelSet.events.on(ReelEvents.PIN_OVERLAY_CREATED, function(_) created++);
		h.reelSet.pin(1, 1, "wild", {turns: "permanent"});
		Assert.equals(0, created); // idle — no overlay

		h.reelSet.spin(function(_) {});
		Assert.equals(1, created);
		Assert.isTrue(h.reelSet.pins.exists(CellPin.pinKey(1, 1)));

		h.reelSet.setResult(abcGrid());
		h.reelSet.slamStop();
		h.advance(200);
		h.destroy();
	}

	/**
	 * Sticky overlays sit on unmasked (no clip). They must stay at restHostMain
	 * during StopPhase bounce — following host overshoot leaks bottom-cell pins
	 * past the drum edge (sample: movePin → SPIN with bounce 56).
	 */
	public function testPinOverlayIgnoresHostBounce() {
		var h = makeHarness();
		var overlay:reels.symbols.ReelSymbol = null;
		h.reelSet.events.on(ReelEvents.PIN_OVERLAY_CREATED, function(args) {
			overlay = args[1];
		});
		// Bottom cell — the leak case.
		h.reelSet.pin(2, 2, "wild", {turns: "permanent"});
		h.reelSet.spin(function(_) {});
		Assert.notNull(overlay);

		var yRest = overlay.y;
		Assert.floatEquals(2 * 100, yRest, 0.01);

		var reel = h.reelSet.getReel(2);
		reel.setHostMain(56);
		h.advance(16);
		// Controller may overwrite host during StartPhase — overlay must still
		// stay at the resting cell, not track bounce/tug.
		Assert.floatEquals(yRest, overlay.y, 0.01);

		reel.setHostMain(reel.restHostMain);
		h.reelSet.setResult(abcGrid());
		h.reelSet.slamStop();
		h.advance(200);
		h.destroy();
	}

	public function testPinMidSpinCreatesOverlay() {
		var h = makeHarness();
		var created = 0;
		h.reelSet.events.on(ReelEvents.PIN_OVERLAY_CREATED, function(_) created++);
		h.reelSet.spin(function(_) {});
		h.reelSet.pin(2, 0, "wild", {turns: 1});
		Assert.equals(1, created);
		h.reelSet.setResult(abcGrid());
		h.reelSet.slamStop();
		h.advance(200);
		h.destroy();
	}

	public function testOriginMigrationRestoresOnGrow() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			multiways: {minCells: 2, maxCells: 5, reelExtent: 500},
			symbolIds: ["a", "wild"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		// Start at max 5 cells; pin origin at cell 3
		h.reelSet.pin(0, 3, "wild", {turns: "permanent", originCell: 3, migration: PinMigration.Origin});
		Assert.equals(3, h.reelSet.getPin(0, 3).cell);

		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([3]); // clamp to cell 2
		Assert.isNull(h.reelSet.getPin(0, 3));
		Assert.equals(2, h.reelSet.getPin(0, 2).cell);
		Assert.equals(3, h.reelSet.getPin(0, 2).originCell);

		h.reelSet.setResult([{visible: ["a", "a", "a"]}]);
		h.advance(5000);
		h.reelSet.slamStop();
		h.advance(100);

		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([5]); // restore to origin 3
		Assert.equals(3, h.reelSet.getPin(0, 3).cell);
		h.reelSet.setResult([{visible: ["a", "a", "a", "a", "a"]}]);
		h.reelSet.slamStop();
		h.advance(100);
		h.destroy();
	}

	public function testFrozenMigrationUpdatesOrigin() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			multiways: {minCells: 2, maxCells: 5, reelExtent: 500},
			symbolIds: ["a", "wild"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		h.reelSet.pin(0, 4, "wild", {
			turns: "permanent",
			originCell: 4,
			migration: PinMigration.Frozen
		});
		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([3]);
		var pin = h.reelSet.getPin(0, 2);
		Assert.notNull(pin);
		Assert.equals(2, pin.cell);
		Assert.equals(2, pin.originCell); // frozen updated

		h.reelSet.setResult([{visible: ["a", "a", "a"]}]);
		h.reelSet.slamStop();
		h.advance(100);

		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([5]);
		// does NOT restore to 4
		Assert.notNull(h.reelSet.getPin(0, 2));
		Assert.isNull(h.reelSet.getPin(0, 4));
		h.reelSet.setResult([{visible: ["a", "a", "a", "a", "a"]}]);
		h.reelSet.slamStop();
		h.advance(100);
		h.destroy();
	}

	public function testMigrationCollisionExpiresLowerPin() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			multiways: {minCells: 2, maxCells: 4, reelExtent: 400},
			symbolIds: ["a", "wild", "coin"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		var collisions = 0;
		h.reelSet.events.on(ReelEvents.PIN_EXPIRED, function(args) {
			if (Std.string(args[1]) == PinExpireReason.Collision) collisions++;
		});
		// Two pins that both clamp to cell 1 when shrinking to 2 cells
		h.reelSet.pin(0, 2, "wild", {turns: "permanent", originCell: 2});
		h.reelSet.pin(0, 3, "coin", {turns: "permanent", originCell: 3});
		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([2]);
		// Topmost (cell 2 → 1) wins; lower (cell 3 → 1) collides
		Assert.notNull(h.reelSet.getPin(0, 1));
		Assert.equals(1, collisions);
		h.reelSet.setResult([{visible: ["a", "a"]}]);
		h.reelSet.slamStop();
		h.advance(100);
		h.destroy();
	}

	public function testPinMigratedEvent() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			multiways: {minCells: 2, maxCells: 4, reelExtent: 400},
			symbolIds: ["a", "wild"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		var migrated = 0;
		h.reelSet.events.on(ReelEvents.PIN_MIGRATED, function(_) migrated++);
		h.reelSet.pin(0, 3, "wild", {turns: "permanent"});
		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([2]);
		Assert.equals(1, migrated);
		h.reelSet.setResult([{visible: ["a", "a"]}]);
		h.reelSet.slamStop();
		h.advance(100);
		h.destroy();
	}

	public function testPinSurvivesLandVisuallyWithCurve() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "wild"],
			symbolWidth: 100,
			symbolHeight: 100,
			curve: 0.7
		});
		h.reelSet.pin(1, 1, "wild", {turns: 3});
		Assert.equals("wild", h.reelSet.getReel(1).getVisibleIds()[1]);

		h.spinAndLand([
			{visible: ["a", "b", "a"]},
			{visible: ["a", "b", "a"]},
			{visible: ["a", "b", "a"]}
		], function(_) {});

		// After land, overlay is gone — strip must still show the pin.
		Assert.equals("wild", h.reelSet.getReel(1).getVisibleIds()[1]);
		Assert.notNull(h.reelSet.getPin(1, 1));
		Assert.equals(2, h.reelSet.getPin(1, 1).turns);
		h.destroy();
	}

	public function testMultiWaysAcquireUsesReelCellSize() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			multiways: {minCells: 2, maxCells: 4, reelExtent: 400},
			symbolIds: ["a", "b", "wild"],
			symbolWidth: 100,
			symbolHeight: 100,
			curve: 0.7
		});
		Assert.floatEquals(100, h.reelSet.getReel(0).symbolHeight, 1e-6);

		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([2]);
		h.reelSet.setResult([{visible: ["a", "b"]}]);
		h.reelSet.slamStop();
		h.advance(100);

		Assert.equals(2, h.reelSet.getReel(0).visibleCells);
		Assert.floatEquals(200, h.reelSet.getReel(0).symbolHeight, 1e-6);
		// After land+pin refresh, every visible symbol must match reel cell size
		// (not factory maxCells size) — otherwise curve facets leave gaps.
		h.reelSet.pin(0, 0, "wild", {turns: 2});
		for (c in 0...2) {
			var sym = h.reelSet.getReel(0).getVisibleSymbol(c);
			Assert.floatEquals(200, sym.cellHeight, 1e-6);
			Assert.floatEquals(100, sym.cellWidth, 1e-6);
		}
		Assert.equals("wild", h.reelSet.getReel(0).getVisibleIds()[0]);
		h.destroy();
	}

	public function testStickyCenterSurvivesMultiWaysShrink() {
		var h = TestHarness.createTestReelSet({
			reels: 5,
			multiways: {minCells: 2, maxCells: 4, reelExtent: 400},
			symbolIds: ["a", "b", "wild"],
			symbolWidth: 100,
			symbolHeight: 100
		});
		// At maxCells=4, true middle is cell 1 — not int(4/2)=2 (bottom after shrink).
		var midReel = 2;
		var midAtMax = Std.int((4 - 1) / 2);
		Assert.equals(1, midAtMax);
		h.reelSet.pin(midReel, midAtMax, "wild", {
			turns: "permanent",
			originCell: midAtMax,
			migration: PinMigration.Origin
		});

		h.reelSet.spin(function(_) {});
		h.reelSet.setShape([3, 3, 3, 3, 3]);
		var pin = h.reelSet.getPin(midReel, 1);
		Assert.notNull(pin);
		Assert.equals(1, pin.cell);
		Assert.isNull(h.reelSet.getPin(midReel, 2));

		h.reelSet.setResult([
			for (_ in 0...5) ({visible: ["a", "b", "a"]}:ColumnTarget)
		]);
		h.reelSet.slamStop();
		h.advance(200);
		Assert.equals("wild", h.reelSet.getReel(midReel).getVisibleIds()[1]);

		// Post-reshape cell size + visibility (HeadlessSymbol has no DO parenting).
		var reel = h.reelSet.getReel(midReel);
		var expectedH = 400 / 3;
		Assert.equals(3, reel.visibleCells);
		for (c in 0...reel.visibleCells) {
			var s = reel.getVisibleSymbol(c);
			Assert.floatEquals(1, s.alpha, 1e-6);
			Assert.isTrue(s.visible);
			Assert.floatEquals(expectedH, s.cellHeight, 1e-6);
		}
		h.destroy();
	}

	/** Overlay teardown must not leave orphan strip DOs (MultiWays sticky holes). */
	public function testMultiWaysStickyLandKeepsFullStrip() {
		var atlas = new Map<String, openfl.display.BitmapData>();
		for (id in ["a", "b", "wild"]) {
			atlas.set(id, new openfl.display.BitmapData(100, 100, true, 0xFF00FF00));
		}
		var clock = new reels.clock.FakeClock();
		var rs = new reels.ReelSetBuilder()
			.reels(5)
			.symbolSize(100, 100)
			.clock(clock)
			.speed("normal", reels.config.SpeedPresets.NORMAL)
			.multiways({minCells: 2, maxCells: 4, reelExtent: 400})
			.adjustDuration(300)
			.symbols(function(r) {
				for (id in ["a", "b", "wild"]) {
					r.register(id, function() return new reels.symbols.BitmapReelSymbol({bitmapDataMap: atlas}));
				}
			})
			.rng(function() return 0.5)
			.build();

		rs.pin(2, 1, "wild", {turns: 3, originCell: 1, migration: PinMigration.Origin});
		rs.spin(function(_) {});
		rs.setShape([4, 2, 3, 4, 2]);
		rs.setResult([
			{visible: ["a", "b", "a", "b"]},
			{visible: ["a", "b"]},
			{visible: ["a", "b", "a"]},
			{visible: ["a", "b", "a", "b"]},
			{visible: ["a", "b"]}
		]);
		for (_ in 0...100) clock.advance(50);

		for (r in 0...5) {
			var reel = rs.getReel(r);
			var expectedH = 400 / reel.visibleCells;
			Assert.isTrue(reel.visibleCells >= 2);
			for (c in 0...reel.visibleCells) {
				var s = reel.getVisibleSymbol(c);
				Assert.isTrue(
					s.displayObject != null && s.displayObject.parent == reel.host,
					'reel $r cell $c orphaned'
				);
				Assert.floatEquals(1, s.alpha, 1e-6);
				Assert.floatEquals(expectedH, s.cellHeight, 0.5);
			}
		}
		Assert.equals("wild", rs.getReel(2).getVisibleIds()[1]);
		rs.destroy();
	}

	public function testOverlayRecycleDoesNotOffsetStripCross() {
		var atlas = new Map<String, openfl.display.BitmapData>();
		for (id in ["a", "wild"]) {
			atlas.set(id, new openfl.display.BitmapData(100, 100, true, 0xFF00FF00));
		}
		var clock = new reels.clock.FakeClock();
		var rs = new reels.ReelSetBuilder()
			.reels(3)
			.symbolSize(100, 100)
			.clock(clock)
			.speed("normal", reels.config.SpeedPresets.NORMAL)
			.multiways({minCells: 2, maxCells: 4, reelExtent: 400})
			.symbols(function(r) {
				for (id in ["a", "wild"]) {
					r.register(id, function() return new reels.symbols.BitmapReelSymbol({bitmapDataMap: atlas}));
				}
			})
			.rng(function() return 0.5)
			.build();

		rs.pin(1, 1, "wild", {turns: "permanent", originCell: 1});
		rs.spin(function(_) {});
		rs.setShape([4, 2, 4]);
		rs.setResult([
			{visible: ["a", "a", "a", "a"]},
			{visible: ["a", "a"]},
			{visible: ["a", "a", "a", "a"]}
		]);
		rs.slamStop();
		for (_ in 0...20) clock.advance(50);

		var reel = rs.getReel(1);
		Assert.equals(2, reel.visibleCells);
		for (c in 0...2) {
			var s = reel.getVisibleSymbol(c);
			Assert.floatEquals(0, s.x, 1e-6);
			Assert.isTrue(s.displayObject != null && s.displayObject.parent == reel.host);
			Assert.floatEquals(reel.symbolHeight, s.cellHeight, 1e-6);
		}
		rs.destroy();
	}

	/** Sticky must survive Moment B: refill grid is force-pinned like setResult. */
	public function testPinForcesRefillCell() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b", "c", "wild"],
			tumble: true,
			bufferSymbols: 1,
			initialFrame: [
				{visible: ["a", "wild", "c"]},
				{visible: ["c", "c", "c"]}
			]
		});
		h.reelSet.pin(0, 1, "wild", {turns: "permanent"});

		var input = [
			{visible: ["b", "a", "a"]},
			{visible: ["c", "c", "c"]}
		];
		var snapshot = input[0].visible.copy();
		var done = false;
		h.reelSet.refill({
			winners: [{reel: 0, cell: 0}, {reel: 0, cell: 2}],
			grid: input,
			mode: "combined"
		}, function(_) {
			done = true;
		});
		var guard = 0;
		while (!done && guard < 100) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "refill should complete");
		Assert.same(snapshot, input[0].visible, "refill must not mutate caller grid");
		Assert.equals("wild", h.reelSet.getReel(0).getVisibleIds()[1]);
		Assert.equals("b", h.reelSet.getReel(0).getVisibleIds()[0]);
		Assert.equals("a", h.reelSet.getReel(0).getVisibleIds()[2]);
		h.destroy();
	}

	/** Destroy must not fade a pinned sticky — otherwise WILD vanishes mid-cascade. */
	public function testDestroySkipsPinnedCells() {
		var h = TestHarness.createTestReelSet({
			reels: 2,
			visibleCells: 3,
			symbolIds: ["a", "b", "wild"],
			tumble: true,
			initialFrame: [
				{visible: ["a", "wild", "b"]},
				{visible: ["a", "a", "a"]}
			]
		});
		h.reelSet.pin(0, 1, "wild", {turns: "permanent"});
		var pinSym = h.reelSet.getReel(0).getVisibleSymbol(1);
		Assert.floatEquals(1, pinSym.alpha, 1e-6);

		var done = false;
		h.reelSet.destroySymbols([
			{reel: 0, cell: 0},
			{reel: 0, cell: 1},
			{reel: 0, cell: 2}
		], {durationMs: 0, staggerMs: 0}, function() {
			done = true;
		});
		var guard = 0;
		while (!done && guard < 50) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done);
		Assert.floatEquals(1, pinSym.alpha, 1e-6);
		Assert.equals("wild", h.reelSet.getReel(0).getVisibleIds()[1]);
		Assert.floatEquals(0, h.reelSet.getReel(0).getVisibleSymbol(0).alpha, 1e-6);
		Assert.floatEquals(0, h.reelSet.getReel(0).getVisibleSymbol(2).alpha, 1e-6);
		h.destroy();
	}

	/**
	 * Full sticky+cascade regression: destroy middle row (incl. sticky) then
	 * refill — strip must still show WILD, no orphan overlay after land.
	 */
	public function testStickySurvivesDestroyAndRefill() {
		var h = TestHarness.createTestReelSet({
			reels: 3,
			visibleCells: 3,
			symbolIds: ["a", "b", "wild"],
			tumble: true,
			bufferSymbols: 1,
			initialFrame: [
				{visible: ["a", "a", "a"]},
				{visible: ["a", "wild", "a"]},
				{visible: ["a", "a", "a"]}
			]
		});
		h.reelSet.pin(1, 1, "wild", {turns: "permanent"});

		var winners = [
			{reel: 0, cell: 1},
			{reel: 1, cell: 1},
			{reel: 2, cell: 1}
		];
		var next = [
			{visible: ["b", "a", "a"]},
			{visible: ["b", "a", "a"]},
			{visible: ["b", "a", "a"]}
		];

		var destroyed = false;
		h.reelSet.destroySymbols(winners, {durationMs: 0, staggerMs: 0}, function() {
			destroyed = true;
		});
		var guard = 0;
		while (!destroyed && guard < 50) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(destroyed);
		Assert.equals("wild", h.reelSet.getReel(1).getVisibleIds()[1]);
		Assert.floatEquals(1, h.reelSet.getReel(1).getVisibleSymbol(1).alpha, 1e-6);

		var refilled = false;
		h.reelSet.refill({winners: winners, grid: next, mode: "combined"}, function(_) {
			refilled = true;
		});
		guard = 0;
		while (!refilled && guard < 100) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(refilled);
		Assert.equals("wild", h.reelSet.getReel(1).getVisibleIds()[1]);
		Assert.floatEquals(1, h.reelSet.getReel(1).getVisibleSymbol(1).alpha, 1e-6);
		Assert.notNull(h.reelSet.getPin(1, 1));
		h.destroy();
	}

	public function testMovePinIdleWalksAndBackfills() {
		var h = makeHarness();
		h.reelSet.pin(1, 0, "wild", {turns: "permanent"});
		Assert.equals("wild", h.reelSet.getReel(1).getVisibleIds()[0]);

		var moved = false;
		var fromCell = -1;
		h.reelSet.events.on(ReelEvents.PIN_MOVED, function(args) {
			moved = true;
			fromCell = args[1].cell;
		});

		var done = false;
		h.reelSet.movePin(
			{reel: 1, cell: 0},
			{reel: 1, cell: 2},
			{duration: 0, backfill: "a"},
			function() done = true
		);
		Assert.isTrue(done);
		Assert.isTrue(moved);
		Assert.equals(0, fromCell);
		Assert.isNull(h.reelSet.getPin(1, 0));
		Assert.notNull(h.reelSet.getPin(1, 2));
		Assert.equals("wild", h.reelSet.getReel(1).getVisibleIds()[2]);
		Assert.equals("a", h.reelSet.getReel(1).getVisibleIds()[0]);
		h.destroy();
	}

	public function testMovePinThrowsWhileSpinning() {
		var h = makeHarness();
		h.reelSet.pin(0, 0, "wild", {turns: "permanent"});
		h.reelSet.spin(function(_) {});
		Assert.raises(function() {
			h.reelSet.movePin({reel: 0, cell: 0}, {reel: 0, cell: 1}, {duration: 0});
		});
		h.reelSet.slamStop();
		h.advance(100);
		h.destroy();
	}

	public function testMovePinCollisionThrows() {
		var h = makeHarness();
		h.reelSet.pin(0, 0, "wild", {turns: "permanent"});
		h.reelSet.pin(0, 2, "coin", {turns: "permanent"});
		Assert.raises(function() {
			h.reelSet.movePin({reel: 0, cell: 0}, {reel: 0, cell: 2}, {duration: 0});
		});
		h.destroy();
	}

	public function testMovePinAnimatedCompletes() {
		var h = makeHarness();
		h.reelSet.pin(2, 1, "wild", {turns: "permanent"});
		var done = false;
		var created = false;
		h.reelSet.movePin(
			{reel: 2, cell: 1},
			{reel: 2, cell: 0},
			{
				duration: 80,
				backfill: "b",
				onFlightCreated: function(_) created = true
			},
			function() done = true
		);
		Assert.isTrue(created);
		Assert.isFalse(done);
		var guard = 0;
		while (!done && guard < 40) {
			h.clock.advance(16);
			guard++;
		}
		Assert.isTrue(done, "flight should complete");
		Assert.equals("wild", h.reelSet.getReel(2).getVisibleIds()[0]);
		Assert.equals("b", h.reelSet.getReel(2).getVisibleIds()[1]);
		h.destroy();
	}

	public function testPinMigrationDurationAlias() {
		var h = TestHarness.createTestReelSet({
			reels: 1,
			multiways: {minCells: 2, maxCells: 4, reelExtent: 400},
			symbolIds: ["a", "wild"],
			adjustDurationMs: 0
		});
		// Rebuild with pinMigrationDuration via builder directly.
		h.destroy();

		var clock = new reels.clock.FakeClock();
		var rs = new reels.ReelSetBuilder()
			.reels(1)
			.symbolSize(100, 100)
			.clock(clock)
			.speed("normal", reels.config.SpeedPresets.NORMAL)
			.multiways({minCells: 2, maxCells: 4, reelExtent: 400})
			.pinMigrationDuration(100)
			.symbols(function(r) {
				r.register("a", function() return new reels.symbols.HeadlessSymbol());
				r.register("wild", function() return new reels.symbols.HeadlessSymbol());
			})
			.rng(function() return 0.5)
			.build();

		rs.pin(0, 1, "wild", {turns: "permanent", originCell: 1});
		rs.spin(function(_) {});
		rs.setShape([2]);
		rs.setResult([{visible: ["a", "a"]}]);
		// Adjust hold 100ms — slam after brief wait still lands.
		for (_ in 0...3) clock.advance(50);
		rs.slamStop();
		for (_ in 0...10) clock.advance(50);
		Assert.equals("wild", rs.getReel(0).getVisibleIds()[1]);
		rs.destroy();
	}
}
