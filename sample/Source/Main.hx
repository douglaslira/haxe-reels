package;

import openfl.Lib;
import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import reels.ReelSet;
import reels.ReelSetBuilder;
import reels.board.HoldAndWinBoard;
import reels.board.HoldAndWinBuilder;
import reels.board.HwCoin;
import reels.board.HwPhase;
import reels.clock.FrameClock;
import reels.config.SpeedPresets;
import reels.config.SpeedProfile;
import reels.core.Direction;
import reels.core.Orientation;
import reels.events.ReelEvents;
import reels.frame.ColumnTarget;
import reels.symbols.BigSymbolCoord;
import reels.symbols.BitmapReelSymbol;
import reels.spine.MockSpineFactory;
import reels.spine.SpineReelSymbol;
import reels.wins.WinPresenter;
import reels.config.WinTypes.SymbolPosition;
import reels.config.WinTypes.Win;

#if html5
import js.Browser;
#end

/**
 * OpenFL stage hosts reels only. Config UI lives in HTML (Tailwind) via HaxeReelsDemo.
 *
 *   cd sample && openfl test html5
 */
class Main extends Application {
	/** Matches project.xml window — max board 5×4 + padding. */
	static inline var STAGE_W = 688;
	static inline var STAGE_H = 516;
	static inline var STAGE_PAD = 32;

	static final IDS = ["A", "K", "Q", "J", "7", "BAR", "WILD", "COIN", "BIG"];
	static final COLORS:Map<String, Int> = [
		"A" => 0xE74C3C,
		"K" => 0x9B59B6,
		"Q" => 0x3498DB,
		"J" => 0x1ABC9C,
		"7" => 0xF1C40F,
		"BAR" => 0xE67E22,
		"WILD" => 0x2ECC71,
		"COIN" => 0xF4D03F,
		"BIG" => 0xC0392B
	];

	var _root:Sprite;
	var _stageHost:Sprite;
	var _frame:Sprite;
	var _reelSet:Null<ReelSet>;
	var _hwBoard:Null<HoldAndWinBoard>;
	var _clock:FrameClock;
	var _atlas:Map<String, BitmapData>;
	var _spinning:Bool = false;
	var _round:Int = 0;
	var _landedCount:Int = 0;
	var _statusCb:Null<String->Bool->Void>;

	var _cfgReels:Int = 5;
	var _cfgCells:Int = 3;
	var _cfgDirection:String = "forward";
	var _cfgAltDirs:Bool = false;
	var _cfgSpeed:String = "normal";
	var _cfgStopDelay:Float = 140;
	var _cfgBounce:Float = 56;
	var _cfgCurve:Float = 0;
	var _cfgCurvePreset:String = "flat";
	var _cfgCurveMode:String = "symbol";
	var _cfgCascade:Bool = false;
	var _cfgRefillMode:String = "gravity-then-drop";
	var _cfgGravityHoldMs:Float = 280;
	var _cfgMultiways:Bool = false;
	var _cfgHorizontal:Bool = false;
	var _cfgStickyPin:Bool = false;
	var _cfgSpineWild:Bool = false;
	var _cfgHoldRespin:Bool = false;
	/** Cell-level Hold&Win board (exclusive w/ cascade / MW / column hold). */
	var _cfgHoldAndWinBoard:Bool = false;
	/** Columns frozen for the next spin (`spin({ holdReels })`). */
	var _heldReels:Array<Int> = [];
	var _respinsLeft:Int = 0;
	static inline var HOLD_DEFAULT_RESPINS:Int = 3;
	static inline var HOLD_ANCHOR:String = "BAR";
	static inline var HW_COIN:String = "COIN";
	static inline var HW_COLS:Int = 3;
	static inline var HW_ROWS:Int = 3;
	static inline var HW_CELL:Float = 88;
	var _stickyReel:Int = -1;
	var _stickyCell:Int = -1;
	/** Queued grid for the next `setResult` (lab forceResult while spinning). */
	var _forceNext:Null<Array<ColumnTarget>> = null;
	var _cfgMwMin:Int = 2;
	var _cfgMwMax:Int = 4;
	var _pendingShape:Null<Array<Int>> = null;
	var _busy:Bool = false;
	var _winPresenter:Null<WinPresenter> = null;

	public function new() {
		super();
	}

	override function onWindowCreate():Void {
		_root = new Sprite();
		Lib.current.addChild(_root);

		_root.graphics.beginFill(0x0A1812);
		_root.graphics.drawRect(0, 0, STAGE_W, STAGE_H);
		_root.graphics.endFill();

		_stageHost = new Sprite();
		_root.addChild(_stageHost);

		_frame = new Sprite();
		_root.addChild(_frame);

		_clock = new FrameClock();
		_atlas = buildAtlas();

		rebuildReelSet();
		exposeBridge();
		emitStatus("Ready — press SPIN", false);
	}

	function exposeBridge():Void {
		#if html5
		var self = this;
		Reflect.setField(Browser.window, "HaxeReelsDemo", {
			configure: function(cfg:Dynamic) {
				self.configureFromJs(cfg);
			},
			spin: function() {
				self.doSpin();
			},
			skip: function() {
				self.doSkip();
			},
			refill: function() {
				self.doRefill();
			},
			runCascade: function() {
				self.doRunCascade();
			},
			movePin: function() {
				self.doMovePin();
			},
			showWins: function() {
				self.doShowWins();
			},
			nudge: function() {
				self.doNudge();
			},
			forceResult: function(?kind:String) {
				self.doForceResult(kind);
			},
			getConfig: function() {
				return self.currentConfig();
			},
			dumpReels: function() {
				return self.dumpReels();
			},
			onStatus: function(fn:Dynamic) {
				self._statusCb = function(msg:String, spinning:Bool) {
					fn(msg, spinning);
				};
			}
		});
		#end
	}

