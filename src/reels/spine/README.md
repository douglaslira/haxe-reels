# reels.spine (optional)

Spine adapter for haxe-reels. **Not a Spine runtime** — you inject
`ISpineFactory` / `ISpineInstance` from your OpenFL Spine binding.

Core packages (`reels.core`, `reels.symbols.BitmapReelSymbol`, …) never import
this folder. Only register `SpineReelSymbol` when the game needs skeletons.

## Vocabulary (ADR 011)

| Role | Default anim | Loop |
|------|--------------|------|
| idle | `idle` | yes |
| landing | `landing` | no |
| win | `win` | no |
| out | `disintegration` | no |
| blur | `blur` | yes |

Missing animations are silent no-ops. Override per symbolId via `animations`.

## Usage

```haxe
import reels.spine.SpineReelSymbol;
import reels.spine.ISpineFactory;

builder.symbols(function(r) {
  r.register("WILD", function() {
    return new SpineReelSymbol({
      factory: myOpenFlSpineFactory, // implements ISpineFactory
      spineMap: [
        "WILD" => { skeleton: "wild", atlas: "wild", skin: "gold" }
      ],
      // animations: ["WILD" => ["idle" => "ide"]],
    });
  });
});
```

## Mock (tests / sample)

`MockSpineFactory` + `MockSpineInstance` implement the same interfaces without
a Spine library. One-shots complete on `update(0)`. Sample toggle
**Spine WILD (mock)** registers WILD through this mock.

## Curve

- `curveMode('symbol')` (default): each Spine cell gets an **affine contain-fit**
  (uniform scale + center on the projected quad). OpenFL cannot keystone a
  live Spine skeleton without render-to-texture; Bitmap symbols still use
  `PerspectiveCell`. Sticky pin overlays and `movePin` flights use the same
  affine path under symbol mode.
- `curveMode('warp')`: the reel mesh warps the whole strip (including Spine
  draw). Per-symbol `applyCellQuad` is skipped; pin/spotlight overlays stay flat.
