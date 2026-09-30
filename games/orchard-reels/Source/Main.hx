package;

import openfl.Lib;
import openfl.display.Application;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.ui.Keyboard;
import reels.ReelSet;
import reels.ReelSetBuilder;
import reels.clock.FrameClock;
import reels.config.SpeedPresets;
import reels.config.SpeedProfile;
import reels.config.WinTypes.SymbolPosition;
import reels.config.WinTypes.Win;
import reels.events.ReelEvents;
import reels.frame.ColumnTarget;
import reels.symbols.BitmapReelSymbol;
import reels.wins.WinPresenter;

/**
 * Mini-title consumer of haxe-reels — HUD + mock setResult, no RGS.
 *
 *   cd haxe-reels/games/orchard-reels && openfl test html5
 */
class Main extends Application {
	static inline var STAGE_W = 960;
	static inline var STAGE_H = 640;
	static inline var REELS = 5;
	static inline var CELLS = 3;
	static inline var SYM_W = 110.;
	static inline var SYM_H = 100.;
	static inline var GAP_X = 4.;
	static inline var GAP_Y = 0.;
	static inline var BOARD_PAD = 18.;
	static inline var START_CREDIT = 1000.;
	static inline var BET_MIN = 1.;
	static inline var BET_MAX = 50.;
	static inline var BET_STEP = 1.;

	static final IDS = ["A", "K", "Q", "J", "7", "BAR", "WILD"];
	static final COLORS:Map<String, Int> = [
		"A" => 0xE74C3C,
		"K" => 0x9B59B6,
		"Q" => 0x3498DB,
		"J" => 0x1ABC9C,
		"7" => 0xF1C40F,
		"BAR" => 0xE67E22,
		"WILD" => 0x2ECC71
	];

	var _root:Sprite;
	var _stageHost:Sprite;
	var _frame:Sprite;
	var _hud:Sprite;
	var _reelSet:Null<ReelSet>;
	var _winPresenter:Null<WinPresenter>;
	var _clock:FrameClock;
	var _atlas:Map<String, BitmapData>;

	var _credit:Float = START_CREDIT;
	var _bet:Float = 5.;
	var _round:Int = 0;
	var _spinning:Bool = false;
	var _busy:Bool = false;
	var _pendingWin:Bool = false;
	var _pendingWinId:String = "";

	var _tfTitle:TextField;
	var _tfCredit:TextField;
	var _tfBet:TextField;
	var _tfStatus:TextField;
	var _btnSpin:Sprite;
	var _btnSkip:Sprite;
	var _btnBetMinus:Sprite;
	var _btnBetPlus:Sprite;

	public function new() {
		super();
	}

	override function onWindowCreate():Void {
		_root = new Sprite();
		Lib.current.addChild(_root);

		drawFelt();
		_stageHost = new Sprite();
		_root.addChild(_stageHost);
		_frame = new Sprite();
		_root.addChild(_frame);
		_hud = new Sprite();
		_root.addChild(_hud);

		_clock = new FrameClock();
		_atlas = buildAtlas();
		buildHud();
		buildReelSet();
		bindKeys();
		setStatus("Welcome — press SPIN", false);
		refreshHud();
	}

	function drawFelt():Void {
		_root.graphics.clear();
		_root.graphics.beginFill(0x0A1812);
		_root.graphics.drawRect(0, 0, STAGE_W, STAGE_H);
		_root.graphics.endFill();
		// Soft vignette bands
		_root.graphics.beginFill(0x0F241A, 0.55);
		_root.graphics.drawRoundRect(24, 72, STAGE_W - 48, STAGE_H - 168, 18);
		_root.graphics.endFill();
	}