	function dumpReels():Dynamic {
		if (_reelSet == null) return {error: "no reelSet"};
		var reels:Array<Dynamic> = [];
		for (r in 0..._cfgReels) {
			var reel = _reelSet.getReel(r);
			var cells:Array<Dynamic> = [];
			for (c in 0...reel.visibleCells) {
				var s = reel.getVisibleSymbol(c);
				var d = s.displayObject;
				var bmScaleX = -1.;
				var bmScaleY = -1.;
				var bmVisible = false;
				var hostKids = -1;
				if (d != null) {
					hostKids = Std.isOfType(d, Sprite) ? cast(d, Sprite).numChildren : -1;
					if (Std.isOfType(d, Sprite)) {
						var sp:Sprite = cast d;
						for (i in 0...sp.numChildren) {
							var ch = sp.getChildAt(i);
							if (Std.isOfType(ch, openfl.display.Bitmap)) {
								var bm:openfl.display.Bitmap = cast ch;
								bmScaleX = bm.scaleX;
								bmScaleY = bm.scaleY;
								bmVisible = bm.visible;
							}
						}
					}
				}
				cells.push({
					c: c,
					id: s.symbolId,
					cellH: s.cellHeight,
					reelH: reel.symbolHeight,
					alpha: s.alpha,
					visible: s.visible,
					y: s.y,
					onHost: d != null && d.parent == reel.host,
					parentKids: d != null && d.parent != null ? d.parent.numChildren : -1,
					symKids: hostKids,
					bmSX: bmScaleX,
					bmSY: bmScaleY,
					bmVis: bmVisible
				});
			}
			reels.push({
				r: r,
				cells: reel.visibleCells,
				H: reel.symbolHeight,
				hostKids: reel.host.numChildren,
				hostY: reel.host.y,
				ids: reel.getVisibleIds(),
				mains: reel.getVisibleMains(),
				cellsDetail: cells
			});
		}
		return {
			shape: _pendingShape,
			sticky: [_stickyReel, _stickyCell],
			maskInset: _reelSet.maskMainInset,
			unmaskedKids: _reelSet.view != null ? -1 : -1,
			reels: reels
		};
	}

	function currentConfig():Dynamic {
		return {
			reels: _cfgReels,
			visibleCells: _cfgCells,
			direction: _cfgDirection,
			alternateDirections: _cfgAltDirs,
			speed: _cfgSpeed,
			stopDelay: _cfgStopDelay,
			bounceDistance: _cfgBounce,
			curve: _cfgCurve,
			curvePreset: _cfgCurvePreset,
			curveMode: _cfgCurveMode,
			cascade: _cfgCascade,
			refillMode: _cfgRefillMode,
			gravityHoldMs: _cfgGravityHoldMs,
			multiways: _cfgMultiways,
			horizontal: _cfgHorizontal,
			stickyPin: _cfgStickyPin,
			spineWild: _cfgSpineWild,
			holdRespin: _cfgHoldRespin,
			holdAndWinBoard: _cfgHoldAndWinBoard,
			heldReels: _heldReels.copy(),
			respinsLeft: _respinsLeft
		};
	}

