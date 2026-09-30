package reels.board;

import openfl.display.Sprite;
import reels.ReelSet;
import reels.ReelSetBuilder;
import reels.config.SpeedPresets;
import reels.config.SpeedProfile;
import reels.config.WinTypes.CellBounds;
import reels.core.Direction;
import reels.core.Orientation;
import reels.core.SharedRectMaskStrategy;
import reels.frame.ColumnTarget;
import reels.symbols.EmptySymbol;
import reels.symbols.ReelSymbol;
import reels.util.IDisposable;

/**
 * A grid of cells that each spin **independently** — the generic "board of
 * reels" primitive. Every cell is its own 1×1 {@link ReelSet}.
 *
 * Mechanism-only: no coins, locks, respins or value. {@link HoldAndWinBoard}
 * is the opinionated layer built on this surface.
 */
class BoardGrid implements IDisposable {
	static inline var DEFAULT_PROFILE = "default";

	public final view:Sprite;
	public final cols:Int;
	public final rows:Int;
	public final cellSize:Float;
	public final gap:Float;
	public final emptyId:String;

	var _reels:Map<String, ReelSet> = new Map();
	var _cells:Array<BoardCell> = [];
	var _bufferSymbols:Int;
	/** Non-empty weight ids used to pad stop buffers (avoids EmptySymbol vanishing). */
	var _fillerIds:Array<String> = [];
	var _rng:() -> Float;
	var _destroyed:Bool = false;

	public function new(opts:BoardGridOptions) {
		if (opts.clock == null) throw "BoardGrid: a clock is required.";
		cols = opts.cols;
		rows = opts.rows;
		cellSize = opts.cellSize;
		gap = opts.gap != null ? opts.gap : 4;
		emptyId = opts.emptyId != null ? opts.emptyId : "empty";
		_bufferSymbols = opts.bufferSymbols != null ? Std.int(opts.bufferSymbols) : 3;
		if (_bufferSymbols < 1) _bufferSymbols = 1;
		_rng = opts.rng != null ? opts.rng : Math.random;
		if (opts.weights != null) {
			for (id => w in opts.weights) {
				if (w > 0 && id != emptyId) _fillerIds.push(id);
			}
		}
		view = new Sprite();

		var profiles = opts.profiles;
		if (profiles == null || !profiles.keys().hasNext()) {
			profiles = new Map();
			profiles.set(DEFAULT_PROFILE, function(_:BoardCell):SpeedProfile {
				return withName(SpeedPresets.NORMAL, DEFAULT_PROFILE, 320);
			});
		}
		var profileNames = [for (k in profiles.keys()) k];
		var orientation:Orientation = opts.orientation != null ? opts.orientation : Vertical;
		var direction:Direction = opts.direction != null ? opts.direction : Forward;
		var empty = emptyId;
		var buf = emptyBuffer();

		for (reel in 0...opts.cols) {
			for (rowIdx in 0...opts.rows) {
				var cell:BoardCell = {reel: reel, cell: rowIdx};
				var origin = originOf(cell);
				if (opts.chrome != null) {
					var bg = new Sprite();
					opts.chrome(bg.graphics, cellSize);
					bg.x = origin.x;
					bg.y = origin.y;
					view.addChild(bg);
				}

				var builder = new ReelSetBuilder()
					.reels(1)
					.visibleCells(1)
					.symbolSize(cellSize, cellSize)
					.symbolGap(0, 0)
					.bufferSymbols(_bufferSymbols)
					.maskStrategy(new SharedRectMaskStrategy())
					.symbols(function(registry) {
						opts.symbols(registry);
						if (!registry.has(empty)) registry.registerClass(empty, EmptySymbol);
					})
					.initialFrame([
						{visible: [empty], bufferStart: buf.copy(), bufferEnd: buf.copy()}
					])
					.clock(opts.clock)
					.orientation(orientation)
					.direction(direction)
					.initialSpeed(profileNames[0]);

				for (name in profileNames) {
					var resolve = profiles.get(name);
					builder.speed(name, resolve(cell));
				}
				if (opts.weights != null) builder.weights(opts.weights);
				if (opts.rng != null) builder.rng(opts.rng);

				var reelSet = builder.build();
				reelSet.view.x = origin.x;
				reelSet.view.y = origin.y;
				view.addChild(reelSet.view);
				_reels.set(cellKey(cell), reelSet);
				_cells.push(cell);
			}
		}
	}

	/** Every cell coordinate, reel-major: (0,0), (0,1), … then (1,0). */
	public function cells():Array<BoardCell> {
		return [for (c in _cells) {reel: c.reel, cell: c.cell}];
	}

	/** Board-local bounds of a cell. */
	public function cellBounds(cell:BoardCell):CellBounds {
		var o = originOf(cell);
		return {x: o.x, y: o.y, width: cellSize, height: cellSize};
	}

