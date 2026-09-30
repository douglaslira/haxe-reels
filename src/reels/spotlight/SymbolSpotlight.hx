package reels.spotlight;

import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.geom.Point;
import reels.config.WinTypes.SymbolPosition;
import reels.core.Reel;
import reels.core.ReelViewport;
import reels.events.EventEmitter;
import reels.events.ReelEvents;
import reels.spotlight.SpotlightOptions.CycleOptions;
import reels.spotlight.SpotlightOptions.SpotlightOptions;
import reels.spotlight.SpotlightOptions.WinLine;
import reels.symbols.ReelSymbol;
import reels.tween.Easing;
import reels.tween.TweenDriver;
import reels.util.AbortToken;
import reels.util.IDisposable;

typedef PromotedSymbol = {
	symbol:ReelSymbol,
	originalParent:Null<DisplayObjectContainer>,
	position:SymbolPosition
};

/**
 * Win celebration primitive: dim + promote winners above the mask + playWin.
 * Does NOT detect wins — consumer passes cell positions.
 *
 * Callback-style (no Promises): `show` / `cycle` take `onComplete`.
 */
class SymbolSpotlight implements IDisposable {
	var _reels:Array<Reel>;
	var _viewport:ReelViewport;
	var _events:EventEmitter;
	var _tweens:TweenDriver;
	var _promoted:Array<PromotedSymbol> = [];
	var _isActive:Bool = false;
	var _destroyed:Bool = false;
	var _cycleToken:Null<AbortToken> = null;

	public function new(
		reels:Array<Reel>,
		viewport:ReelViewport,
		events:EventEmitter,
		tweens:TweenDriver
	) {
		_reels = reels;
		_viewport = viewport;
		_events = events;
		_tweens = tweens;
	}

	public var isActive(get, never):Bool;

	function get_isActive():Bool {
		return _isActive;
	}

	public var isDestroyed(get, never):Bool;

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	/** Show spotlight on positions; cancels any running cycle first. */
	public function show(
		positions:Array<SymbolPosition>,
		?options:SpotlightOptions,
		?onComplete:() -> Void
	):Void {
		hide();
		showInternal(positions, options, onComplete);
	}

	function showInternal(
		positions:Array<SymbolPosition>,
		?options:SpotlightOptions,
		?onComplete:() -> Void
	):Void {
		var dimAmount = options != null && options.dimAmount != null ? options.dimAmount : 0.5;
		var playWinAnimation = options == null || options.playWinAnimation != false;
		var promoteAboveMask = options == null || options.promoteAboveMask != false;

		_isActive = true;
		_events.emit(ReelEvents.SPOTLIGHT_START, [positions]);
		_viewport.showDim(dimAmount);

		var pending = 0;
		var finished = false;
		function maybeDone():Void {
			if (finished) return;
			if (pending > 0) return;
			finished = true;
			if (onComplete != null) onComplete();
		}

		var seen = new Map<String, Bool>();
		for (pos in positions) {
			if (pos.reelIndex < 0 || pos.reelIndex >= _reels.length) continue;
			var reel = _reels[pos.reelIndex];
			if (pos.cellIndex < 0 || pos.cellIndex >= reel.visibleCells) continue;

			var symbol = reel.getSymbolAt(pos.cellIndex);
			var key = pos.reelIndex + ":" + reel.getAnchorCell(pos.cellIndex);
			if (seen.exists(key)) continue;
			seen.set(key, true);

			if (promoteAboveMask) {
				var d = symbol.displayObject;
				if (d != null) {
					var originalParent:Null<DisplayObjectContainer> =
						Std.isOfType(d.parent, DisplayObjectContainer)
							? cast d.parent
							: null;
					_promoted.push({
						symbol: symbol,
						originalParent: originalParent,
						position: pos
					});
					promoteToSpotlight(d);
				}
			}

			if (playWinAnimation) {
				pending++;
				symbol.playWin(function() {
					pending--;
					maybeDone();
				});
			}
		}

		maybeDone();
	}

	function promoteToSpotlight(d:DisplayObject):Void {
		var layer = _viewport.spotlight;
		var global = d.localToGlobal(new Point(0, 0));
		layer.addChild(d);
		var local = layer.globalToLocal(global);
		d.x = local.x;
		d.y = local.y;
	}

	/** Hide spotlight and restore promoted symbols; aborts a running cycle. */
	public function hide():Void {
		if (_cycleToken != null) {
			_cycleToken.abort();
			_cycleToken = null;
		}
		teardownVisual();
	}

	/**
	 * Restore promoted symbols + hide dim without aborting a cycle.
	 * Cycle loop calls this between lines.
	 */
	function teardownVisual():Void {
		var layer = _viewport.spotlight;
		for (entry in _promoted) {
			var d = entry.symbol.displayObject;
			if (d == null) continue;
			// Pool recycled the symbol into another reel — do not steal it back.
			if (d.parent != layer) continue;
			if (entry.originalParent != null) {
				var global = d.localToGlobal(new Point(0, 0));
				entry.originalParent.addChild(d);
				var local = entry.originalParent.globalToLocal(global);
				d.x = local.x;
				d.y = local.y;
			}
			entry.symbol.stopAnimation();
		}
		_promoted = [];
		_viewport.hideDim();
		var wasActive = _isActive;
		_isActive = false;
		if (wasActive) _events.emit(ReelEvents.SPOTLIGHT_END, []);
	}

	/** Cycle win lines; resolves via onComplete when done or hide() aborts. */
	public function cycle(
		winLines:Array<WinLine>,
		?options:CycleOptions,
		?onComplete:() -> Void
	):Void {
		if (winLines == null || winLines.length == 0) {
			if (onComplete != null) onComplete();
			return;
		}

		var displayDuration = options != null && options.displayDuration != null
			? options.displayDuration
			: 2000.;
		var gapDuration = options != null && options.gapDuration != null
			? options.gapDuration
			: 300.;
		var cycles = options != null && options.cycles != null ? options.cycles : 1;

		hide();
		var token = new AbortToken();
		_cycleToken = token;

		var cycleCount = 0;
		var lineIndex = 0;
		var step:() -> Void = null;

		function finish():Void {
			if (_cycleToken == token) _cycleToken = null;
			if (onComplete != null) onComplete();
		}

		step = function() {
			if (token.aborted) {
				finish();
				return;
			}
			showInternal(winLines[lineIndex].positions, options, function() {
				if (token.aborted) {
					finish();
					return;
				}
				wait(displayDuration, token, function() {
					if (token.aborted) {
						finish();
						return;
					}
					teardownVisual();
					wait(gapDuration, token, function() {
						if (token.aborted) {
							finish();
							return;
						}
						lineIndex++;
						if (lineIndex >= winLines.length) {
							lineIndex = 0;
							cycleCount++;
							if (cycles != -1 && cycleCount >= cycles) {
								finish();
								return;
							}
						}
						step();
					});
				});
			});
		};

		step();
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

	public function destroy():Void {
		if (_destroyed) return;
		hide();
		_destroyed = true;
	}
}