	function configureFromJs(cfg:Dynamic):Void {
		if (cfg == null) return;

		var nextReels = cfg.reels != null ? Std.int(cfg.reels) : _cfgReels;
		var nextCells = cfg.visibleCells != null ? Std.int(cfg.visibleCells) : _cfgCells;
		var nextDir:String = cfg.direction != null ? Std.string(cfg.direction) : _cfgDirection;
		var nextAlt = cfg.alternateDirections == true;
		var nextSpeed:String = cfg.speed != null ? Std.string(cfg.speed) : _cfgSpeed;
		var nextDelay:Float = cfg.stopDelay != null ? cfg.stopDelay : _cfgStopDelay;
		var nextBounce:Float = cfg.bounceDistance != null ? cfg.bounceDistance : _cfgBounce;
		var nextCurve:Float = cfg.curve != null ? cfg.curve : _cfgCurve;
		var nextPreset:String = cfg.curvePreset != null ? Std.string(cfg.curvePreset) : _cfgCurvePreset;
		var nextCurveMode:String = cfg.curveMode != null ? Std.string(cfg.curveMode) : _cfgCurveMode;
		var nextCascade = cfg.cascade == true;
		var nextRefillMode:String = cfg.refillMode != null ? Std.string(cfg.refillMode) : _cfgRefillMode;
		var nextHold:Float = cfg.gravityHoldMs != null ? cfg.gravityHoldMs : _cfgGravityHoldMs;
		var nextMw = cfg.multiways == true;
		var nextHorizontal = cfg.horizontal == true;
		var nextSticky = cfg.stickyPin == true;
		var nextSpineWild = cfg.spineWild == true;
		var nextHoldRespin = cfg.holdRespin == true;
		var nextHwBoard = cfg.holdAndWinBoard == true;

		nextReels = clampInt(nextReels, 3, 5);
		nextCells = clampInt(nextCells, 3, 4);
		if (nextDir != "reverse") nextDir = "forward";
		if (nextSpeed != "turbo" && nextSpeed != "superTurbo") nextSpeed = "normal";
		nextDelay = clampFloat(nextDelay, 0, 300);
		nextBounce = clampFloat(nextBounce, 0, 80);
		nextCurve = clampFloat(nextCurve, 0, 1);
		nextPreset = normalizeCurvePreset(nextPreset);
		nextCurveMode = normalizeCurveMode(nextCurveMode);
		if (nextPreset == "flat") {
			nextCurve = 0;
			nextCurveMode = "symbol";
		} else if (nextCurve <= 0) nextCurve = 0.4;
		if (nextRefillMode != "combined") nextRefillMode = "gravity-then-drop";
		nextHold = clampFloat(nextHold, 0, 800);
		// Exclusive modes: cascade ↔ MW; hold-respin / HW board vs tumble; HW vs column hold.
		if (nextMw) nextCascade = false;
		if (nextCascade) nextMw = false;
		if (nextHorizontal) nextMw = false;
		if (nextMw) nextHorizontal = false;
		if (nextHwBoard) {
			nextCascade = false;
			nextMw = false;
			nextHoldRespin = false;
		}
		if (nextHoldRespin) {
			nextCascade = false;
			nextHwBoard = false;
		}
		if (nextCascade) {
			nextHoldRespin = false;
			nextHwBoard = false;
		}
		if (nextMw) nextHwBoard = false;

		var needsRebuild = nextReels != _cfgReels
			|| nextCells != _cfgCells
			|| nextDir != _cfgDirection
			|| nextAlt != _cfgAltDirs
			|| nextBounce != _cfgBounce
			|| nextCurve != _cfgCurve
			|| nextPreset != _cfgCurvePreset
			|| nextCurveMode != _cfgCurveMode
			|| nextCascade != _cfgCascade
			|| nextMw != _cfgMultiways
			|| nextHorizontal != _cfgHorizontal
			|| nextSpineWild != _cfgSpineWild
			|| nextHwBoard != _cfgHoldAndWinBoard;

		_cfgReels = nextReels;
		_cfgCells = nextCells;
		_cfgDirection = nextDir;
		_cfgAltDirs = nextAlt;
		_cfgSpeed = nextSpeed;
		_cfgStopDelay = nextDelay;
		_cfgBounce = nextBounce;
		_cfgCurve = nextCurve;
		_cfgCurvePreset = nextPreset;
		_cfgCurveMode = nextCurveMode;
		_cfgCascade = nextCascade;
		_cfgRefillMode = nextRefillMode;
		_cfgGravityHoldMs = nextHold;
		_cfgMultiways = nextMw;
		_cfgHorizontal = nextHorizontal;
		_cfgSpineWild = nextSpineWild;
		var stickyChanged = nextSticky != _cfgStickyPin;
		_cfgStickyPin = nextSticky;
		var holdChanged = nextHoldRespin != _cfgHoldRespin;
		_cfgHoldRespin = nextHoldRespin;
		_cfgHoldAndWinBoard = nextHwBoard;
		if (holdChanged && !_cfgHoldRespin) clearHoldFeature();

		if (needsRebuild) {
			if ((_spinning || _busy) && _reelSet != null) {
				_reelSet.slamStop();
				_spinning = false;
				_busy = false;
			}
			if ((_spinning || _busy) && _hwBoard != null) {
				_hwBoard.skip();
				_spinning = false;
				_busy = false;
			}
			clearHoldFeature();
			rebuildReelSet();
			var mode = _cfgHoldAndWinBoard
				? "hold&win-board"
				: (_cfgMultiways
					? "multiways"
					: (_cfgHorizontal
						? "horizontal"
						: (_cfgCascade ? "cascade" : "standard")));
			var dirNote = _cfgAltDirs ? ", alt dirs" : "";
			var curveNote = _cfgCurvePreset != "flat"
				? ', curve ${_cfgCurvePreset}/${_cfgCurveMode} ${Math.round(_cfgCurve * 100) / 100}'
				: "";
			var stickyNote = _cfgStickyPin ? ", sticky" : "";
			var spineNote = _cfgSpineWild ? ", spine WILD" : "";
			var holdNote = _cfgHoldRespin ? ", hold-respin" : "";
			emitStatus('Rebuilt ${_cfgHoldAndWinBoard ? '${HW_COLS}x${HW_ROWS}' : '${_cfgReels}x${_cfgMultiways ? _cfgMwMax : _cfgCells}'} ($mode$dirNote$curveNote$stickyNote$spineNote$holdNote)', false);
		} else if (_reelSet != null) {
			applyLiveTuning();
			if (stickyChanged) applyStickyPinConfig();
			if (holdChanged && _cfgHoldRespin) {
				emitStatus("Hold respin on — BAR columns lock on land", false);
			} else {
				emitStatus('Live: ${_cfgSpeed}, stagger ${_cfgStopDelay}ms, refill ${_cfgRefillMode}', _spinning || _busy);
			}
		} else if (_hwBoard != null && holdChanged) {
			emitStatus("Hold&Win board ready — SPIN to enter / respin", false);
		}
	}

	function normalizeCurvePreset(raw:String):String {
		return switch (raw) {
			case "single", "per-reel", "set", "set-lean": raw;
			case _: "flat";
		};
	}

	function normalizeCurveMode(raw:String):String {
		return raw == "warp" ? "warp" : "symbol";
	}

	function applyLiveTuning():Void {
		if (_reelSet == null) return;
		_reelSet.setSpeed(_cfgSpeed);
		_reelSet.setStopDelays(buildStopDelays());
	}

	function buildStopDelays():Array<Float> {
		return [for (i in 0..._cfgReels) _cfgStopDelay * i];
	}

	function profileWithBounce(base:SpeedProfile, bounce:Float):SpeedProfile {
		return {
			name: base.name,
			spinDelay: base.spinDelay,
			spinSpeed: base.spinSpeed,
			stopDelay: base.stopDelay,
			anticipationDelay: base.anticipationDelay,
			bounceDistance: bounce,
			bounceDuration: base.bounceDuration,
			accelerationEase: base.accelerationEase,
			decelerationEase: base.decelerationEase,
			accelerationDuration: base.accelerationDuration,
			minimumSpinTime: base.minimumSpinTime
		};
	}

