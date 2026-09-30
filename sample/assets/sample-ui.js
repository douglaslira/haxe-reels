(function () {
	"use strict";

	var form = document.getElementById("demo-form");
	var statusEl = document.getElementById("demo-status");
	var snippetEl = document.getElementById("demo-snippet");
	var btnSpin = document.getElementById("btn-spin");
	var btnSkip = document.getElementById("btn-skip");
	var btnRefill = document.getElementById("btn-refill");
	var btnCascade = document.getElementById("btn-cascade");
	var btnMovePin = document.getElementById("btn-move-pin");
	var btnShowWins = document.getElementById("btn-show-wins");
	var btnNudge = document.getElementById("btn-nudge");
	var btnForceWild = document.getElementById("btn-force-wild");
	var btnForceBig = document.getElementById("btn-force-big");
	var cascadeOpts = document.getElementById("cascade-opts");
	var cascadeActions = document.getElementById("cascade-actions");
	var pinActions = document.getElementById("pin-actions");
	var holdWrap = document.getElementById("hold-wrap");
	var rebuildCtrls = document.querySelectorAll(".rebuild-ctrl");
	var busy = false;

	function readConfig() {
		var dir = form.querySelector('input[name="direction"]:checked');
		var cascadeEl = document.getElementById("cfg-cascade");
		var altEl = document.getElementById("cfg-alt-dirs");
		var modeEl = document.getElementById("cfg-refill-mode");
		var holdEl = document.getElementById("cfg-gravity-hold");
		var curveEl = document.getElementById("cfg-curve");
		var curvePresetEl = document.getElementById("cfg-curve-preset");
		var curveModeEl = document.getElementById("cfg-curve-mode");
		var mwEl = document.getElementById("cfg-multiways");
		var horizEl = document.getElementById("cfg-horizontal");
		var stickyEl = document.getElementById("cfg-sticky-pin");
		var spineEl = document.getElementById("cfg-spine-wild");
		var holdRespinEl = document.getElementById("cfg-hold-respin");
		var hwBoardEl = document.getElementById("cfg-hold-win-board");
		var preset = curvePresetEl ? curvePresetEl.value : "flat";
		var curveMode = curveModeEl ? curveModeEl.value : "symbol";
		var curve = curveEl ? Number(curveEl.value) / 100 : 0;
		if (preset === "flat") {
			curve = 0;
			curveMode = "symbol";
			if (curveEl) curveEl.value = 0;
			if (curveModeEl) curveModeEl.value = "symbol";
		} else if (curve <= 0) {
			curve = 0.4;
			if (curveEl) curveEl.value = 40;
		}
		var cascade = cascadeEl ? cascadeEl.checked : false;
		var holdRespin = holdRespinEl ? holdRespinEl.checked : false;
		var holdAndWinBoard = hwBoardEl ? hwBoardEl.checked : false;
		var multiways = mwEl ? mwEl.checked : false;
		var horizontal = horizEl ? horizEl.checked : false;
		if (holdAndWinBoard) {
			cascade = false;
			holdRespin = false;
			multiways = false;
			horizontal = false;
		}
		if (holdRespin) {
			cascade = false;
			holdAndWinBoard = false;
		}
		if (cascade) {
			holdRespin = false;
			holdAndWinBoard = false;
		}
		if (multiways) {
			holdAndWinBoard = false;
			horizontal = false;
		}
		if (horizontal) multiways = false;
		return {
			reels: Number(document.getElementById("cfg-reels").value),
			visibleCells: Number(document.getElementById("cfg-cells").value),
			direction: dir ? dir.value : "forward",
			alternateDirections: altEl ? altEl.checked : false,
			speed: document.getElementById("cfg-speed").value,
			stopDelay: Number(document.getElementById("cfg-delay").value),
			bounceDistance: Number(document.getElementById("cfg-bounce").value),
			curve: curve,
			curvePreset: preset,
			curveMode: curveMode,
			cascade: cascade,
			refillMode: modeEl ? modeEl.value : "gravity-then-drop",
			gravityHoldMs: holdEl ? Number(holdEl.value) : 280,
			multiways: multiways,
			horizontal: horizontal,
			stickyPin: stickyEl ? stickyEl.checked : false,
			spineWild: spineEl ? spineEl.checked : false,
			holdRespin: holdRespin,
			holdAndWinBoard: holdAndWinBoard
		};
	}

	function syncCascadeUi(cfg) {
		var on = !!cfg.cascade;
		if (cascadeOpts) cascadeOpts.classList.toggle("hidden", !on);
		if (cascadeActions) {
			cascadeActions.classList.toggle("hidden", !on);
			cascadeActions.classList.toggle("flex", on);
		}
		var holdLabel = document.getElementById("val-hold");
		if (holdLabel) holdLabel.textContent = cfg.gravityHoldMs + " ms";
		var twoStage = cfg.refillMode === "gravity-then-drop";
		if (holdWrap) holdWrap.classList.toggle("hidden", !on || !twoStage);
		var holdEl = document.getElementById("cfg-gravity-hold");
		if (holdEl) holdEl.disabled = !on || !twoStage || busy;
		var modeEl = document.getElementById("cfg-refill-mode");
		if (modeEl) modeEl.disabled = !on || busy;
	}

	function syncPinUi(cfg) {
		var on = !!cfg.stickyPin;
		if (pinActions) {
			pinActions.classList.toggle("hidden", !on);
			pinActions.classList.toggle("flex", on);
		}
		if (btnMovePin) btnMovePin.disabled = busy || !on;
	}

	function updateLabels(cfg) {
		document.getElementById("val-reels").textContent = String(cfg.reels);
		document.getElementById("val-cells").textContent = String(cfg.visibleCells);
		document.getElementById("val-delay").textContent = cfg.stopDelay + " ms";
		document.getElementById("val-bounce").textContent = cfg.bounceDistance + " px";
		var curveLabel = document.getElementById("val-curve");
		if (curveLabel) curveLabel.textContent = String(Math.round((cfg.curve || 0) * 100) / 100);
		var curveAmountEl = document.getElementById("cfg-curve");
		var curveModeEl = document.getElementById("cfg-curve-mode");
		var flat = cfg.curvePreset === "flat";
		if (curveAmountEl) curveAmountEl.disabled = busy || flat;
		if (curveModeEl) curveModeEl.disabled = busy || flat;
		syncCascadeUi(cfg);

		var tumbleLine = cfg.cascade ? "  .tumble({ fall, dropIn })\n" : "";
		var altLine = cfg.alternateDirections
			? "  .directionPerReel([F, R, F, …])\n"
			: "";
		var curveLine = "";
		if (cfg.curvePreset && cfg.curvePreset !== "flat" && cfg.curve > 0) {
			if (cfg.curvePreset === "per-reel") {
				curveLine = "  .curvePerReel([… mid peak " + cfg.curve + "])\n";
			} else if (cfg.curvePreset === "set" || cfg.curvePreset === "set-lean") {
				curveLine =
					"  .curve(" + cfg.curve + ")\n" +
					"  .curveFocus('" + cfg.curvePreset + "')\n";
			} else {
				curveLine = "  .curve(" + cfg.curve + ")\n";
			}
			if (cfg.curveMode === "warp") {
				curveLine += "  .curveMode('warp')\n  .curveBleed(24)\n";
			}
		}
		var stickyLine = cfg.stickyPin
			? "\n// after build / land:\n//   reelSet.pin(mid, mid, \"WILD\", { turns: \"permanent\" })\n//   reelSet.movePin(from, to, { duration: 420 })\n"
			: "";
		var holdLine = cfg.holdRespin
			? "\n// respin:\n//   reelSet.spin({ holdReels: lockedColumns }, …)\n"
			: "";
		var hwLine = cfg.holdAndWinBoard
			? "new HoldAndWinBuilder()\n" +
				"  .grid(3, 3).cellSize(88, { gap: 4 })\n" +
				"  .symbols((r) => r.registerClass('COIN', BitmapReelSymbol, …))\n" +
				"  .respins(3).clock(clock).build();\n" +
				"// board.enter(seeds); board.respin(hits, onDone);\n"
			: "";
		var winsLine =
			"\n// after land:\n//   new WinPresenter(reelSet).show([{ cells: midRow }])\n";
		var spineLine = cfg.spineWild
			? "\n// register WILD:\n//   new SpineReelSymbol({ factory, spineMap })\n"
			: "";
		var cellsLine = cfg.multiways
			? "  .multiways({ minCells: 2, maxCells: 4, reelExtent })\n" +
				"  .pinMigrationDuration(300)\n"
			: "  .visibleCells(" + cfg.visibleCells + ")\n";
		var orientLine = cfg.horizontal
			? "  .orientation(Horizontal)\n"
			: "";
		var refillLine = cfg.cascade
			? "\n// refill / runCascade\n//   mode: \"" + cfg.refillMode + "\"" +
				(cfg.refillMode === "gravity-then-drop"
					? "\n//   gravityHoldMs: " + cfg.gravityHoldMs
					: "")
			: "";

		if (snippetEl) {
			if (cfg.holdAndWinBoard) {
				snippetEl.textContent = hwLine;
			} else {
				snippetEl.textContent =
					"new ReelSetBuilder()\n" +
					"  .reels(" + cfg.reels + ")\n" +
					cellsLine +
					orientLine +
					"  .direction('" + cfg.direction + "')\n" +
					altLine +
					curveLine +
					tumbleLine +
					"  .speed('" + cfg.speed + "', …)\n" +
					"  .build()" +
					stickyLine +
					holdLine +
					spineLine +
					winsLine +
					refillLine;
			}
		}
		syncPinUi(cfg);
	}

	function inferStatusState(msg, spinning) {
		if (spinning) return "busy";
		if (!msg) return "idle";
		var m = msg.toLowerCase();
		if (m.indexOf("done") !== -1 || m.indexOf("ready") !== -1) return "done";
		if (m.indexOf("waiting") !== -1) return "idle";
		return "idle";
	}

	function setStatus(msg, spinning) {
		statusEl.textContent = msg;
		var state = inferStatusState(msg, spinning === true);
		statusEl.setAttribute("data-state", state);
	}

	function setBusy(nextBusy) {
		busy = !!nextBusy;
		btnSpin.disabled = busy;
		btnSkip.disabled = !busy;
		if (btnShowWins) btnShowWins.disabled = busy;
		if (btnNudge) btnNudge.disabled = busy;

		var cfg = readConfig();
		var cascadeOn = cfg.cascade;
		if (btnRefill) btnRefill.disabled = busy || !cascadeOn;
		if (btnCascade) btnCascade.disabled = busy || !cascadeOn;
		rebuildCtrls.forEach(function (el) {
			el.disabled = busy;
		});
		syncCascadeUi(cfg);
		syncPinUi(cfg);
	}

	function apply() {
		var demo = window.HaxeReelsDemo;
		if (!demo || typeof demo.configure !== "function") return;
		var cascadeEl = document.getElementById("cfg-cascade");
		var holdRespinEl = document.getElementById("cfg-hold-respin");
		var hwBoardEl = document.getElementById("cfg-hold-win-board");
		// Exclusive in the DOM so labels match what configure receives.
		if (cascadeEl && holdRespinEl && cascadeEl.checked && holdRespinEl.checked) {
			cascadeEl.checked = false;
		}
		if (hwBoardEl && hwBoardEl.checked) {
			if (cascadeEl) cascadeEl.checked = false;
			if (holdRespinEl) holdRespinEl.checked = false;
			var mwEl = document.getElementById("cfg-multiways");
			if (mwEl) mwEl.checked = false;
			var horizEl = document.getElementById("cfg-horizontal");
			if (horizEl) horizEl.checked = false;
		}
		var mwEl2 = document.getElementById("cfg-multiways");
		var horizEl2 = document.getElementById("cfg-horizontal");
		if (mwEl2 && horizEl2 && mwEl2.checked && horizEl2.checked) {
			// Last-wins: prefer the control that just changed is hard; clear MW when both.
			horizEl2.checked = true;
			mwEl2.checked = false;
		}
		var cfg = readConfig();
		if (cascadeEl) cascadeEl.checked = !!cfg.cascade;
		if (holdRespinEl) holdRespinEl.checked = !!cfg.holdRespin;
		if (hwBoardEl) hwBoardEl.checked = !!cfg.holdAndWinBoard;
		if (mwEl2) mwEl2.checked = !!cfg.multiways;
		if (horizEl2) horizEl2.checked = !!cfg.horizontal;
		updateLabels(cfg);
		demo.configure(cfg);
	}

	function isTypingTarget(el) {
		if (!el || !el.tagName) return false;
		var tag = el.tagName.toLowerCase();
		return tag === "input" || tag === "select" || tag === "textarea" || el.isContentEditable;
	}

	function bindShortcuts() {
		document.addEventListener("keydown", function (e) {
			if (e.metaKey || e.ctrlKey || e.altKey) return;
			if (isTypingTarget(e.target)) return;
			var demo = window.HaxeReelsDemo;
			if (!demo) return;

			if (e.code === "Space") {
				e.preventDefault();
				if (!busy && demo.spin && !btnSpin.disabled) demo.spin();
				return;
			}
			if (e.key === "s" || e.key === "S") {
				e.preventDefault();
				if (busy && demo.skip && !btnSkip.disabled) demo.skip();
			}
		});
	}

	function bind() {
		var demo = window.HaxeReelsDemo;
		if (!demo || typeof demo.configure !== "function") {
			setStatus("Waiting for engine…", false);
			return false;
		}

		if (typeof demo.onStatus === "function") {
			demo.onStatus(function (msg, spinning) {
				setStatus(msg, spinning);
				if (typeof spinning === "boolean") setBusy(spinning);
			});
		}

		form.addEventListener("input", apply);
		form.addEventListener("change", apply);

		btnSpin.addEventListener("click", function () {
			if (demo.spin) demo.spin();
		});
		btnSkip.addEventListener("click", function () {
			if (demo.skip) demo.skip();
		});
		if (btnRefill) {
			btnRefill.addEventListener("click", function () {
				if (demo.refill) demo.refill();
			});
		}
		if (btnCascade) {
			btnCascade.addEventListener("click", function () {
				if (demo.runCascade) demo.runCascade();
			});
		}
		if (btnMovePin) {
			btnMovePin.addEventListener("click", function () {
				if (demo.movePin) demo.movePin();
			});
		}
		if (btnShowWins) {
			btnShowWins.addEventListener("click", function () {
				if (demo.showWins) demo.showWins();
			});
		}
		if (btnNudge) {
			btnNudge.addEventListener("click", function () {
				if (demo.nudge) demo.nudge();
			});
		}
		if (btnForceWild) {
			btnForceWild.addEventListener("click", function () {
				if (demo.forceResult) demo.forceResult("wild");
			});
		}
		if (btnForceBig) {
			btnForceBig.addEventListener("click", function () {
				if (demo.forceResult) demo.forceResult("big");
			});
		}

		bindShortcuts();

		var cfg = demo.getConfig ? demo.getConfig() : readConfig();
		if (cfg) {
			document.getElementById("cfg-reels").value = cfg.reels;
			document.getElementById("cfg-cells").value = cfg.visibleCells;
			document.getElementById("cfg-speed").value = cfg.speed;
			document.getElementById("cfg-delay").value = cfg.stopDelay;
			document.getElementById("cfg-bounce").value = cfg.bounceDistance;
			var curveEl = document.getElementById("cfg-curve");
			if (curveEl && cfg.curve != null) curveEl.value = Math.round(cfg.curve * 100);
			var curvePresetEl = document.getElementById("cfg-curve-preset");
			if (curvePresetEl && cfg.curvePreset) curvePresetEl.value = cfg.curvePreset;
			var curveModeEl = document.getElementById("cfg-curve-mode");
			if (curveModeEl && cfg.curveMode) curveModeEl.value = cfg.curveMode;
			var cascadeEl = document.getElementById("cfg-cascade");
			if (cascadeEl) cascadeEl.checked = !!cfg.cascade;
			var mwEl = document.getElementById("cfg-multiways");
			if (mwEl) mwEl.checked = !!cfg.multiways;
			var horizEl = document.getElementById("cfg-horizontal");
			if (horizEl) horizEl.checked = !!cfg.horizontal;
			var stickyEl = document.getElementById("cfg-sticky-pin");
			if (stickyEl) stickyEl.checked = !!cfg.stickyPin;
			var spineEl = document.getElementById("cfg-spine-wild");
			if (spineEl) spineEl.checked = !!cfg.spineWild;
			var holdRespinEl = document.getElementById("cfg-hold-respin");
			if (holdRespinEl) holdRespinEl.checked = !!cfg.holdRespin;
			var hwBoardEl = document.getElementById("cfg-hold-win-board");
			if (hwBoardEl) hwBoardEl.checked = !!cfg.holdAndWinBoard;
			var altEl = document.getElementById("cfg-alt-dirs");
			if (altEl) altEl.checked = !!cfg.alternateDirections;
			var modeEl = document.getElementById("cfg-refill-mode");
			if (modeEl && cfg.refillMode) modeEl.value = cfg.refillMode;
			var holdEl = document.getElementById("cfg-gravity-hold");
			if (holdEl && cfg.gravityHoldMs != null) holdEl.value = cfg.gravityHoldMs;
			var radio = form.querySelector('input[name="direction"][value="' + cfg.direction + '"]');
			if (radio) radio.checked = true;
			updateLabels(readConfig());
		}

		setStatus("Ready — press SPIN", false);
		setBusy(false);
		apply();
		return true;
	}

	var tries = 0;
	function waitForBridge() {
		if (bind()) return;
		tries++;
		if (tries > 200) {
			setStatus("Engine failed to expose HaxeReelsDemo", false);
			return;
		}
		setTimeout(waitForBridge, 50);
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", waitForBridge);
	} else {
		waitForBridge();
	}
})();