	function buildHud():Void {
		_tfTitle = makeLabel(28, 0xE2C48A, true);
		_tfTitle.width = STAGE_W;
		_tfTitle.height = 40;
		_tfTitle.y = 18;
		_tfTitle.text = "ORCHARD REELS";
		_hud.addChild(_tfTitle);

		_tfCredit = makeLabel(16, 0xE8EBE9, false);
		_tfCredit.width = 280;
		_tfCredit.height = 28;
		_tfCredit.x = 36;
		_tfCredit.y = STAGE_H - 78;
		_hud.addChild(_tfCredit);

		_tfBet = makeLabel(16, 0xE2C48A, false);
		_tfBet.width = 120;
		_tfBet.height = 28;
		_tfBet.x = 340;
		_tfBet.y = STAGE_H - 78;
		_hud.addChild(_tfBet);

		_tfStatus = makeLabel(14, 0x8A958E, false);
		_tfStatus.width = STAGE_W - 72;
		_tfStatus.height = 24;
		_tfStatus.x = 36;
		_tfStatus.y = STAGE_H - 44;
		_hud.addChild(_tfStatus);

		_btnBetMinus = makeButton("−", 44, 40, 0x222A26, 0xE2C48A);
		_btnBetMinus.x = 460;
		_btnBetMinus.y = STAGE_H - 84;
		_btnBetMinus.addEventListener(MouseEvent.CLICK, function(_) changeBet(-BET_STEP));
		_hud.addChild(_btnBetMinus);

		_btnBetPlus = makeButton("+", 44, 40, 0x222A26, 0xE2C48A);
		_btnBetPlus.x = 512;
		_btnBetPlus.y = STAGE_H - 84;
		_btnBetPlus.addEventListener(MouseEvent.CLICK, function(_) changeBet(BET_STEP));
		_hud.addChild(_btnBetPlus);

		_btnSkip = makeButton("SKIP", 100, 48, 0x171C19, 0xC9A45C);
		_btnSkip.x = STAGE_W - 250;
		_btnSkip.y = STAGE_H - 88;
		_btnSkip.addEventListener(MouseEvent.CLICK, function(_) doSkip());
		_hud.addChild(_btnSkip);

		_btnSpin = makeButton("SPIN", 120, 48, 0xC9A45C, 0x1A1408);
		_btnSpin.x = STAGE_W - 140;
		_btnSpin.y = STAGE_H - 88;
		_btnSpin.addEventListener(MouseEvent.CLICK, function(_) doSpin());
		_hud.addChild(_btnSpin);
	}

	function buildReelSet():Void {
		if (_winPresenter != null) {
			_winPresenter.destroy();
			_winPresenter = null;
		}
		if (_reelSet != null) {
			if (_reelSet.view.parent != null) _reelSet.view.parent.removeChild(_reelSet.view);
			_reelSet.destroy();
			_reelSet = null;
		}

		var bounce = 48.;
		var profile = withBounce(SpeedPresets.NORMAL, bounce);

		_reelSet = new ReelSetBuilder()
			.reels(REELS)
			.visibleCells(CELLS)
			.symbolSize(SYM_W, SYM_H)
			.symbolGap(GAP_X, GAP_Y)
			.bufferSymbols(1)
			.clock(_clock)
			.symbols(function(r) {
				for (id in IDS) {
					r.registerClass(id, BitmapReelSymbol, {bitmapDataMap: _atlas});
				}
			})
			.weights([
				"A" => 20, "K" => 20, "Q" => 20,
				"J" => 20, "7" => 10, "BAR" => 8, "WILD" => 4
			])
			.speed("normal", profile)
			.initialSpeed("normal")
			.build();

		var boardW = REELS * SYM_W + (REELS - 1) * GAP_X;
		var boardH = CELLS * SYM_H + (CELLS - 1) * GAP_Y;
		_reelSet.view.x = (STAGE_W - boardW) * 0.5;
		_reelSet.view.y = 96;
		_stageHost.addChild(_reelSet.view);

		_frame.graphics.clear();
		_frame.graphics.lineStyle(2, 0xC9A45C, 0.5);
		_frame.graphics.drawRoundRect(
			_reelSet.view.x - BOARD_PAD,
			_reelSet.view.y - BOARD_PAD,
			boardW + BOARD_PAD * 2,
			boardH + BOARD_PAD * 2,
			14
		);

		_winPresenter = new WinPresenter(_reelSet, {
			stagger: 50,
			cycleGap: 280,
			dimLosersAlpha: 0.28
		});

		_reelSet.events.on(ReelEvents.SPIN_START, function(_) {
			if (_winPresenter != null) _winPresenter.abort();
			if (_reelSet.spotlight.isActive) _reelSet.spotlight.hide();
		});
		_reelSet.events.on(ReelEvents.SPIN_COMPLETE, function(_) {
			_spinning = false;
			onLand();
		});
	}