	function rebuildReelSet():Void {
		if (_winPresenter != null) {
			_winPresenter.destroy();
			_winPresenter = null;
		}
		destroyHwBoard();
		if (_reelSet != null) {
			if (_reelSet.view.parent != null) _reelSet.view.parent.removeChild(_reelSet.view);
			_reelSet.destroy();
			_reelSet = null;
		}
		_stickyReel = -1;
		_stickyCell = -1;
		_forceNext = null;

		if (_cfgHoldAndWinBoard) {
			rebuildHoldAndWinBoard();
			return;
		}

		var dir:Direction = _cfgDirection == "reverse" ? Reverse : Forward;
		var gapX = 4.0;
		var gapY = 0.0;
		var symbolW = 120.0;
		var symbolH = 110.0;
		var reelExtent = 0.;
		if (_cfgMultiways) {
			reelExtent = _cfgMwMax * symbolH;
			symbolH = reelExtent / _cfgMwMax;
		}

		if (_cfgHorizontal) {
			gapX = 0.0;
			gapY = 4.0;
			// Fit stacked reels into the OpenFL window (cells along X, reels on Y).
			var maxBoardH = STAGE_H - 2 * STAGE_PAD;
			var naturalH = _cfgReels * symbolH + (_cfgReels - 1) * gapY;
			if (naturalH > maxBoardH && naturalH > 0) {
				var scale = maxBoardH / naturalH;
				symbolW *= scale;
				symbolH *= scale;
			}
		}

		var builder = new ReelSetBuilder()
			.reels(_cfgReels)
			.symbolSize(symbolW, symbolH)
			.symbolGap(gapX, gapY)
			.bufferSymbols(1)
			.direction(dir)
			.orientation(_cfgHorizontal ? Orientation.Horizontal : Orientation.Vertical)
			.clock(_clock)
			.symbols(function(r) {
				var spineFactory = _cfgSpineWild ? new MockSpineFactory() : null;
				for (id in IDS) {
					if (id == "WILD" && spineFactory != null) {
						r.register("WILD", function() {
							return new SpineReelSymbol({
								factory: spineFactory,
								spineMap: [
									"WILD" => {skeleton: "WILD", atlas: "WILD", skin: "WILD"}
								]
							});
						});
					} else if (id == "BIG") {
						r.registerClass(
							id,
							BitmapReelSymbol,
							{bitmapDataMap: _atlas},
							{size: {reels: 2, cells: 2}}
						);
					} else {
						r.registerClass(id, BitmapReelSymbol, {bitmapDataMap: _atlas});
					}
				}
			})
			.weights(_cfgSpineWild
				? [
					// Heavy WILD so smoke (curve + Spine) lands without hunting.
					"A" => 10, "K" => 10, "Q" => 10,
					"J" => 10, "7" => 6, "BAR" => 6, "WILD" => 48
				]
				: [
					"A" => 20, "K" => 20, "Q" => 20,
					"J" => 20, "7" => 10, "BAR" => 10
				]
			)
			.speed("normal", profileWithBounce(SpeedPresets.NORMAL, _cfgBounce))
			.speed("turbo", profileWithBounce(SpeedPresets.TURBO, _cfgBounce))
			.speed("superTurbo", profileWithBounce(SpeedPresets.SUPER_TURBO, _cfgBounce))
			.initialSpeed(_cfgSpeed);

		if (_cfgMultiways) {
			builder.multiways({
				minCells: _cfgMwMin,
				maxCells: _cfgMwMax,
				reelExtent: reelExtent
			});
			// Pin-overlay migrate tween across reshape (pixi pinMigrationDuration).
			builder.pinMigrationDuration(300);
		} else {
			builder.visibleCells(_cfgCells);
		}

		// Seed a mid-row WILD on every reel so Spine-on-curve is visible at idle
		// without spinning first.
		if (_cfgSpineWild && !_cfgMultiways) {
			var frame:Array<ColumnTarget> = [];
			var fillers = ["A", "K", "Q", "J", "7", "BAR"];
			for (r in 0..._cfgReels) {
				var col:Array<String> = [];
				for (c in 0..._cfgCells) {
					col.push(c == Std.int((_cfgCells - 1) / 2)
						? "WILD"
						: fillers[(r + c) % fillers.length]);
				}
				frame.push({visible: col});
			}
			builder.initialFrame(frame);
		}

		if (_cfgAltDirs) {
			var opposite:Direction = dir == Forward ? Reverse : Forward;
			var perReel:Array<Direction> = [];
			for (i in 0..._cfgReels) {
				perReel.push(i % 2 == 0 ? dir : opposite);
			}
			builder.directionPerReel(perReel);
		}

		if (_cfgCurvePreset != "flat" && _cfgCurve > 0) {
			if (_cfgCurvePreset == "per-reel") {
				var curves:Array<Dynamic> = [];
				var mid = (_cfgReels - 1) / 2;
				for (i in 0..._cfgReels) {
					var dist = Math.abs(i - mid) / (mid > 0 ? mid : 1);
					var amount = _cfgCurve * (0.55 + 0.45 * (1 - dist));
					curves.push(amount);
				}
				builder.curvePerReel(curves);
			} else {
				builder.curve(_cfgCurve);
				if (_cfgCurvePreset == "set" || _cfgCurvePreset == "set-lean") {
					builder.curveFocus(_cfgCurvePreset);
				}
			}
			if (_cfgCurveMode == "warp") {
				builder.curveMode("warp");
				// Room for art past the cell edge (pixi curved-reels-cascade recipe).
				builder.curveBleed(24);
			}
		}

		if (_cfgCascade) {
			builder.tumble({
				fall: {duration: 280, cellStagger: 40},
				dropIn: {duration: 480, cellStagger: 50}
			});
		}

		_reelSet = builder.build();

		var boardW:Float;
		var boardH:Float;
		if (_cfgHorizontal) {
			boardW = _cfgCells * symbolW + (_cfgCells - 1) * gapX;
			boardH = _cfgReels * symbolH + (_cfgReels - 1) * gapY;
		} else {
			boardW = _cfgReels * symbolW + (_cfgReels - 1) * gapX;
			boardH = _cfgMultiways
				? reelExtent
				: (_cfgCells * symbolH + (_cfgCells - 1) * gapY);
		}
		_reelSet.view.x = Math.max(STAGE_PAD, (STAGE_W - boardW) * 0.5);
		_reelSet.view.y = Math.max(STAGE_PAD, (STAGE_H - boardH) * 0.5);
		_stageHost.addChild(_reelSet.view);

		_frame.graphics.clear();
		_frame.graphics.lineStyle(2, 0xC9A45C, 0.45);
		_frame.graphics.drawRoundRect(
			_reelSet.view.x - 10,
			_reelSet.view.y - 10,
			boardW + 20,
			boardH + 20,
			14
		);
		_frame.x = 0;
		_frame.y = 0;

		wireEvents();
		_winPresenter = new WinPresenter(_reelSet, {
			stagger: 60,
			cycleGap: 350,
			dimLosersAlpha: 0.25
		});
		applyLiveTuning();
		applyStickyPinConfig();
	}

	function destroyHwBoard():Void {
		if (_hwBoard == null) return;
		if (_hwBoard.view.parent != null) _hwBoard.view.parent.removeChild(_hwBoard.view);
		_hwBoard.destroy();
		_hwBoard = null;
	}

