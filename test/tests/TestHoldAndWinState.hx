package tests;

import reels.board.HoldAndWinState;
import reels.board.HwCell;
import reels.board.HwCoin;
import reels.board.HwEffect;
import reels.board.HwPhase;
import reels.board.HwTypes;
import utest.Assert;
import utest.Test;

/**
 * Pure HoldAndWinState reducer — parity with pixi HoldAndWinState.test.ts.
 */
class TestHoldAndWinState extends Test {
	static final CELLS:Array<HwCell> = [
		{reel: 0, cell: 0},
		{reel: 1, cell: 0},
		{reel: 0, cell: 1},
		{reel: 1, cell: 1}
	];

	function make(respins:Int = 3):HoldAndWinState {
		return new HoldAndWinState(CELLS, respins);
	}

	function types(fx:Array<HwEffect>):Array<String> {
		return [for (e in fx) e.type];
	}

	function coin(reel:Int, cell:Int, id:String = "coin", ?data:Dynamic):HwCoin {
		return {cell: {reel: reel, cell: cell}, id: id, data: data};
	}

	public function testStartsIdleAndEmpty() {
		var s = make();
		Assert.equals(Idle, s.phase);
		Assert.equals(0, s.respinsLeft);
		Assert.equals(4, s.capacity);
		Assert.isFalse(s.isFull);
		Assert.equals(0, s.lockedCoins().length);
		Assert.equals(4, s.freeCells().length);
	}

	public function testEnterSeedsLedger() {
		var s = make(3);
		var fx = s.enter([coin(0, 0, "coin", {value: 5})]);
		Assert.same(["respins:changed", "feature:enter"], types(fx));
		Assert.equals(3, fx[0].payload.value);
		Assert.equals("seed", fx[0].payload.reason);
		Assert.equals(Active, s.phase);
		Assert.equals(3, s.respinsLeft);
		Assert.equals(1, s.lockedCoins().length);
		Assert.equals(3, s.freeCells().length);
		Assert.isTrue(s.isLocked({reel: 0, cell: 0}));
	}

	public function testEnterThrowsWhileActive() {
		var s = make();
		s.enter([]);
		Assert.raises(function() s.enter([]));
	}

	public function testEnterThrowsDuplicateSeed() {
		var s = make();
		Assert.raises(function() {
			s.enter([coin(0, 0), coin(0, 0)]);
		});
	}

	public function testEnterThrowsOutOfGrid() {
		var s = make();
		Assert.raises(function() {
			s.enter([coin(9, 9)]);
		});
	}

	public function testStoredCellIsCopyDataMutable() {
		var s = make();
		var input:{reel:Int, cell:Int} = {reel: 0, cell: 0};
		s.enter([{cell: input, id: "coin", data: {value: 5}}]);
		input.reel = 5;
		var stored = s.lockedCoins()[0];
		Assert.equals(0, stored.cell.reel);
		Assert.equals(0, stored.cell.cell);
		stored.data.value = 50;
		Assert.equals(50, s.lockedCoins()[0].data.value);
	}

	public function testBeginWaveFromActive() {
		var s = make();
		s.enter([coin(0, 0)]);
		var w = s.beginWave([coin(1, 0)]);
		Assert.equals(1, w.round);
		Assert.equals(3, w.spinning.length);
		Assert.isTrue(w.hitByKey.exists("1,0"));
		Assert.equals(Spinning, s.phase);
	}

	public function testBeginWaveThrowsBeforeEnterAndInFlight() {
		var s = make();
		Assert.raises(function() s.beginWave([]));
		s.enter([]);
		s.beginWave([]);
		Assert.raises(function() s.beginWave([]));
	}

	public function testBeginWaveThrowsOnLockedHit() {
		var s = make();
		s.enter([coin(0, 0)]);
		Assert.raises(function() s.beginWave([coin(0, 0)]));
	}

	public function testBeginWaveThrowsDuplicateHit() {
		var s = make();
		s.enter([]);
		Assert.raises(function() {
			s.beginWave([coin(0, 0), coin(0, 0)]);
		});
	}

	public function testLandHitAndMiss() {
		var s = make();
		s.enter([]);
		s.beginWave([coin(0, 0, "coin", {value: 5})]);
		var hit = s.land({reel: 0, cell: 0}, coin(0, 0, "coin", {value: 5}));
		Assert.same(["cell:landed", "coin:locked"], types(hit));
		Assert.equals(1, hit[1].payload.locked);
		Assert.equals(4, hit[1].payload.capacity);
		var miss = s.land({reel: 1, cell: 0}, null);
		Assert.same(["cell:landed"], types(miss));
		Assert.isNull(miss[0].payload.coin);
	}

	public function testEndWaveHitResetsCounter() {
		var s = make(3);
		s.enter([]);
		s.beginWave([coin(0, 0)]);
		s.land({reel: 0, cell: 0}, coin(0, 0));
		s.land({reel: 1, cell: 0}, null);
		var r = s.endWave();
		Assert.same(["respins:changed", "respin:end"], types(r.effects));
		Assert.equals(3, r.effects[0].payload.value);
		Assert.equals("hit-reset", r.effects[0].payload.reason);
		Assert.equals(Active, s.phase);
	}

	public function testEndWaveMissDecrementsAndEndsAtZero() {
		var s = make(1);
		s.enter([]);
		s.beginWave([]);
		s.land({reel: 0, cell: 0}, null);
		var r = s.endWave();
		Assert.same(["respins:changed", "respin:end", "feature:end"], types(r.effects));
		Assert.equals(0, r.effects[0].payload.value);
		Assert.equals("miss", r.effects[0].payload.reason);
		Assert.equals(Idle, s.phase);
	}

