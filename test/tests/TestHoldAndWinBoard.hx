package tests;

import reels.board.HoldAndWinBoard;
import reels.board.HoldAndWinBuilder;
import reels.board.HwCell;
import reels.board.HwCoin;
import reels.board.HwPhase;
import reels.board.HwRespinResult;
import reels.clock.FakeClock;
import reels.config.SpeedPresets;
import reels.symbols.HeadlessSymbol;
import utest.Assert;
import utest.Test;

/**
 * HoldAndWinBoard smoke — enter / respin / release / reset with FakeClock.
 */
class TestHoldAndWinBoard extends Test {
	var clock:FakeClock;
	var board:HoldAndWinBoard;

	public function setup() {
		clock = new FakeClock();
		board = new HoldAndWinBuilder()
			.grid(2, 2)
			.cellSize(40, {gap: 2})
			.respins(2)
			.stagger(function(_, _) return 0.)
			.speedProfile({
				name: SpeedPresets.SUPER_TURBO.name,
				spinDelay: 0,
				spinSpeed: 80,
				stopDelay: 0,
				anticipationDelay: 0,
				bounceDistance: 0,
				bounceDuration: 0,
				accelerationEase: "linear",
				decelerationEase: "linear",
				accelerationDuration: 0,
				minimumSpinTime: 50
			})
			.symbols(function(r) {
				r.register("coin", function() return new HeadlessSymbol());
			})
			.weights(["coin" => 1., "empty" => 3.])
			.clock(clock)
			.build();
	}

	public function teardown() {
		if (board != null && !board.isDestroyed) board.destroy();
		board = null;
		clock = null;
	}

	function coin(reel:Int, cell:Int, id:String = "coin", ?data:Dynamic):HwCoin {
		return {cell: {reel: reel, cell: cell}, id: id, data: data};
	}

	/** Drive FakeClock + skip until respin callback fires. */
	function finishRespin(hits:Array<HwCoin>, onDone:HwRespinResult->Void):Void {
		var done = false;
		board.respin(hits, function(result) {
			done = true;
			onDone(result);
		});
		// Skip early so cells land without waiting full minimumSpinTime waves.
		for (_ in 0...40) {
			if (done) break;
			board.skip();
			clock.advance(50);
		}
		Assert.isTrue(done, "respin should complete under FakeClock + skip");
	}

	public function testEnterSeedsLockedAndActive() {
		board.enter([coin(0, 0, "coin", {value: 10})]);
		Assert.equals(Active, board.phase);
		Assert.equals(2, board.respinsLeft);
		Assert.equals(1, board.lockedCoins.length);
		Assert.equals(3, board.freeCells.length);
		Assert.equals("coin", board.symbolAt({reel: 0, cell: 0}).symbolId);
	}

	public function testRespinHitLocksAndResetsCounter() {
		board.enter([coin(0, 0)]);
		var result:HwRespinResult = null;
		finishRespin([coin(1, 0)], function(r) result = r);
		Assert.notNull(result);
		Assert.equals(1, result.round);
		Assert.equals(1, result.hits.length);
		Assert.equals(2, result.respinsLeft); // hit resets
		Assert.equals(2, board.lockedCoins.length);
		Assert.isFalse(result.done);
		Assert.equals(Active, board.phase);
	}

	public function testRespinMissDecrementsAndCanEnd() {
		board.enter([coin(0, 0)]);
		// Two misses with respins=2 → feature ends after second miss.
		finishRespin([], function(_) {});
		Assert.equals(1, board.respinsLeft);
		Assert.equals(Active, board.phase);
		finishRespin([], function(r) {
			Assert.isTrue(r.done);
			Assert.equals(0, r.respinsLeft);
		});
		Assert.equals(Idle, board.phase);
	}

	public function testReleaseClearsCells() {
		board.enter([coin(0, 0), coin(1, 1)]);
		var released = board.release([{reel: 0, cell: 0}]);
		Assert.equals(1, released.length);
		Assert.equals(1, board.lockedCoins.length);
		Assert.equals("empty", board.symbolAt({reel: 0, cell: 0}).symbolId);
	}

	public function testResetReturnsIdle() {
		board.enter([coin(0, 0)]);
		board.reset();
		Assert.equals(Idle, board.phase);
		Assert.equals(0, board.lockedCoins.length);
		Assert.equals(0, board.respinsLeft);
		for (cell in board.freeCells) {
			Assert.equals("empty", board.symbolAt(cell).symbolId);
		}
	}

	public function testSetSymbolAtRewritesLocked() {
		board.enter([coin(0, 0, "coin")]);
		board.setSymbolAt({reel: 0, cell: 0}, "coin", {value: 99});
		Assert.equals("coin", board.symbolAt({reel: 0, cell: 0}).symbolId);
		Assert.equals(99, board.lockedCoins[0].data.value);
	}

	public function testBuilderRequiresSymbolsAndClock() {
		Assert.raises(function() {
			new HoldAndWinBuilder().clock(new FakeClock()).build();
		});
		Assert.raises(function() {
			new HoldAndWinBuilder()
				.symbols(function(r) r.register("coin", function() return new HeadlessSymbol()))
				.build();
		});
	}
}