	function rebuildHoldAndWinBoard():Void {
		var gap = 4.;
		// Strip fillers (A/K/…) are visible during spin; EmptySymbol stays for
		// rest/miss. Pure empty:3 + EmptySymbol looked like a dead cell.
		var stripIds = ["A", "K", "Q", "J", "7", "BAR"];
		_hwBoard = new HoldAndWinBuilder()
			.grid(HW_COLS, HW_ROWS)
			.cellSize(HW_CELL, {gap: gap})
			.respins(HOLD_DEFAULT_RESPINS)
			.bufferSymbols(3)
			.speedProfile({
				name: "normal",
				spinDelay: 0,
				spinSpeed: 42,
				stopDelay: 0,
				anticipationDelay: 0,
				// Same knob as the main ReelSet sample bounce slider.
				bounceDistance: _cfgBounce,
				bounceDuration: _cfgBounce > 0 ? 420 : 0,
				accelerationEase: "power2.in",
				decelerationEase: "power2.out",
				accelerationDuration: 220,
				minimumSpinTime: 520
			})
			.symbols(function(r) {
				r.registerClass(HW_COIN, BitmapReelSymbol, {bitmapDataMap: _atlas});
				for (id in stripIds) {
					r.registerClass(id, BitmapReelSymbol, {bitmapDataMap: _atlas});
				}
			})
			.weights([
				"A" => 2., "K" => 2., "Q" => 2., "J" => 2., "7" => 2., "BAR" => 1.,
				HW_COIN => 3., "empty" => 2.
			])
			.cellChrome(function(g, size) {
				g.beginFill(0x1A2A22, 1);
				g.lineStyle(1, 0xC9A45C, 0.35);
				g.drawRoundRect(0, 0, size, size, 8);
				g.endFill();
			})
			.clock(_clock)
			.build();

		var boardW = HW_COLS * HW_CELL + (HW_COLS - 1) * gap;
		var boardH = HW_ROWS * HW_CELL + (HW_ROWS - 1) * gap;
		_hwBoard.view.x = Math.max(STAGE_PAD, (STAGE_W - boardW) * 0.5);
		_hwBoard.view.y = Math.max(STAGE_PAD, (STAGE_H - boardH) * 0.5);
		_stageHost.addChild(_hwBoard.view);

		_frame.graphics.clear();
		_frame.graphics.lineStyle(2, 0xC9A45C, 0.45);
		_frame.graphics.drawRoundRect(
			_hwBoard.view.x - 10,
			_hwBoard.view.y - 10,
			boardW + 20,
			boardH + 20,
			14
		);

		_hwBoard.events.on("coin:locked", function(args) {
			var locked:Int = args[0].locked;
			var capacity:Int = args[0].capacity;
			emitStatus('Coin locked ($locked/$capacity) · ${_hwBoard.respinsLeft} left', true);
		});
		_hwBoard.events.on("feature:end", function(args) {
			var full:Bool = args[0].full;
			emitStatus(full ? "Board full — feature end" : "Respins done — feature end", false);
		});
		emitStatus("Hold&Win board — SPIN to enter (seed coins)", false);
	}

	function stickyPinCell():{reel:Int, cell:Int} {
		var r = Std.int(_cfgReels / 2);
		var cells = _reelSet != null ? _reelSet.getReel(r).visibleCells : _cfgCells;
		// True middle row for the *current* shape (not maxCells/2, which pins
		// the bottom after MultiWays shrinks from max → visible).
		var c = cells > 0 ? Std.int((cells - 1) / 2) : 0;
		return {reel: r, cell: c};
	}

	/** Sample sticky is the only WILD pin — find it even after movePin. */
	function findManagedStickyPin():Null<reels.pins.CellPin> {
		if (_reelSet == null) return null;
		if (_stickyReel >= 0 && _stickyCell >= 0) {
			var tracked = _reelSet.getPin(_stickyReel, _stickyCell);
			if (tracked != null && tracked.symbolId == "WILD") return tracked;
		}
		for (key in _reelSet.pins.keys()) {
			var p = _reelSet.pins.get(key);
			if (p != null && p.symbolId == "WILD") return p;
		}
		return null;
	}

	function clearManagedStickyPin():Void {
		if (_reelSet == null) {
			_stickyReel = -1;
			_stickyCell = -1;
			return;
		}
		// Unpin every WILD pin — tracking can lag behind movePin and leave orphans.
		var victims:Array<{reel:Int, cell:Int}> = [];
		for (key in _reelSet.pins.keys()) {
			var p = _reelSet.pins.get(key);
			if (p != null && p.symbolId == "WILD") {
				victims.push({reel: p.reel, cell: p.cell});
			}
		}
		for (v in victims) _reelSet.unpin(v.reel, v.cell);
		_stickyReel = -1;
		_stickyCell = -1;
	}

	function applyStickyPinConfig():Void {
		if (_reelSet == null) return;
		if (!_cfgStickyPin) {
			clearManagedStickyPin();
			return;
		}
		if (_reelSet.isSpinning) return;

		// Honor movePin: if a WILD pin already exists anywhere, keep IT —
		// never force geometric center on land (that spawned a second WILD).
		var live = findManagedStickyPin();
		if (live != null) {
			_stickyReel = live.reel;
			_stickyCell = live.cell;
			return;
		}

		var at = stickyPinCell();
		clearManagedStickyPin();
		_reelSet.pin(at.reel, at.cell, "WILD", {
			// Permanent so movePin → spin does not expire and re-home to center.
			turns: "permanent",
			originCell: at.cell,
			migration: "origin"
		});
		_stickyReel = at.reel;
		_stickyCell = at.cell;
	}

	function wireEvents():Void {
		if (_reelSet == null) return;
		_reelSet.events.on(ReelEvents.SPIN_START, function(_) {
			if (_winPresenter != null) _winPresenter.abort();
			if (_reelSet.spotlight.isActive) _reelSet.spotlight.hide();
		});
		_reelSet.events.on(ReelEvents.SPIN_REEL_LANDED, function(args) {
			_landedCount++;
			var i:Int = args[0];
			emitStatus('Landing… reel $i  (${_landedCount}/${_cfgReels})', true);
		});
		_reelSet.events.on(ReelEvents.SPIN_COMPLETE, function(_) {
			_spinning = false;
			_busy = false;
			applyStickyPinConfig();
			if (_cfgHoldRespin) {
				updateHoldFeatureAfterLand();
			} else {
				emitStatus('Round $_round done — press SPIN again', false);
			}
		});
	}

