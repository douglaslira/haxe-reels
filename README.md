# haxe-reels

**Standalone reel / slot strip engine for [OpenFL](https://www.openfl.org/) + [Haxe](https://haxe.org/).**

Handles strip motion, land timing, pooling, pins, cascade/tumble, MultiWays reshape, optional Hold & Win boards, and win *presentation* — not game math.

| | |
|---|---|
| License | [MIT](LICENSE) |
| Version | `0.1.0` ([haxelib.json](haxelib.json)) |
| Classpath | `src/` → package `reels.*` |
| Targets | OpenFL (HTML5 lab tested); headless via `FakeClock` + `--interp` |
| Inspired by | [pixi-reels](https://github.com/schmooky/pixi-reels) — see [NOTICE](NOTICE) |

Repository: [github.com/douglaslira/haxe-reels](https://github.com/douglaslira/haxe-reels)

---

## What this library is

`haxe-reels` is the **view + motion** layer of a slot:

1. You build a `ReelSet` (or `HoldAndWinBoard`) with symbols, speeds, geometry.
2. You call `spin()`.
3. When your **server / RGS / mock** has the outcome, you call `setResult(grid)`.
4. The engine decelerates, lands, bounces, emits events, and optionally runs cascade / win highlight.

It does **not** decide wins, RTP, balances, or RNG for money. Strip fill weights (`.weights`) are only for **decorative** mid-spin symbols, not certified outcomes.

```
┌─────────────┐     spin()      ┌──────────────┐
│  Your game  │ ──────────────► │   ReelSet    │
│  / RGS host │ ◄────────────── │  (OpenFL)    │
└─────────────┘   setResult()   └──────────────┘
       │                              │
       │  paytable / wallet / auth    │  events, WinPresenter
       ▼                              ▼
```

---

## Requirements

- Haxe 4.x
- [OpenFL](https://www.openfl.org/) + Lime (`haxelib install openfl lime`)
- For unit tests: `haxelib install utest`

---

## Install

```bash
# From GitHub
haxelib git haxe-reels https://github.com/douglaslira/haxe-reels

# Local checkout (dev)
haxelib dev haxe-reels /path/to/haxe-reels
```

In Lime/OpenFL `project.xml`:

```xml
<haxelib name="haxe-reels" />
<haxelib name="openfl" />
<haxelib name="lime" />
```

Inside this repo’s samples, the engine is linked via `<source path="../../src" />` instead of haxelib so you can iterate without publishing.

---

## Quick start

```haxe
import reels.ReelSetBuilder;
import reels.config.SpeedPresets;
import reels.events.ReelEvents;
import reels.symbols.BitmapReelSymbol;
import openfl.display.BitmapData;

var cherry:BitmapData = /* your atlas frame */;
var seven:BitmapData = /* ... */;

var reelSet = new ReelSetBuilder()
  .reels(5)
  .visibleCells(3)
  .symbolSize(140, 140)
  .symbolGap(0, 4)
  .liveClock() // binds OpenFL Stage ENTER_FRAME
  .symbols(function(r) {
    r.registerClass("cherry", BitmapReelSymbol, {bitmapData: cherry});
    r.registerClass("seven", BitmapReelSymbol, {bitmapData: seven});
  })
  .weights(["cherry" => 40, "seven" => 10]) // strip filler only
  .speed("normal", SpeedPresets.NORMAL)
  .speed("turbo", SpeedPresets.TURBO)
  .speed("superTurbo", SpeedPresets.SUPER_TURBO)
  .initialSpeed("normal")
  .build();

stage.addChild(reelSet.view);

reelSet.events.on(ReelEvents.SPIN_COMPLETE, function(args) {
  // args[0] is SpinResult when emitted from the controller path
});

reelSet.spin(function(result) {
  // result.symbols : Array<Array<String>>  visible grid
  // result.wasSkipped : Bool
  // result.duration : Float (ms)
});

// When the authoritative outcome arrives:
reelSet.setResult([
  {visible: ["cherry", "cherry", "seven"]},
  {visible: ["seven", "cherry", "cherry"]},
  {visible: ["cherry", "seven", "cherry"]},
  {visible: ["seven", "seven", "cherry"]},
  {visible: ["cherry", "cherry", "cherry"]}
]);
```

**Contract:** always `spin` → then `setResult` (or supply the grid through your own bridge). Calling `setResult` without an active spin is a no-op for land.

---

## Architecture overview

| Layer | Package | Role |
|---|---|---|
| Facade | `reels.ReelSet`, `reels.ReelSetBuilder` | Public API most games use |
| Core strip | `reels.core.*` | `Reel`, motion, curve, mask, stop queue |
| Spin FSM | `reels.spin.*` | Start → Spin → Anticipation → Stop (+ cascade phases) |
| Frame / land | `reels.frame.*` | `ColumnTarget`, random strip provider |
| Symbols | `reels.symbols.*` | Bitmap, headless, big symbols, stubs |
| Cascade | `reels.cascade.*` | Tumble geometry, `refill`, `runCascade` |
| Pins | `reels.pins.*` | Sticky / migrating overlays |
| Wins | `reels.wins.*` | `WinPresenter` (highlight only) |
| Board | `reels.board.*` | `HoldAndWinBoard` (grid of 1×1 strips) |
| Spine (optional) | `reels.spine.*` | Adapter interfaces + mock — **not** a Spine runtime |
| Clock | `reels.clock.*` | `FrameClock` (Stage) / `FakeClock` (tests) |
| Events | `reels.events.*` | Colon-namespaced strings + `EventEmitter` |

---

## ReelSetBuilder reference

Fluent builder. Call `.build()` once; rebuild if you change geometry that needs a new instance.

### Geometry & travel

| Method | Meaning |
|---|---|
| `reels(n)` | Number of strips (default 5) |
| `visibleCells(n)` | Visible cells per reel (default 3) |
| `symbolSize(w, h)` | Cell width × height in px |
| `symbolGap(x, y)` | Gaps between cells on cross / main axes |
| `bufferSymbols(n)` / `bufferSymbolsRange(start, end)` | Off-screen strip padding |
| `orientation(Vertical\|Horizontal)` | Travel axis: Y vs X ([Orientation](src/reels/core/Orientation.hx)) |
| `direction(Forward\|Reverse)` | Default travel sense for all reels |
| `directionPerReel([...])` | Per-reel forward/reverse (e.g. alternate) |

### Clock, symbols, RNG

| Method | Meaning |
|---|---|
| `liveClock()` | Use Stage frame clock |
| `clock(IFrameClock)` | Inject custom clock (`FakeClock` in tests) |
| `symbols(registry -> Void)` | Register factories (`register` / `registerClass`) |
| `weights(Map<String,Float>)` | Mid-spin decorative strip distribution |
| `rng(() -> Float)` | Inject `[0,1)` RNG for strip fill (default `Math.random`) |
| `initialFrame(ColumnTarget[])` | Starting visible grid |

### Speed

| Method | Meaning |
|---|---|
| `speed(name, SpeedProfile)` | Register a named profile |
| `initialSpeed(name)` | Active profile at build |

Built-ins in `SpeedPresets`: `NORMAL`, `TURBO`, `SUPER_TURBO` — fields include `spinSpeed`, `stopDelay`, `anticipationDelay`, `bounceDistance`, `bounceDuration`, easings, `minimumSpinTime`.

### Cascade / tumble

| Method | Meaning |
|---|---|
| `tumble(?TumbleConfig)` | Enable tumble spin path (Fall → Place → DropIn) |

```haxe
.tumble({
  fall: { duration: 280 },
  dropIn: { duration: 480 }
  // gravity: optional string key for algorithm variants
})
```

### MultiWays

| Method | Meaning |
|---|---|
| `multiways({ minCells, maxCells, reelExtent })` | Fixed reel box; cell count varies per spin |
| `adjustDuration(ms)` | Tween duration when reshaping cell size |
| `pinMigrationDuration(ms)` | Alias for pin overlay reshape tween |
| `setShape(cellsPerReel)` on `ReelSet` | Apply a new cells-per-reel shape after build |

### Curve & mask

| Method | Meaning |
|---|---|
| `curve(ReelCurveInput)` | Single curve for the set |
| `curvePerReel([...])` | Per-reel curves |
| `curveFocus(CurveFocus)` / `curveMode(CurveMode)` | How curve is applied (set vs symbol, lean, …) |
| `curveBleed(px)` | Extra mask bleed for curved strips |
| `maskStrategy(MaskStrategy)` | Custom clip strategy (rect / shared rect) |

---

## ReelSet runtime API

### Spin lifecycle

| Method | Role |
|---|---|
| `spin(?SpinOptions, ?onComplete)` | Start strips. Options: `holdReels`, `timeoutMs` |
| `setResult(ColumnTarget[])` | Authoritative land grid → begin stop sequence |
| `setAnticipation(indices)` | Mark reels that should tease before stop |
| `setStopDelays(msPerReel)` | Stagger stop start times |
| `skipSpin()` | Round-aware skip (boost + slam semantics) |
| `slamStop(?SlamOptions)` | Force hard land now |
| `setSpeed(name)` | Switch active `SpeedProfile` |

```haxe
typedef ColumnTarget = {
  visible: Array<String>,
  ?bufferStart: Array<Null<String>>,
  ?bufferEnd: Array<Null<String>>
};

typedef SpinResult = {
  symbols: Array<Array<String>>,
  wasSkipped: Bool,
  duration: Float
};

typedef SpinOptions = {
  ?holdReels: Array<Int>, // columns that stay locked this respin
  ?timeoutMs: Float
};
```

### Inspection & layout

| Method | Role |
|---|---|
| `view` | Root `DisplayObject` to add to the stage |
| `getReel(i)` | Access a single `Reel` |
| `getVisibleGrid()` | Current visible symbol ids |
| `getCellBounds(reel, cell)` | Stage-local rectangle of a cell |
| `getSymbolFootprint(...)` | Size metadata for big symbols |
| `events` | `EventEmitter` |
| `destroy()` | Teardown clock listeners, pools, children |

### Pins (sticky / walking wilds)

| Method | Role |
|---|---|
| `pin(reel, cell, symbolId, ?options)` | Overlay that stays across spins (`turns: "permanent"` etc.) |
| `unpin(reel, cell)` | Remove overlay |
| `movePin(from, to, ?opts)` | Animate pin to another cell |
| `getPin(reel, cell)` | Read pin state |

### Cascade / destroy / refill

| Method | Role |
|---|---|
| `refill(RefillOptions, onComplete)` | Moment B after wins (combined or gravity-then-drop) |
| `destroySymbols(opts, onComplete)` | Animate destruction of winning cells |
| `runCascade(opts, onComplete)` | Higher-level destroy → refill chain |

```haxe
reelSet.refill({
  winners: [{ reel: 0, cell: 1 }, { reel: 1, cell: 1 }],
  grid: nextColumnTargets,
  mode: "combined" // or "gravity-then-drop"
  // gravityHoldMs, gravityHold, onGravityComplete for two-stage
}, function(result) { /* ... */ });
```

### Nudge

| Method | Role |
|---|---|
| `nudge(...)` | Step a reel by N cells with tween |
| `skipNudge(?reel)` | Cancel in-flight nudge |

---

## Symbols

### Registration

```haxe
.symbols(function(r) {
  // Class + constructor options (Bitmap)
  r.registerClass("cherry", BitmapReelSymbol, { bitmapData: cherryBd });

  // Factory (headless / custom)
  r.register("blank", function() return new HeadlessSymbol("blank"));

  // Meta: big symbol footprint + unmask
  r.setMeta("BIG", {
    size: { reels: 2, cells: 2 },
    unmask: true
  });
})
```

| Type | Package | Notes |
|---|---|---|
| `BitmapReelSymbol` | `reels.symbols` | OpenFL `BitmapData` cell |
| `HeadlessSymbol` / `HeadlessView` | `reels.symbols` | No display — unit tests |
| `EmptySymbol` | `reels.symbols` | Hold & Win empty cell |
| `OccupiedStub` | `reels.symbols` | Placeholder under a big symbol footprint |
| `SpineReelSymbol` | `reels.spine` | Needs your `ISpineFactory` (or `MockSpineFactory`) |

**Big symbols:** declare `SymbolSize` `{ reels, cells }` in meta. The engine expands footprint across reels×cells and fills secondary cells with stubs. Horizonal orientation uses the same footprint axes (reels × cells), not a naive single-axis resize.

---

## Events (`ReelEvents`)

Subscribe via `reelSet.events.on(name, fn)` / `once` / `off`.

### Spin

`spin:start` · `spin:allStarted` · `spin:stopping` · `spin:reelLanded` · `spin:allLanded` · `spin:complete`

### Skip / speed / phase

`skip:requested` · `skip:completed` · `skip:boosted` · `speed:changed` · `phase:enter` · `phase:exit`

### Cascade

`cascade:fall:start|end` · `cascade:place:end` · `cascade:dropIn:start|end` · `cascade:gravity:start|end` · `cascade:destroy:start|end` · `cascade:chain:start|end`

### MultiWays / pins / wins / nudge

`shape:changed` · `adjust:start|complete` · `pin:placed|expired|migrated|moved|overlayCreated|overlayDestroyed` · `spotlight:start|end` · `win:start|group|symbol|end` · `nudge:start|complete|cancelled`

Constants live in `reels.events.ReelEvents` — prefer those over raw strings.

---

## Win presentation (not win detection)

```haxe
import reels.wins.WinPresenter;
import reels.config.WinTypes.Win;

var presenter = new WinPresenter(reelSet /*, { dimAlpha, stagger, cycles, ... }*/);

presenter.show([
  {
    cells: [
      { reelIndex: 0, cellIndex: 1 },
      { reelIndex: 1, cellIndex: 1 },
      { reelIndex: 2, cellIndex: 1 }
    ],
    value: 100,
    id: "line-2"
  }
], function() {
  // finished highlight cycles
});
```

`WinPresenter` dims non-winners, pulses winners, emits `win:*` events. **Your game** still owns paylines / ways / scatter math.

---

## Hold & Win board

Separate builder for a **W×H grid of independent 1×1 strips** (classic Hold & Win / coin respin presentation). Value logic stays in the game layer.

```haxe
import reels.board.HoldAndWinBuilder;

var board = new HoldAndWinBuilder()
  .grid(3, 3)
  .cellSize(72, { gap: 4 })
  .symbols(function(r) { /* register coin symbols */ })
  .weights(["coin" => 1, "empty" => 4])
  .build();

stage.addChild(board.view);
```

Exclusive with some sample lab modes (cascade / MultiWays / hold-respin toggles) — see the lab panel.

---

## Cascade geometry (tumble)

Two moments:

1. **Initial tumble spin** — builder `.tumble(...)`; `setResult` drives Fall → Place → DropIn.
2. **Refill after wins** — `refill` / `runCascade` with winner cells + next grid.

```haxe
import reels.cascade.TumbleAlgorithm;

// Pure geometry helper (no display):
var offsets = TumbleAlgorithm.computeDropOffsets(5, [], { initial: true });
```

Modes for refill:

- `combined` — gravity + drop-in in one stage (default)
- `gravity-then-drop` — pause (`gravityHoldMs`) between stages

---

## Vertical vs horizontal

```haxe
import reels.core.Orientation;
import reels.core.Direction;

new ReelSetBuilder()
  .orientation(Horizontal) // strips travel on X; reels stack on Y
  .direction(Forward)      // or Reverse
  .directionPerReel([Forward, Reverse, Forward, Reverse, Forward])
  // ...
```

Viewport and big-symbol sizing respect orientation; do not assume “main = Y” in consumer layout code — use `getCellBounds` / `ReelAxis` if you draw overlays.

---

## Spine (optional)

`reels.spine` is an **adapter**, not a runtime. Inject `ISpineFactory` / `ISpineInstance` from your OpenFL Spine binding, or use `MockSpineFactory` in tests/sample.

Default animation roles: `idle`, `landing`, `win`, `disintegration` (out), `blur`. Missing clips are silent no-ops. Details: [src/reels/spine/README.md](src/reels/spine/README.md).

---

## Headless tests

```bash
make test
# → haxe tests.hxml  (utest + openfl/lime, --interp)
```

```haxe
import reels.testing.TestHarness;

var h = TestHarness.createTestReelSet({ reels: 5, visibleCells: 3 });
h.spinAndLand([
  { visible: ["a", "a", "a"] },
  { visible: ["b", "b", "b"] },
  { visible: ["a", "b", "a"] },
  { visible: ["b", "a", "b"] },
  { visible: ["a", "a", "b"] }
], function(result) {
  TestHarness.expectGrid(h.reelSet, /* same grid */);
});
h.destroy();
```

`FakeClock` advances virtual time without a Stage — spin phases, cascade, pins, MultiWays, Hold & Win, etc. are covered under `test/tests/`.

```bash
make compile   # typecheck reels.* with --no-output
```

---

## Samples in this repo

### Lab — `sample/`

Interactive API playground: OpenFL canvas + HTML/Tailwind panel (`window.HaxeReelsDemo` bridge).

```bash
cd sample
openfl test html5
```

Useful for: reel count, cells, direction / alternate, bounce, curve presets, sticky pin, hold respin, Hold & Win 3×3, WinPresenter, mock Spine, speed, stop delays, tumble + refill.

Full control table: [sample/README.md](sample/README.md).

### Consumer game — `games/orchard-reels/`

Minimal **standalone** slot-style app: HUD, fake credit, mock `setResult`, `WinPresenter`. No casino/RGS coupling.

```bash
cd games/orchard-reels
openfl test html5
```

Details: [games/orchard-reels/README.md](games/orchard-reels/README.md).

---

## Scope

### In (engine)

- Builder + `ReelSet` facade
- Phases: start / spin / anticipation / stop (+ cascade phases)
- `StopFrameQueue` land, object pooling
- Bitmap + headless symbols, big symbols, occupied stubs
- Skip / slam, speed profiles, stop stagger, anticipation
- Events + `FakeClock` harness
- Cascade / tumble + refill modes
- `directionPerReel`, horizontal orientation
- Reel curve + mask strategies
- MultiWays reshape (`setShape` / adjust tweens)
- Pins (sticky / move / migrate)
- `WinPresenter` + spotlight hooks
- Hold & Win board builder
- Optional Spine adapter interfaces + mock

### Out (your game / RGS)

- Win detection, paytables, ways/lines math
- Certified outcome RNG / wallet / debit-credit
- Audio, full HUD frameworks, bonus free-spin state machines
- Spine runtime itself (bring your own binding)
- Casino host, auth, JWT, datacenter deploy scripts

---

## Integration checklist (production consumer)

1. Add `<haxelib name="haxe-reels" />` (or monorepo `source` path).
2. Register real symbol art (`BitmapReelSymbol` / Spine).
3. `spin()` only after **server-side debit** (never trust the client for money).
4. Map RGS grid → `ColumnTarget[]` → `setResult`.
5. Run paytable on the **server**; client may mirror for UX only.
6. Use `WinPresenter` (or your VFX) from `spin:complete` / your win list.
7. Call `destroy()` when leaving the game scene.
8. Prefer `FakeClock` tests for any new motion-sensitive feature.

---

## Project layout

```
haxe-reels/
├── src/reels/          # library
├── test/               # utest + TestHarness
├── sample/             # interactive lab
├── games/orchard-reels/# standalone consumer demo
├── haxelib.json
├── tests.hxml
├── Makefile
├── LICENSE             # MIT © Douglas Lira
└── NOTICE              # pixi-reels attribution
```

---

## License

MIT © Douglas Lira — see [LICENSE](LICENSE).

Portions of architecture and motion contracts are adapted from [pixi-reels](https://github.com/schmooky/pixi-reels) (MIT); see [NOTICE](NOTICE).
