package reels.wins;

import reels.ReelSet;
import reels.config.WinTypes.SymbolPosition;
import reels.config.WinTypes.Win;
import reels.events.ReelEvents;
import reels.symbols.ReelSymbol;
import reels.tween.Easing;
import reels.tween.TweenDriver;
import reels.util.AbortToken;
import reels.util.IDisposable;
import reels.wins.WinSort;

/**
 * Highlight winning cells. Emits win:* events; does not draw lines.
 * Callback-style: `show(wins, onComplete)`.
 */
class WinPresenter implements IDisposable {
	var _reelSet:ReelSet;
	var _tweens:TweenDriver;
	var _dimAlpha:Null<Float>;
	var _stagger:Float;
	var _cycleGap:Float;
	var _cycles:Int;
	var _sortByValue:Bool;
	var _symbolAnim:String;
	var _customAnim:Null<(ReelSymbol, SymbolPosition, Win) -> Void>;
	var _abort:Null<AbortToken> = null;
	var _isActive:Bool = false;
	var _destroyed:Bool = false;

	public function new(reelSet:ReelSet, ?options:WinPresenterOptions) {
		_reelSet = reelSet;
		_tweens = reelSet.tweens;
		resolveOptions(options);
	}

	public var isActive(get, never):Bool;

	function get_isActive():Bool {
		return _isActive;
	}

	public var isDestroyed(get, never):Bool;

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	/**
	 * Present wins. Cancels any in-flight sequence first.
	 * Empty input completes immediately without events.
	 */
	public function show(wins:Array<Win>, ?onComplete:() -> Void):Void {
		abort();
		if (_destroyed) {
			if (onComplete != null) onComplete();
			return;
		}
		if (wins == null || wins.length == 0) {
			if (onComplete != null) onComplete();
			return;
		}

		var ordered = _sortByValue ? WinSort.sortByValueDesc(wins) : wins.copy();
		var token = new AbortToken();
		_abort = token;
		_isActive = true;
		_reelSet.events.emit(ReelEvents.WIN_START, [ordered]);

		var loop = 0;
		var winIndex = 0;

		function finish(reason:String):Void {
			restoreAlpha();
			if (_abort == token) _abort = null;
			_isActive = false;
			_reelSet.events.emit(ReelEvents.WIN_END, [reason]);
			if (onComplete != null) onComplete();
		}

		function afterGap():Void {
			if (token.aborted) {
				finish("aborted");
				return;
			}
			winIndex++;
			if (winIndex >= ordered.length) {
				winIndex = 0;
				loop++;
				if (_cycles != -1 && loop >= _cycles) {
					finish("complete");
					return;
				}
			}
			showOne(ordered[winIndex], token, function() {
				wait(_cycleGap, token, afterGap);
			});
		}

		showOne(ordered[0], token, function() {
			if (token.aborted) {
				finish("aborted");
				return;
			}
			wait(_cycleGap, token, afterGap);
		});
	}

	function showOne(win:Win, token:AbortToken, onDone:() -> Void):Void {
		var cells = win.cells != null ? win.cells.copy() : [];
		if (cells.length == 0) {
			onDone();
			return;
		}

		applyDim(cells);
		_reelSet.events.emit(ReelEvents.WIN_GROUP, [win, cells]);

		var idx = 0;
		var pending = 0;
		var kicked = 0;
		var finished = false;

		function finishOnce():Void {
			if (finished) return;
			if (kicked < cells.length) return;
			if (pending > 0) return;
			finished = true;
			onDone();
		}

		function cellDone():Void {
			pending--;
			finishOnce();
		}

		function kickNext():Void {
			if (token.aborted) {
				// Treat remaining as kicked so we can settle.
				kicked = cells.length;
				finishOnce();
				return;
			}
			if (idx >= cells.length) {
				finishOnce();
				return;
			}

			var cell = cells[idx++];
			kicked++;
			var reel = _reelSet.getReel(cell.reelIndex);
			if (reel != null && cell.cellIndex >= 0 && cell.cellIndex < reel.visibleCells) {
				var symbol = reel.getSymbolAt(cell.cellIndex);
				_reelSet.events.emit(ReelEvents.WIN_SYMBOL, [symbol, cell, win]);
				pending++;
				playAnim(symbol, cell, win, cellDone);
			}

			if (idx >= cells.length) {
				finishOnce();
				return;
			}
			if (_stagger <= 0) {
				kickNext();
			} else {
				wait(_stagger, token, kickNext);
			}
		}

		kickNext();
	}