	function withBounce(base:SpeedProfile, bounce:Float):SpeedProfile {
		return {
			name: base.name,
			spinDelay: base.spinDelay,
			spinSpeed: base.spinSpeed,
			stopDelay: base.stopDelay,
			anticipationDelay: base.anticipationDelay,
			bounceDistance: bounce,
			bounceDuration: bounce > 0 ? 380 : 0,
			accelerationEase: base.accelerationEase,
			decelerationEase: base.decelerationEase,
			accelerationDuration: base.accelerationDuration,
			minimumSpinTime: base.minimumSpinTime
		};
	}

	function doSpin():Void {
		if (_spinning || _busy || _reelSet == null) return;
		if (_credit < _bet) {
			setStatus("Not enough credit — lower bet", false);
			return;
		}
		_credit -= _bet;
		_round++;
		_spinning = true;
		_busy = true;
		_pendingWin = false;
		_pendingWinId = "";
		refreshHud();
		setStatus('Round $_round — spinning…', true);

		_reelSet.spin(function(_) {});
		_reelSet.setStopDelays([0., 100., 200., 300., 400.]);

		var outcome = mockOutcome();
		_pendingWin = outcome.isWin;
		_pendingWinId = outcome.winId;
		haxe.Timer.delay(function() {
			if (_reelSet == null || _reelSet.isDestroyed || !_spinning) return;
			_reelSet.setResult(outcome.grid);
			setStatus("Result in — landing…", true);
		}, 420);
	}

	function doSkip():Void {
		if (!_spinning || _reelSet == null) return;
		setStatus("Skip — slamming…", true);
		_reelSet.skipSpin();
	}

	function onLand():Void {
		if (_pendingWin && _winPresenter != null) {
			var mid = Std.int(CELLS / 2);
			var cells:Array<SymbolPosition> = [];
			for (r in 0...REELS) cells.push({reelIndex: r, cellIndex: mid});
			var win:Win = {
				cells: cells,
				value: _bet * 10,
				id: _pendingWinId
			};
			_busy = true;
			setStatus('WIN ${_pendingWinId} ×10 — celebrating…', true);
			_winPresenter.show([win], function() {
				_credit += win.value;
				_busy = false;
				refreshHud();
				setStatus('Won ${Std.int(win.value)} — press SPIN', false);
			});
			return;
		}
		_busy = false;
		refreshHud();
		setStatus('Round $_round done — press SPIN', false);
	}

	function mockOutcome():{grid:Array<ColumnTarget>, isWin:Bool, winId:String} {
		var forceWin = Math.random() < 0.28;
		var winId = Math.random() < 0.45 ? "7" : (Math.random() < 0.5 ? "WILD" : "BAR");
		var fillers = ["A", "K", "Q", "J", "7", "BAR"];
		var mid = Std.int(CELLS / 2);
		var out:Array<ColumnTarget> = [];
		for (c in 0...REELS) {
			var col:Array<String> = [];
			for (i in 0...CELLS) {
				if (forceWin && i == mid) {
					col.push(winId);
				} else {
					col.push(fillers[Std.int(Math.random() * fillers.length)]);
				}
			}
			// Avoid accidental mid-line on non-win spins
			if (!forceWin && c > 0) {
				var prev = out[0].visible[mid];
				if (col[mid] == prev) {
					col[mid] = fillers[(fillers.indexOf(col[mid]) + 1) % fillers.length];
				}
			}
			out.push({visible: col});
		}
		if (forceWin) {
			for (c in 0...REELS) out[c].visible[mid] = winId;
		}
		return {grid: out, isWin: forceWin, winId: winId};
	}