	function clearHoldFeature():Void {
		_heldReels = [];
		_respinsLeft = 0;
	}

	function columnHasAnchor(ids:Array<String>):Bool {
		for (id in ids) {
			if (id == HOLD_ANCHOR) return true;
		}
		return false;
	}

	function isHeldReel(index:Int):Bool {
		for (h in _heldReels) {
			if (h == index) return true;
		}
		return false;
	}

	/**
	 * Client-side hold-respin demo (not HoldAndWinBoard):
	 * columns with BAR lock; a hit resets the counter; a miss decrements;
	 * feature ends at 0 respins or all columns held.
	 */
	function updateHoldFeatureAfterLand():Void {
		if (_reelSet == null) return;
		var grid = _reelSet.getVisibleGrid();
		var hit = false;
		var nextHeld = _heldReels.copy();
		for (r in 0...grid.length) {
			if (isHeldReel(r)) continue;
			if (columnHasAnchor(grid[r])) {
				nextHeld.push(r);
				hit = true;
			}
		}
		nextHeld.sort(Reflect.compare);
		_heldReels = nextHeld;

		if (_heldReels.length == 0) {
			_respinsLeft = 0;
			emitStatus('Round $_round done — land BAR to start hold', false);
			return;
		}

		if (hit) {
			_respinsLeft = HOLD_DEFAULT_RESPINS;
		} else {
			_respinsLeft--;
		}

		if (_heldReels.length >= _cfgReels) {
			emitStatus('Hold full board [${_heldReels.join(",")}] — feature end', false);
			clearHoldFeature();
			return;
		}
		if (_respinsLeft <= 0) {
			emitStatus('Respins exhausted — feature end (held was [${nextHeld.join(",")}])', false);
			clearHoldFeature();
			return;
		}

		emitStatus(
			'Hold [${_heldReels.join(",")}] · ${_respinsLeft} respin(s) left — SPIN',
			false
		);
	}

	function doHoldAndWinSpin():Void {
		if (_hwBoard == null || _busy) return;
		if (_hwBoard.phase == Spinning) return;

		if (_hwBoard.phase == Idle) {
			var free = _hwBoard.freeCells;
			if (free.length == 0) return;
			var seeds:Array<HwCoin> = [];
			var n = 1 + Std.int(Math.random() * Math.min(2, free.length));
			var shuffled = free.copy();
			shuffled.sort(function(_, _) return Math.random() < 0.5 ? -1 : 1);
			for (i in 0...n) {
				var cell = shuffled[i];
				seeds.push({
					cell: cell,
					id: HW_COIN,
					data: {value: 10 + Std.int(Math.random() * 40)}
				});
			}
			_hwBoard.enter(seeds);
			emitStatus(
				'Entered ${seeds.length} coin(s) · ${_hwBoard.respinsLeft} respin(s) — SPIN',
				false
			);
			return;
		}

		// Active: respin free cells with mock hits.
		_busy = true;
		_spinning = true;
		_round++;
		var freeCells = _hwBoard.freeCells;
		var hits:Array<HwCoin> = [];
		if (freeCells.length > 0 && Math.random() < 0.65) {
			var hitCount = 1 + Std.int(Math.random() * Math.min(2, freeCells.length));
			var pool = freeCells.copy();
			pool.sort(function(_, _) return Math.random() < 0.5 ? -1 : 1);
			for (i in 0...hitCount) {
				hits.push({
					cell: pool[i],
					id: HW_COIN,
					data: {value: 5 + Std.int(Math.random() * 50)}
				});
			}
		}
		emitStatus(
			hits.length > 0
				? 'Respin round — ${hits.length} hit(s)…'
				: "Respin round — miss…",
			true
		);
		_hwBoard.respin(hits, function(result) {
			_busy = false;
			_spinning = false;
			if (result.done) {
				emitStatus(
					result.full
						? 'Full board after ${result.round} round(s)'
						: 'Feature end · ${result.respinsLeft} left · ${result.hits.length} hit(s)',
					false
				);
			} else {
				emitStatus(
					'Locked ${_hwBoard.lockedCoins.length}/${_hwBoard.capacity} · ${result.respinsLeft} left — SPIN',
					false
				);
			}
		});
	}

	function doSpin():Void {
		if (_spinning || _busy) return;
		if (_cfgHoldAndWinBoard) {
			doHoldAndWinSpin();
			return;
		}
		if (_reelSet == null) return;
		_spinning = true;
		_busy = true;
		_round++;
		_landedCount = 0;
		_pendingShape = null;
		var holdNote = (_cfgHoldRespin && _heldReels.length > 0)
			? ' hold [${_heldReels.join(",")}]'
			: "";
		emitStatus(
			_cfgCascade
				? 'Round $_round — cascade…'
				: 'Round $_round — spinning…$holdNote',
			true
		);

		if (_cfgHoldRespin && _heldReels.length > 0) {
			_reelSet.spin({holdReels: _heldReels.copy()}, function(_) {});
		} else {
			_reelSet.spin(function(_) {});
		}
		_reelSet.setStopDelays(buildStopDelays());

		if (_cfgMultiways) {
			_pendingShape = randomShape();
			_reelSet.setShape(_pendingShape);
			emitStatus('setShape([${_pendingShape.join(",")}])', true);
		}

		var delayMs = _cfgSpeed == "superTurbo" ? 80 : (_cfgSpeed == "turbo" ? 120 : 500);
		haxe.Timer.delay(function() {
			if (_reelSet == null || _reelSet.isDestroyed || !_spinning) return;
			var grid = _forceNext != null ? _forceNext : makeResultGrid();
			_forceNext = null;
			_reelSet.setResult(grid);
			emitStatus("setResult() arrived — landing…", true);
		}, delayMs);
	}

	/**
	 * Lab bridge: paint a forced grid now (idle) or queue for the next land.
	 * kind: "wild" (default) mid-row WILD; "big" 2×2 BIG at top-left.
	 */
	function doForceResult(?kind:String):Void {
		if (_reelSet == null || _cfgHoldAndWinBoard) return;
		var useBig = kind != null && (kind == "big" || kind == "BIG");
		if (useBig && _cfgMultiways) {
			emitStatus("forceResult(big) blocked — exclusive w/ MultiWays", false);
			return;
		}
		var grid = makeForceGrid(kind);
		if (_spinning || _busy) {
			_forceNext = grid;
			emitStatus('forceResult(${kind != null ? kind : "wild"}) queued', true);
			return;
		}
		paintForceGrid(grid);
		emitStatus('forceResult(${kind != null ? kind : "wild"}) applied', false);
	}