	function playAnim(
		symbol:ReelSymbol,
		cell:SymbolPosition,
		win:Win,
		onComplete:() -> Void
	):Void {
		if (_customAnim != null) {
			_customAnim(symbol, cell, win);
			onComplete();
			return;
		}
		symbol.playWin(onComplete);
	}

	function applyDim(winCells:Array<SymbolPosition>):Void {
		if (_dimAlpha == null) return;
		var winKeys = new Map<String, Bool>();
		for (c in winCells) winKeys.set(c.reelIndex + ":" + c.cellIndex, true);

		for (r in 0..._reelSet.reelCount) {
			var reel = _reelSet.getReel(r);
			for (cell in 0...reel.visibleCells) {
				var key = r + ":" + cell;
				reel.getSymbolAt(cell).alpha = winKeys.exists(key) ? 1 : _dimAlpha;
			}
		}
	}

	function restoreAlpha():Void {
		for (r in 0..._reelSet.reelCount) {
			var reel = _reelSet.getReel(r);
			for (cell in 0...reel.visibleCells) {
				reel.getSymbolAt(cell).alpha = 1;
			}
		}
	}

	function wait(ms:Float, token:AbortToken, onDone:() -> Void):Void {
		if (token.aborted || ms <= 0) {
			onDone();
			return;
		}
		var done = false;
		var handle = _tweens.to(
			function() return 0.,
			function(_) {},
			1,
			ms,
			Easing.linear,
			function() {
				if (done) return;
				done = true;
				onDone();
			}
		);
		token.onAbort(function() {
			if (done) return;
			done = true;
			_tweens.kill(handle);
			onDone();
		});
	}

	/** Abort any in-flight show(). */
	public function abort():Void {
		if (_abort != null) _abort.abort();
	}

	public function destroy():Void {
		if (_destroyed) return;
		_destroyed = true;
		abort();
	}

	function resolveOptions(?opts:WinPresenterOptions):Void {
		if (opts == null) {
			_dimAlpha = 0.35;
			_stagger = 0;
			_cycleGap = 400;
			_cycles = 1;
			_sortByValue = true;
			_symbolAnim = "win";
			_customAnim = null;
			return;
		}

		if (opts.dimLosers == false) {
			_dimAlpha = null;
		} else if (opts.dimLosersAlpha != null) {
			_dimAlpha = opts.dimLosersAlpha;
		} else {
			_dimAlpha = 0.35;
		}

		_stagger = opts.stagger != null ? Math.max(0, opts.stagger) : 0;
		_cycleGap = opts.cycleGap != null ? opts.cycleGap : 400;
		_cycles = opts.cycles != null ? opts.cycles : 1;
		_sortByValue = opts.sortByValue != false;
		_symbolAnim = opts.symbolAnim != null ? opts.symbolAnim : "win";
		_customAnim = opts.customAnim;
	}
}

typedef WinPresenterOptions = {
	/**
	 * Fade non-winners. `false` = leave alphas alone.
	 * Use `dimLosersAlpha` for a custom fade (default 0.35 when dimming).
	 */
	?dimLosers:Bool,
	?dimLosersAlpha:Float,
	/** Named anim; currently only `"win"` (playWin). Use customAnim for hooks. */
	?symbolAnim:String,
	?customAnim:(ReelSymbol, SymbolPosition, Win) -> Void,
	?stagger:Float,
	?cycleGap:Float,
	?cycles:Int,
	?sortByValue:Bool
};