	/** Board-local center of a cell — flight / trail anchors. */
	public function cellCenter(cell:BoardCell):{x:Float, y:Float} {
		var o = originOf(cell);
		return {x: o.x + cellSize / 2, y: o.y + cellSize / 2};
	}

	/** Live symbol instance currently shown in a cell. */
	public function symbolAt(cell:BoardCell):ReelSymbol {
		return reelAt(cell).getReel(0).getSymbolAt(0);
	}

	/** The cell's underlying 1×1 ReelSet. */
	public function reelAt(cell:BoardCell):ReelSet {
		return reelOf(cell);
	}

	/** Select a registered speed profile by name for one cell. */
	public function setProfile(cell:BoardCell, name:String):Void {
		reelOf(cell).setSpeed(name);
	}

	/** Place a symbol instantly (no spin), with blank off-window buffers. */
	public function place(cell:BoardCell, id:String):Void {
		var buf = emptyBuffer();
		reelOf(cell).getReel(0).forceResult({
			visible: [id],
			bufferStart: buf,
			bufferEnd: buf.copy()
		});
	}

	/**
	 * Spin each target cell and stop it showing its `id`. `onLanded` fires per
	 * cell as it settles. When every target has landed, `onComplete` fires.
	 *
	 * Stop buffers are padded with **visible** strip fillers (not `emptyId`):
	 * EmptySymbol in the StopFrameQueue makes the cell go blank mid-stop, then
	 * the land id pops in — which reads as "fell away, then locked". After
	 * settle, {@link place} clears buffers back to empty for a clean rest.
	 */
	public function spinCells(
		targets:Array<BoardSpinTarget>,
		?onLanded:BoardCell->String->Void,
		?onComplete:() -> Void
	):Void {
		if (targets.length == 0) {
			if (onComplete != null) onComplete();
			return;
		}
		var remaining = targets.length;
		for (t in targets) {
			var cell = t.cell;
			var id = t.id;
			var reelSet = reelOf(cell);
			var target:ColumnTarget = {
				visible: [id],
				bufferStart: spinBuffer(),
				bufferEnd: spinBuffer()
			};
			reelSet.spin(null, function(_) {
				// Rest state: blank off-window so neighbours stay clean.
				place(cell, id);
				if (onLanded != null) onLanded(cell, id);
				remaining -= 1;
				if (remaining == 0 && onComplete != null) onComplete();
			});
			reelSet.setResult([target]);
		}
	}

	/** Slam every in-flight cell. Returns the count that were spinning. */
	public function skipSpinning():Int {
		var inFlight = 0;
		for (reelSet in _reels) {
			if (reelSet.isSpinning) {
				inFlight += 1;
				try {
					reelSet.skipSpin();
				} catch (_:Dynamic) {
					// result not provided yet — nothing to skip to
				}
			}
		}
		return inFlight;
	}

	public var isDestroyed(get, never):Bool;

	function get_isDestroyed():Bool {
		return _destroyed;
	}

	public function destroy():Void {
		if (_destroyed) return;
		_destroyed = true;
		for (reelSet in _reels) reelSet.destroy();
		_reels.clear();
		_cells = [];
		if (view.parent != null) view.parent.removeChild(view);
		view.removeChildren();
	}

	function originOf(cell:BoardCell):{x:Float, y:Float} {
		return {
			x: cell.reel * (cellSize + gap),
			y: cell.cell * (cellSize + gap)
		};
	}

	function emptyBuffer():Array<Null<String>> {
		return [for (_ in 0..._bufferSymbols) emptyId];
	}

	/** Visible pad for stop wraps — never EmptySymbol, or the window goes blank. */
	function spinBuffer():Array<Null<String>> {
		return [for (_ in 0..._bufferSymbols) pickFiller()];
	}

	function pickFiller():String {
		if (_fillerIds.length == 0) return emptyId;
		var i = Std.int(_rng() * _fillerIds.length);
		if (i < 0) i = 0;
		if (i >= _fillerIds.length) i = _fillerIds.length - 1;
		return _fillerIds[i];
	}

	function reelOf(cell:BoardCell):ReelSet {
		var reelSet = _reels.get(cellKey(cell));
		if (reelSet == null) {
			throw 'BoardGrid: cell ${cellKey(cell)} is outside the ${cols}x${rows} grid.';
		}
		return reelSet;
	}

	static function cellKey(c:BoardCell):String {
		return '${c.reel},${c.cell}';
	}

	static function withName(base:SpeedProfile, name:String, minimumSpinTime:Float):SpeedProfile {
		return {
			name: name,
			spinDelay: base.spinDelay,
			spinSpeed: base.spinSpeed,
			stopDelay: base.stopDelay,
			anticipationDelay: base.anticipationDelay,
			bounceDistance: base.bounceDistance,
			bounceDuration: base.bounceDuration,
			accelerationEase: base.accelerationEase,
			decelerationEase: base.decelerationEase,
			accelerationDuration: base.accelerationDuration,
			minimumSpinTime: minimumSpinTime
		};
	}
}