	function makeForceGrid(?kind:String):Array<ColumnTarget> {
		var useBig = kind != null && (kind == "big" || kind == "BIG");
		var out:Array<ColumnTarget> = [];
		var fillers = ["A", "K", "Q", "J", "7", "BAR"];
		for (c in 0..._cfgReels) {
			var cells = _pendingShape != null && c < _pendingShape.length
				? _pendingShape[c]
				: _cfgCells;
			var col:Array<String> = [];
			for (i in 0...cells) {
				col.push(fillers[(c + i) % fillers.length]);
			}
			if (cells > 0) {
				if (useBig && c == 0 && cells >= 2 && _cfgReels >= 2) {
					col[0] = "BIG";
				} else if (!useBig) {
					col[Std.int((cells - 1) / 2)] = "WILD";
				}
			}
			out.push({visible: col});
		}
		return out;
	}

	function paintForceGrid(grid:Array<ColumnTarget>):Void {
		if (_reelSet == null) return;
		var decorated = BigSymbolCoord.coordinate(
			grid,
			function(id) return id == "BIG" ? {reels: 2, cells: 2} : BigSymbolCoord.unit(),
			function(i) return _reelSet.getReel(i).visibleCells,
			_reelSet.getReel(0).bufferStart,
			_reelSet.getReel(0).bufferEnd
		);
		for (i in 0..._cfgReels) {
			if (i < decorated.length) {
				_reelSet.getReel(i).forceResult(decorated[i]);
			}
		}
	}

	function doSkip():Void {
		if (_cfgHoldAndWinBoard && _hwBoard != null) {
			if (!_spinning && !_busy) return;
			emitStatus("skip() — slamming board cells", true);
			_hwBoard.skip();
			return;
		}
		if (!_spinning || _reelSet == null) return;
		emitStatus("skipSpin() — slamming now", true);
		_reelSet.skipSpin();
	}

	/** Demo: middle-row payline via WinPresenter (no win math). */
	function doShowWins():Void {
		if (_spinning || _busy || _reelSet == null || _winPresenter == null) return;
		if (_winPresenter.isActive) {
			_winPresenter.abort();
			emitStatus("Wins aborted", false);
			return;
		}

		var cells:Array<SymbolPosition> = [];
		for (r in 0..._cfgReels) {
			var mid = Std.int((_reelSet.getReel(r).visibleCells - 1) / 2);
			cells.push({reelIndex: r, cellIndex: mid});
		}
		var wins:Array<Win> = [
			{cells: cells, value: 100, id: "mid-line"},
			{
				cells: [
					{reelIndex: 0, cellIndex: 0},
					{reelIndex: 1, cellIndex: 1},
					{reelIndex: 2, cellIndex: 2}
				],
				value: 40,
				id: "diag"
			}
		];

		_busy = true;
		emitStatus("WinPresenter.show — mid line + diag…", true);
		_winPresenter.show(wins, function() {
			_busy = false;
			emitStatus("Wins done — press SPIN or SHOW WINS", false);
		});
	}

	/** Fruit-machine nudge: push one WILD into the middle reel from the top. */
	function doNudge():Void {
		if (_spinning || _busy || _reelSet == null || _cfgHoldAndWinBoard) return;
		if (_cfgStickyPin) {
			emitStatus("Nudge blocked — unpin sticky first", false);
			return;
		}
		var mid = Std.int(_cfgReels / 2);
		_busy = true;
		emitStatus('nudge($mid) — WILD in…', true);
		_reelSet.nudge(mid, {
			distance: 1,
			direction: "forward",
			incoming: ["WILD"],
			duration: 280
		}, function(_) {
			_busy = false;
			emitStatus("Nudge done — press SPIN", false);
		});
	}

	/** Walking wild demo: advance sticky pin one cell down on its reel. */
	function doMovePin():Void {
		if (_spinning || _busy || _reelSet == null || !_cfgStickyPin) return;
		if (_stickyReel < 0 || _stickyCell < 0) applyStickyPinConfig();
		if (_stickyReel < 0 || _stickyCell < 0) return;
		if (_reelSet.getPin(_stickyReel, _stickyCell) == null) {
			applyStickyPinConfig();
			if (_reelSet.getPin(_stickyReel, _stickyCell) == null) return;
		}

		var reel = _reelSet.getReel(_stickyReel);
		var nextCell = _stickyCell + 1;
		if (nextCell >= reel.visibleCells) nextCell = 0;
		if (_reelSet.getPin(_stickyReel, nextCell) != null) {
			emitStatus("movePin blocked — destination occupied", false);
			return;
		}

		_busy = true;
		emitStatus('movePin(${_stickyReel},${_stickyCell}) → (${_stickyReel},${nextCell})…', true);
		var fromReel = _stickyReel;
		var fromCell = _stickyCell;
		_reelSet.movePin(
			{reel: fromReel, cell: fromCell},
			{reel: fromReel, cell: nextCell},
			{duration: 420, backfill: "A", easing: "power2.inOut"},
			function() {
				_stickyReel = fromReel;
				_stickyCell = nextCell;
				_busy = false;
				emitStatus("Pin moved — press SPIN or MOVE PIN", false);
			}
		);
	}

