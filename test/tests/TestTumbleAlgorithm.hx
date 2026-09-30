package tests;

import reels.cascade.DropOffset;
import reels.cascade.TumbleAlgorithm;
import reels.core.Direction;
import utest.Assert;
import utest.Test;

class TestTumbleAlgorithm extends Test {
	function offsetsEqual(actual:Array<DropOffset>, expected:Array<DropOffset>, ?msg:String):Void {
		Assert.equals(expected.length, actual.length, msg);
		for (i in 0...expected.length) {
			var a = actual[i];
			var e = expected[i];
			Assert.equals(e.cell, a.cell, '$msg [$i].cell');
			Assert.equals(e.originalCell, a.originalCell, '$msg [$i].originalCell');
			Assert.equals(e.offsetCells, a.offsetCells, '$msg [$i].offsetCells');
			Assert.equals(e.isNew, a.isNew, '$msg [$i].isNew');
		}
	}

	function offsetCellsOf(offsets:Array<DropOffset>):Array<Int> {
		return [for (o in offsets) o.offsetCells];
	}

	function originalCellsOf(offsets:Array<DropOffset>):Array<Int> {
		return [for (o in offsets) o.originalCell];
	}

	// --- Moment A ---

	public function testInitialTreatsEveryCellAsNew() {
		var offsets = TumbleAlgorithm.computeDropOffsets(5, [], {initial: true});
		offsetsEqual(offsets, [
			{cell: 0, originalCell: -5, offsetCells: 5, isNew: true},
			{cell: 1, originalCell: -4, offsetCells: 5, isNew: true},
			{cell: 2, originalCell: -3, offsetCells: 5, isNew: true},
			{cell: 3, originalCell: -2, offsetCells: 5, isNew: true},
			{cell: 4, originalCell: -1, offsetCells: 5, isNew: true}
		]);
	}

	public function testInitialSameFallDistance() {
		var offsets = TumbleAlgorithm.computeDropOffsets(7, [], {initial: true});
		Assert.same([7, 7, 7, 7, 7, 7, 7], offsetCellsOf(offsets));
	}

	public function testInitialStacksOriginsAboveViewport() {
		var offsets = TumbleAlgorithm.computeDropOffsets(4, [], {initial: true});
		Assert.same([-4, -3, -2, -1], originalCellsOf(offsets));
	}

	public function testInitialIgnoresWinnerCells() {
		var offsets = TumbleAlgorithm.computeDropOffsets(3, [0, 2], {initial: true});
		Assert.same([3, 3, 3], offsetCellsOf(offsets));
	}

	// --- Moment B: no winners ---

	public function testRefillNoWinnersAllZero() {
		var offsets = TumbleAlgorithm.computeDropOffsets(5, []);
		Assert.same([0, 0, 0, 0, 0], offsetCellsOf(offsets));
		Assert.same([0, 1, 2, 3, 4], originalCellsOf(offsets));
	}

	public function testRefillNoWinnersExplicitInitialFalse() {
		var offsets = TumbleAlgorithm.computeDropOffsets(5, [], {initial: false});
		Assert.same([0, 0, 0, 0, 0], offsetCellsOf(offsets));
	}

	// --- Moment B: top winners ---