	function changeBet(delta:Float):Void {
		if (_spinning || _busy) return;
		_bet = clamp(_bet + delta, BET_MIN, BET_MAX);
		refreshHud();
	}

	function refreshHud():Void {
		_tfCredit.text = 'Credit  ${Std.int(_credit)}';
		_tfBet.text = 'Bet  ${Std.int(_bet)}';
		_btnSpin.mouseEnabled = !_spinning && !_busy;
		_btnSpin.alpha = (_spinning || _busy) ? 0.45 : 1;
		_btnSkip.mouseEnabled = _spinning;
		_btnSkip.alpha = _spinning ? 1 : 0.35;
		_btnBetMinus.mouseEnabled = !_spinning && !_busy;
		_btnBetPlus.mouseEnabled = !_spinning && !_busy;
	}

	function setStatus(msg:String, busy:Bool):Void {
		_tfStatus.text = msg;
		_tfStatus.textColor = busy ? 0xFFC878 : 0x8A958E;
		refreshHud();
	}

	function bindKeys():Void {
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent) {
			if (e.keyCode == Keyboard.SPACE) {
				e.preventDefault();
				doSpin();
			} else if (e.keyCode == Keyboard.S) {
				doSkip();
			}
		});
	}

	function makeLabel(size:Int, color:Int, bold:Bool):TextField {
		var tf = new TextField();
		tf.defaultTextFormat = new TextFormat("_sans", size, color, bold, null, null, null, null, TextFormatAlign.LEFT);
		tf.selectable = false;
		tf.mouseEnabled = false;
		return tf;
	}

	function makeButton(label:String, w:Float, h:Float, fill:Int, ink:Int):Sprite {
		var s = new Sprite();
		s.graphics.beginFill(fill);
		s.graphics.lineStyle(1, 0xC9A45C, 0.35);
		s.graphics.drawRoundRect(0, 0, w, h, 10);
		s.graphics.endFill();
		s.buttonMode = true;
		s.mouseChildren = false;
		var tf = new TextField();
		tf.defaultTextFormat = new TextFormat("_sans", 15, ink, true, null, null, null, null, TextFormatAlign.CENTER);
		tf.width = w;
		tf.height = h;
		tf.y = (h - 22) * 0.5;
		tf.text = label;
		tf.selectable = false;
		tf.mouseEnabled = false;
		s.addChild(tf);
		return s;
	}

	function buildAtlas():Map<String, BitmapData> {
		var map = new Map<String, BitmapData>();
		for (id in IDS) map.set(id, drawSymbol(id, COLORS.get(id)));
		return map;
	}

	function drawSymbol(id:String, color:Int):BitmapData {
		var w = Std.int(SYM_W);
		var h = Std.int(SYM_H);
		var bd = new BitmapData(w, h, true, 0x00000000);
		var s = new Sprite();
		s.graphics.beginFill(color);
		s.graphics.drawRoundRect(0, 0, w, h, 12);
		s.graphics.endFill();
		s.graphics.lineStyle(2, 0xFFFFFF, 0.18);
		s.graphics.drawRoundRect(3, 3, w - 6, h - 6, 10);
		var tf = new TextField();
		tf.defaultTextFormat = new TextFormat("_sans", 28, 0x101412, true, null, null, null, null, TextFormatAlign.CENTER);
		tf.width = w;
		tf.height = 40;
		tf.y = (h - 36) * 0.5;
		tf.text = id;
		tf.selectable = false;
		s.addChild(tf);
		bd.draw(s);
		return bd;
	}

	function clamp(v:Float, lo:Float, hi:Float):Float {
		if (v < lo) return lo;
		if (v > hi) return hi;
		return v;
	}
}