	public function testBoardFullAndFeatureEnd() {
		var s = make(3);
		s.enter([coin(0, 0), coin(1, 0), coin(0, 1)]);
		s.beginWave([coin(1, 1)]);
		s.land({reel: 1, cell: 1}, coin(1, 1));
		var r = s.endWave();
		Assert.same(
			["respins:changed", "respin:end", "board:full", "feature:end"],
			types(r.effects)
		);
		Assert.isTrue(r.effects[3].payload.full);
		Assert.isTrue(s.isFull);
		Assert.equals(Idle, s.phase);
	}

	public function testEnterFullBoardEndsOnEmptyWave() {
		var s = make(3);
		s.enter([coin(0, 0), coin(1, 0), coin(0, 1), coin(1, 1)]);
		Assert.equals(Active, s.phase);
		Assert.isTrue(s.isFull);
		var w = s.beginWave([]);
		Assert.equals(1, w.round);
		Assert.equals(0, w.spinning.length);
		var r = s.endWave();
		Assert.same(
			["respins:changed", "respin:end", "board:full", "feature:end"],
			types(r.effects)
		);
		Assert.isTrue(r.effects[3].payload.full);
		Assert.equals(0, r.landed.length);
		Assert.equals(Idle, s.phase);
	}

	public function testReleaseRemovesLocked() {
		var s = make();
		s.enter([coin(0, 0), coin(1, 0)]);
		var r = s.release([{reel: 0, cell: 0}]);
		Assert.equals(1, r.released.length);
		Assert.same(["coin:released"], types(r.effects));
		Assert.equals(1, r.effects[0].payload.remaining);
		Assert.isFalse(s.isLocked({reel: 0, cell: 0}));
	}

	public function testReleaseIgnoresFreeCell() {
		var s = make();
		s.enter([]);
		var r = s.release([{reel: 0, cell: 0}]);
		Assert.equals(0, r.released.length);
		Assert.equals(0, r.effects.length);
	}

	public function testSwapRewritesLocked() {
		var s = make();
		s.enter([coin(0, 0, "coin", {value: 5})]);
		s.swap({reel: 0, cell: 0}, "major", {value: 100});
		var c = s.coinAt({reel: 0, cell: 0});
		Assert.notNull(c);
		Assert.equals("major", c.id);
		Assert.equals(100, c.data.value);
	}

	public function testSwapKeepsPriorDataWhenNull() {
		var s = make();
		s.enter([coin(0, 0, "coin", {value: 5})]);
		s.swap({reel: 0, cell: 0}, "major", null);
		var c = s.coinAt({reel: 0, cell: 0});
		Assert.equals("major", c.id);
		Assert.equals(5, c.data.value);
	}

	public function testSwapThrowsOnFreeCell() {
		var s = make();
		s.enter([]);
		Assert.raises(function() s.swap({reel: 0, cell: 0}, "major", null));
	}

	public function testResetClearsToIdle() {
		var s = make(3);
		s.enter([coin(0, 0), coin(1, 0)]);
		var fx = s.reset();
		Assert.same(["feature:reset"], types(fx));
		Assert.equals(2, fx[0].payload.clearedCoins);
		Assert.equals(Idle, s.phase);
		Assert.equals(0, s.respinsLeft);
		Assert.equals(0, s.lockedCoins().length);
	}

	public function testReleaseThrowsWhileSpinning() {
		var s = make();
		s.enter([coin(0, 0)]);
		s.beginWave([]);
		Assert.raises(function() s.release([{reel: 0, cell: 0}]));
	}

	public function testSwapThrowsWhileSpinning() {
		var s = make();
		s.enter([coin(0, 0)]);
		s.beginWave([]);
		Assert.raises(function() s.swap({reel: 0, cell: 0}, "major", null));
	}

	public function testAbortWaveRestoresActive() {
		var s = make();
		s.enter([coin(1, 1)]);
		s.beginWave([coin(0, 0)]);
		s.land({reel: 0, cell: 0}, coin(0, 0));
		Assert.equals(Spinning, s.phase);
		s.abortWave();
		Assert.equals(Active, s.phase);
		Assert.isTrue(s.isLocked({reel: 0, cell: 0}));
		s.beginWave([]);
		var r = s.endWave();
		Assert.equals(0, r.landed.length);
	}

	public function testAbortWaveNoopWhenNotSpinning() {
		var s = make();
		s.enter([]);
		Assert.equals(Active, s.phase);
		s.abortWave();
		Assert.equals(Active, s.phase);
	}

	public function testLandNoopOutsideWave() {
		var s = make();
		s.enter([]);
		var fx = s.land({reel: 0, cell: 0}, coin(0, 0));
		Assert.equals(0, fx.length);
		Assert.isFalse(s.isLocked({reel: 0, cell: 0}));
	}

	public function testEndWaveNoopOutsideWave() {
		var s = make(3);
		s.enter([]);
		var r = s.endWave();
		Assert.equals(0, r.effects.length);
		Assert.equals(0, r.landed.length);
		Assert.equals(3, s.respinsLeft);
		Assert.equals(Active, s.phase);
	}

	public function testResetMidWaveNotResurrected() {
		var s = make();
		s.enter([coin(0, 0)]);
		s.beginWave([coin(1, 0)]);
		s.reset();
		Assert.equals(Idle, s.phase);
		Assert.equals(0, s.lockedCoins().length);
		var stray = s.land({reel: 1, cell: 0}, coin(1, 0));
		Assert.equals(0, stray.length);
		Assert.equals(0, s.lockedCoins().length);
		var r = s.endWave();
		Assert.equals(0, r.effects.length);
		Assert.equals(Idle, s.phase);
	}

	public function testCellKeyFormat() {
		Assert.equals("2,3", HwTypes.cellKey({reel: 2, cell: 3}));
	}
}