	function doRefill():Void {
		if (_spinning || _busy || _reelSet == null || !_cfgCascade) return;
		_busy = true;
		_landedCount = 0;
		emitStatus('refill() — ${_cfgRefillMode}…', true);

		var winners = [
			{reel: 0, cell: 1},
			{reel: 1, cell: 0},
			{reel: 2, cell: 2}
		];
		// Never treat the sticky cell as a winner — gravity would open a hole
		// under the pin and land a random symbol beneath the overlay.
		if (_cfgStickyPin && _stickyReel >= 0) {
			winners = [
				for (w in winners)
					if (!(w.reel == _stickyReel && w.cell == _stickyCell)) w
			];
		}
		var grid = makeResultGrid();
		function onDone(_:Dynamic):Void {
			_busy = false;
			applyStickyPinConfig();
			emitStatus("Refill done — press SPIN or REFILL", false);
		}
		if (_cfgRefillMode == "gravity-then-drop") {
			_reelSet.refill({
				winners: winners,
				grid: grid,
				mode: "gravity-then-drop",
				gravityHoldMs: _cfgGravityHoldMs,
				gravityHold: function() {
					emitStatus('gravity hold ${_cfgGravityHoldMs}ms…', true);
				}
			}, onDone);
		} else {
			_reelSet.refill({
				winners: winners,
				grid: grid,
				mode: "combined"
			}, onDone);
		}
	}

	function doRunCascade():Void {
		if (_spinning || _busy || _reelSet == null || !_cfgCascade) return;
		_busy = true;
		_landedCount = 0;
		emitStatus('runCascade() — ${_cfgRefillMode}…', true);

		var chainBudget = 2;
		function detectWinners(grid:Array<Array<String>>, chain:Int) {
			if (chain >= chainBudget) return [];
			var out = [];
			for (r in 0...grid.length) {
				if (grid[r].length > 1) {
					// Sticky pin must survive cascade — skip its cell.
					if (_cfgStickyPin && r == _stickyReel && _stickyCell == 1) continue;
					out.push({reel: r, cell: 1});
				}
			}
			return out;
		}
		function nextGrid(_, _, _) return makeResultGrid();
		function onCascade(stage:Int, winners:Array<Dynamic>) {
			emitStatus('cascade chain $stage — ${winners.length} winners', true);
		}
		function onDone(summary:Dynamic):Void {
			_busy = false;
			applyStickyPinConfig();
			emitStatus(
				'Cascade done — chains ${summary.chainLength}, winners ${summary.totalWinners}'
					+ (summary.wasSkipped ? " (skipped)" : ""),
				false
			);
		}

		if (_cfgRefillMode == "gravity-then-drop") {
			_reelSet.runCascade({
				detectWinners: detectWinners,
				nextGrid: nextGrid,
				pauseAfterDestroyMs: 180,
				destroyOptions: {durationMs: 220, staggerMs: 30},
				refillMode: "gravity-then-drop",
				gravityHoldMs: _cfgGravityHoldMs,
				gravityHold: function() {
					emitStatus('gravity hold ${_cfgGravityHoldMs}ms…', true);
				},
				onCascade: onCascade
			}, onDone);
		} else {
			_reelSet.runCascade({
				detectWinners: detectWinners,
				nextGrid: nextGrid,
				pauseAfterDestroyMs: 180,
				destroyOptions: {durationMs: 220, staggerMs: 30},
				refillMode: "combined",
				onCascade: onCascade
			}, onDone);
		}
	}

	function randomShape():Array<Int> {
		var out:Array<Int> = [];
		var span = _cfgMwMax - _cfgMwMin + 1;
		for (_ in 0..._cfgReels) {
			out.push(_cfgMwMin + Std.int(Math.random() * span));
		}
		return out;
	}

	function makeResultGrid():Array<ColumnTarget> {
		var pool = [
			["A", "A", "7", "K"],
			["K", "Q", "K", "J"],
			["7", "BAR", "7", "A"],
			["J", "J", "Q", "BAR"],
			["BAR", "A", "K", "7"]
		];
		var out:Array<ColumnTarget> = [];
		for (c in 0..._cfgReels) {
			var cells = _pendingShape != null && c < _pendingShape.length
				? _pendingShape[c]
				: _cfgCells;
			var src = pool[(c + _round) % pool.length];
			var col:Array<String> = [];
			for (i in 0...cells) {
				col.push(src[i % src.length]);
			}
			var shift = cells > 0 ? _round % cells : 0;
			var rotated = col.slice(shift).concat(col.slice(0, shift));
			// Hold demo: bias a free column toward BAR every few rounds so
			// the feature can continue without a full HoldAndWinBoard.
			if (
				_cfgHoldRespin
				&& !isHeldReel(c)
				&& cells > 0
				&& (_round + c) % 3 == 0
			) {
				rotated[Std.int(cells / 2)] = HOLD_ANCHOR;
			}
			// Spine-on-curve smoke: keep a mid-cell WILD after every land.
			if (_cfgSpineWild && cells > 0) {
				rotated[Std.int((cells - 1) / 2)] = "WILD";
			}
			out.push({visible: rotated});
		}
		return out;
	}

	function emitStatus(msg:String, spinning:Bool):Void {
		if (_statusCb != null) _statusCb(msg, spinning);
	}

	function clampInt(v:Int, lo:Int, hi:Int):Int {
		if (v < lo) return lo;
		if (v > hi) return hi;
		return v;
	}

	function clampFloat(v:Float, lo:Float, hi:Float):Float {
		if (v < lo) return lo;
		if (v > hi) return hi;
		return v;
	}

	function buildAtlas():Map<String, BitmapData> {
		var map = new Map<String, BitmapData>();
		for (id in IDS) {
			map.set(id, drawSymbol(id, COLORS.get(id)));
		}
		return map;
	}

	function drawSymbol(id:String, color:Int):BitmapData {
		var w = 120;
		var h = 110;
		var bd = new BitmapData(w, h, true, 0x00000000);
		var s = new Sprite();
		// Fill the cell edge-to-edge so curved quads do not show felt cracks.
		s.graphics.beginFill(color);
		s.graphics.drawRoundRect(0, 0, w, h, 10);
		s.graphics.endFill();
		s.graphics.lineStyle(2, 0xFFFFFF, 0.28);
		s.graphics.drawRoundRect(1, 1, w - 2, h - 2, 9);

		var tf = new TextField();
		tf.defaultTextFormat = new TextFormat(
			"_sans",
			id.length > 2 ? 28 : 42,
			0x0F172A,
			true,
			null, null, null, null,
			TextFormatAlign.CENTER
		);
		tf.width = w;
		tf.height = 60;
		tf.y = (h - 50) * 0.5;
		tf.text = id;
		tf.selectable = false;
		tf.mouseEnabled = false;
		s.addChild(tf);

		bd.draw(s);
		return bd;
	}
}
