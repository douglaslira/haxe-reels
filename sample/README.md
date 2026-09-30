# Sample — haxe-reels

Demo interativo: canvas OpenFL + painel de config.
Bridge: `window.HaxeReelsDemo`.

**Convenção:** toda API parametrizável nova no engine deve aparecer no painel
(não ficar hardcode em `Main.hx`).

## Rodar

```bash
cd sample
openfl test html5
```

Ou:

```bash
openfl build html5
cd Export/html5/bin && python3 -m http.server 8765
# http://127.0.0.1:8765/
```

> Precisa de rede no primeiro load (Tailwind CDN + Google Fonts).

## Layout

- **Desktop (lg+):** stage à esquerda, aside (~400px) à direita
- **Mobile:** stage em cima (~55vh), painel embaixo com ações sticky
- Painel: seções **Board / Spin / Cascade** + footer fixo (status, SPIN/SKIP, snippet)

## Controles

| Controle | Efeito |
|----------|--------|
| Reels 3–5 | reconstrói o `ReelSet` |
| Visible cells 3–4 | reconstrói |
| Direction forward/reverse | reconstrói (default de todos os reels) |
| Alternate reels | `directionPerReel` F/R/F/R… (rebuild) |
| Bounce distance | reconstrói com bounce custom |
| Curve preset | Flat / Single / Per-reel / Set-lean / Set (`curveFocus`) |
| Curve amount | amount do preset (desligado em Flat) |
| Sticky pin | `pin(mid, mid, "WILD", { turns: "permanent" })` |
| Hold respin | `spin({ holdReels })` — BAR locks column |
| Hold&Win board | 3×3 `HoldAndWinBuilder` — exclusive w/ cascade / MW / hold respin |
| Move pin | `movePin(from, to)` walking wild (só com sticky) |
| Show wins | `new WinPresenter(reelSet).show([{ cells: midRow }, …])` |
| Spine WILD (mock) | `SpineReelSymbol` + `MockSpineFactory` (sem lib Spine) |
| Speed normal/turbo/superTurbo | `setSpeed` ao vivo |
| Stop delay stagger | `setStopDelays` ao vivo |
| Enable tumble | reconstrói com `.tumble()` |
| Refill mode | `combined` ou `gravity-then-drop` |
| Gravity hold | `gravityHoldMs` (só two-stage) |
| SPIN / SKIP | spin + slam |
| REFILL / CASCADE | só com tumble ligado |

Durante spin/refill, controles de rebuild ficam desabilitados.

## Atalhos

| Tecla | Ação |
|-------|------|
| `Space` | SPIN (quando idle) |
| `S` | SKIP (quando busy) |

Ignorados se o foco estiver em input/select.

## Arquitetura

- Template Lime: `templates/html5/template/index.html`
- UI JS: `assets/sample-ui.js`
- Stage Haxe: `Source/Main.hx` (só reels + bridge)

```js
window.HaxeReelsDemo.configure({
  reels, visibleCells, direction, alternateDirections,
  speed, stopDelay, bounceDistance,
  cascade, refillMode, gravityHoldMs
})
window.HaxeReelsDemo.spin()
window.HaxeReelsDemo.skip()
window.HaxeReelsDemo.refill()
window.HaxeReelsDemo.runCascade()
```