	public function testRefillTopOnlyWinner() {
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(5, [0]), [
			{cell: 0, originalCell: -1, offsetCells: 1, isNew: true},
			{cell: 1, originalCell: 1, offsetCells: 0, isNew: false},
			{cell: 2, originalCell: 2, offsetCells: 0, isNew: false},
			{cell: 3, originalCell: 3, offsetCells: 0, isNew: false},
			{cell: 4, originalCell: 4, offsetCells: 0, isNew: false}
		]);
	}

	public function testRefillTopTwoWinners() {
		var offsets = TumbleAlgorithm.computeDropOffsets(5, [0, 1]);
		offsetsEqual([offsets[0]], [{cell: 0, originalCell: -2, offsetCells: 2, isNew: true}]);
		offsetsEqual([offsets[1]], [{cell: 1, originalCell: -1, offsetCells: 2, isNew: true}]);
		offsetsEqual([offsets[2]], [{cell: 2, originalCell: 2, offsetCells: 0, isNew: false}]);
		offsetsEqual([offsets[3]], [{cell: 3, originalCell: 3, offsetCells: 0, isNew: false}]);
		offsetsEqual([offsets[4]], [{cell: 4, originalCell: 4, offsetCells: 0, isNew: false}]);
	}

	// --- Moment B: mid / scattered / bottom ---

	public function testRefillMidColumnWinner() {
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(5, [2]), [
			{cell: 0, originalCell: -1, offsetCells: 1, isNew: true},
			{cell: 1, originalCell: 0, offsetCells: 1, isNew: false},
			{cell: 2, originalCell: 1, offsetCells: 1, isNew: false},
			{cell: 3, originalCell: 3, offsetCells: 0, isNew: false},
			{cell: 4, originalCell: 4, offsetCells: 0, isNew: false}
		]);
	}

	public function testRefillScatteredWinners() {
		var offsets = TumbleAlgorithm.computeDropOffsets(5, [0, 2]);
		offsetsEqual([offsets[0]], [{cell: 0, originalCell: -2, offsetCells: 2, isNew: true}]);
		offsetsEqual([offsets[1]], [{cell: 1, originalCell: -1, offsetCells: 2, isNew: true}]);
		offsetsEqual([offsets[2]], [{cell: 2, originalCell: 1, offsetCells: 1, isNew: false}]);
		offsetsEqual([offsets[3]], [{cell: 3, originalCell: 3, offsetCells: 0, isNew: false}]);
		offsetsEqual([offsets[4]], [{cell: 4, originalCell: 4, offsetCells: 0, isNew: false}]);
	}

	public function testRefillBottomOnlyWinner() {
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(5, [4]), [
			{cell: 0, originalCell: -1, offsetCells: 1, isNew: true},
			{cell: 1, originalCell: 0, offsetCells: 1, isNew: false},
			{cell: 2, originalCell: 1, offsetCells: 1, isNew: false},
			{cell: 3, originalCell: 2, offsetCells: 1, isNew: false},
			{cell: 4, originalCell: 3, offsetCells: 1, isNew: false}
		]);
	}

	// --- Edge cases ---

	public function testFullClearAllNew() {
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(3, [0, 1, 2]), [
			{cell: 0, originalCell: -3, offsetCells: 3, isNew: true},
			{cell: 1, originalCell: -2, offsetCells: 3, isNew: true},
			{cell: 2, originalCell: -1, offsetCells: 3, isNew: true}
		]);
	}

	public function testSingleCellReel() {
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(1, [], {initial: true}), [
			{cell: 0, originalCell: -1, offsetCells: 1, isNew: true}
		]);
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(1, [0]), [
			{cell: 0, originalCell: -1, offsetCells: 1, isNew: true}
		]);
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(1, []), [
			{cell: 0, originalCell: 0, offsetCells: 0, isNew: false}
		]);
	}

	public function testUnsortedWinnerCells() {
		var sorted = TumbleAlgorithm.computeDropOffsets(5, [0, 2]);
		var unsorted = TumbleAlgorithm.computeDropOffsets(5, [2, 0]);
		offsetsEqual(unsorted, sorted);
	}

	// --- Reverse gravity ---

	public function testReversePacksSurvivorsAtStart() {
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(3, [0], {gravity: Reverse}), [
			{cell: 0, originalCell: 1, offsetCells: -1, isNew: false},
			{cell: 1, originalCell: 2, offsetCells: -1, isNew: false},
			{cell: 2, originalCell: 3, offsetCells: -1, isNew: true}
		]);
	}

	public function testReverseInitialEntersFromEnd() {
		var offsets = TumbleAlgorithm.computeDropOffsets(3, [], {initial: true, gravity: Reverse});
		Assert.same([3, 4, 5], originalCellsOf(offsets));
		Assert.same([-3, -3, -3], offsetCellsOf(offsets));
		for (o in offsets) Assert.isTrue(o.isNew);
	}

	public function testReverseMultipleArrivalsSameDistance() {
		offsetsEqual(TumbleAlgorithm.computeDropOffsets(3, [0, 1], {gravity: Reverse}), [
			{cell: 0, originalCell: 2, offsetCells: -2, isNew: false},
			{cell: 1, originalCell: 3, offsetCells: -2, isNew: true},
			{cell: 2, originalCell: 4, offsetCells: -2, isNew: true}
		]);
	}

	public function testReverseNoWinnersNoMove() {
		var offsets = TumbleAlgorithm.computeDropOffsets(5, [], {gravity: Reverse});
		Assert.same([0, 0, 0, 0, 0], offsetCellsOf(offsets));
		for (o in offsets) Assert.isFalse(o.isNew);
	}

	public function testReverseIsMirrorOfForward() {
		var n = 6;
		function mirror(c:Int):Int {
			return n - 1 - c;
		}
		var winnerSets:Array<Array<Int>> = [
			[0], [3], [0, 2], [1, 4, 5], [], [0, 1, 2, 3, 4, 5]
		];
		for (winners in winnerSets) {
			var rev = TumbleAlgorithm.computeDropOffsets(n, winners, {gravity: Reverse});
			var mirroredWinners = [for (w in winners) mirror(w)];
			var fwd = TumbleAlgorithm.computeDropOffsets(n, mirroredWinners, {gravity: Forward});
			var reflected:Array<DropOffset> = [
				for (o in fwd) {
					cell: mirror(o.cell),
					originalCell: mirror(o.originalCell),
					offsetCells: o.offsetCells == 0 ? 0 : -o.offsetCells,
					isNew: o.isNew
				}
			];
			reflected.sort(function(a, b) return a.cell - b.cell);
			offsetsEqual(reflected, rev, 'winners $winners');
		}
	}

	public function testDefaultsToForwardGravity() {
		offsetsEqual(
			TumbleAlgorithm.computeDropOffsets(4, [1]),
			TumbleAlgorithm.computeDropOffsets(4, [1], {gravity: Forward})
		);
	}
}
