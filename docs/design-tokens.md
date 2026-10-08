# Design tokens

The Flutter tokens are a deterministic translation of the raft-ui design-system
CSS. Nothing in `packages/raft_ui/lib/src/tokens/*.g.dart` comes from a
screenshot or a pixel sample. The browser-computed snapshots in
`docs/theme-tokens/*.json` are kept only as a verification oracle.

## Flow

```
tool/design-source/                       (vendored, sha256-pinned in manifest.json)
  raft-ui-0.5.27/foundation.css           raw ramps + theme blocks
  raft-ui-0.5.27/styles.css               Tailwind @theme / @theme inline aliases
  raft-ui-0.5.27/fonts.css                per-theme font stacks
  tailwindcss-4.2.2/theme.css             Tailwind default scale
  raft-web-26f77ef/index.css              Web product @theme overrides, :root.dark
  component-roles.css                     AUTHORED: recipe roles as plain CSS
        │
        ▼  tool/gen-tokens  (python3, stdlib only)
packages/raft_ui/lib/src/tokens/
  primitive_colors.g.dart   RaftPrimitiveColors   tier 1
  semantic_colors.g.dart    RaftSemanticColors    tier 2 (×3 themes)
  product_colors.g.dart     RaftProductColors     tier 2b (×3 themes)
  component_colors.g.dart   RaftComponentColors   tier 3 (×3 themes)
  shadows.g.dart            RaftCssShadow, RaftShadow, RaftThemeShadows, RaftProductShadows
  metrics.g.dart            RaftThemeMetrics (×3), RaftScale, RaftTextStep
  token_set.g.dart          RaftThemeId, RaftTokenSet
  tokens.dart               barrel (hand-written), exported by package:raft_ui
        │
        ▼
RaftTokens (ThemeExtension, theme.dart) ── RaftTokens.of(context)
```

`raftTheme(family, dark:)` installs `RaftTokens.theme(family, dark:)`. From a
`RaftTokens` you get:

| Getter | Type | Content |
| --- | --- | --- |
| `tokenSet` | `RaftTokenSet` | every tier below for the active theme |
| `semantic` | `RaftSemanticColors` | `foreground`, `layerCanvas`, `ink8`, `primary400`, `primaryHover`, `dangerSoft`, ... |
| `product` | `RaftProductColors` | `brutalCyan`, `statusBusy`, `codeSurface`, ... |
| `components` | `RaftComponentColors` | `buttonDefaultFill`, `taskSectionFill`, `switchThumb`, ... |
| `themeShadows` | `RaftThemeShadows` | `xs` … `xl` as `RaftShadow` |
| `metrics` | `RaftThemeMetrics` | field / card-title metrics, font stacks, bundled font families |
| `colors` | `Map<String, Color>` | compatibility view keyed by CSS name without `--` (all four colour tiers) |

`RaftPrimitiveColors`, `RaftScale` and `RaftProductShadows` are theme-invariant
static classes.

## Regenerate

```
tool/gen-tokens            # rewrite the .g.dart files
tool/gen-tokens --check    # exit 1 if they are stale (also enforced by tool/tests/test_gen_tokens.py)
tool/gen-tokens --oracle   # per-token comparison with docs/theme-tokens/*.json
```

To move to a new raft-ui / product revision, refresh the vendored copies (this
rewrites `tool/design-source/manifest.json`), then regenerate and run the tests:

```
tool/gen-tokens --import-sources --raft-ui <raft-ui package dir> --raft-source <raft-source checkout>
tool/gen-tokens
```

`--raft-source` also locates `node_modules/.pnpm/tailwindcss@*/` unless
`--tailwind <dir>` is given. Never hand-edit vendored files: the generator
refuses to run when their hashes differ from the manifest. Update the version
directory names in `SOURCES` (top of `tool/gen-tokens`) when versions change.

## Mapping rules

**Cascade.** The Web app sets `data-theme` and the `.light`/`.dark` class on
`<html>` (`AppThemeProvider.tsx`), so every block applies to the same element
and custom properties resolve against the merged declarations:

| Theme | Merged blocks (later wins) |
| --- | --- |
| `brutal` | Tailwind @theme → raw ramps → fonts root → `:where(:root),[data-theme=brutal]` |
| `elegantLight` | brutal chain → fonts elegant → `[data-theme=elegant]` |
| `elegantDark` | elegantLight chain → `[data-theme=elegant].dark` → product `:root.dark` |

Tailwind @theme merge order is tailwind default → raft-ui `@theme` → raft-ui
`@theme inline` → product `index.css @theme` (product wins; e.g.
`--color-brutal-cyan` is `#27CCF3`, not `--color-brutal-cyan-400`). The
generator asserts the `@media (prefers-color-scheme: dark)` fallback block is
identical to the `.dark` block.

`var()` is substituted textually (with fallbacks) after the merge, exactly as
CSS computes custom properties. Consequence: a formula declared only in the
root block uses the overriding theme's inputs, e.g. elegant-dark
`primaryActive = color-mix(in srgb-linear, primary-400 84%, <dark ink>)`.

**Names.** `--foreground-muted` → `foregroundMuted`, `--ink-8` → `ink8`,
`--color-brutal-yellow-50` → `RaftPrimitiveColors.brutalYellow50`,
`--color-brutal-cyan` → `RaftProductColors.brutalCyan`,
`--theme-shadow-md` → `RaftThemeShadows.md`, `--shadow-brutal-sm` →
`RaftProductShadows.shadowBrutalSm`. `toCssMap()` on each colour class returns
the CSS names (without `--`).

**Tiers.** Every colour variable of the three foundation theme blocks becomes a
`RaftSemanticColors` field (107 fields; each `.g.dart` entry carries the source
declaration as a comment and the field doc says which blocks declare it). The
ink ramp (`ink`, `ink2` … `ink40`) is theme-scoped in the source, so it lives
in the semantic tier, not in the primitives. `RaftProductColors` holds the
`--color-*` Tailwind aliases from raft-ui and the product (15 fields).
`RaftComponentColors` holds roles defined in
`tool/design-source/component-roles.css`: each is the CSS that a raft-ui recipe
class resolves to (for example `hover:bg-[oklch(0.31_0.006_106.42)]` becomes
`--button-default-hover: oklch(0.31 0.006 106.42)`), with a source citation.
Add a role there, never as a Dart literal.

**Colour conversion** (`parse_color` in `tool/gen-tokens`):

1. `oklch(L C H / A)` → OKLab → LMS (cubed) → XYZ-D65 → linear sRGB using
   the CSS Color 4 sample-code matrices. `#hex`, `rgb()`, `rgba()`,
   `transparent`, `black`, `white` are also accepted.
2. `color-mix()` supports `srgb-linear`, `srgb`, `oklab` and `oklch` (shorter
   hue; a powerless hue takes the other colour's hue). Mixing is premultiplied
   and uses CSS Color 5 percentage normalisation, so
   `color-mix(in srgb-linear, rgb(… / .16) 78%, X)` has alpha
   `.78 × .16 + .22 = .3448`.
3. Painting: gamma-encode (sign preserving), clip each channel to [0, 1], round
   to 8 bits. Chrome clips per channel for sRGB output; it does not apply the
   CSS Color 4 chroma-reduction gamut map. The oracle confirms this for the
   out-of-gamut tokens (`primary-strong` → `#655000`, `accent-strong` →
   `#c00064`). About ten tokens per theme are outside sRGB (the yellow ramp
   ends, `warning*`, `primary-strong`, `accent-strong`, dark `info-muted/soft`).
4. Alpha is never quantised: opaque colours emit `Color(0xffRRGGBB)`;
   translucent ones emit `Color.fromRGBO(r, g, b, alpha)` with the exact CSS
   alpha (`0.1` stays `0.1`, not `26/255`).

**Shadows.** Each `box-shadow` layer becomes a `RaftCssShadow` (`inset`,
`offset`, `blur`, `spread`, `color`) in CSS order inside a `RaftShadow`.

- `RaftShadow.outer` gives the non-inset layers as `BoxShadow`s in CSS order;
  `paintOrder` reverses them. `BoxDecoration` paints index 0 first (bottom),
  while CSS paints the first layer on top, so use `paintOrder` when stacking
  matters (identical-hue stacks look the same either way).
- `BoxShadow.blurRadius` carries the CSS blur value (repository convention).
  Flutter turns it into sigma `0.57735 × blur + 0.5`, but CSS uses `blur / 2`.
  Custom painters should use `RaftCssShadow.blurSigma`.
- Flutter has no inset `BoxShadow`. `RaftShadow.inset` lists the inset layers.
  Paint them after the background, clipped to the padding box (border box
  deflated by the border width). For each layer, draw an even-odd path made of
  a large outer rect minus the padding box shifted by `offset` and deflated by
  `spread`, with `MaskFilter.blur(BlurStyle.normal, blurSigma)` when `blur > 0`.
  Draw from the last layer to the first so the CSS-first layer ends on top.
  `RaftFieldBorder` (theme.dart) and `RaftPopoverSurface` (popover_surface.dart)
  are the reference painters.

**Metrics.** `--field-font-size/weight/line-height` and `--card-title-*` are
emitted per theme as doubles (px or CSS weight; `raftFontWeight()` maps
weights to `FontWeight`). Font stacks come from `fonts.css`. The first family
maps to the bundled asset (`Hanken Grotesk` → `packages/raft_ui/HankenGrotesk`,
`Geist`, `Geist Mono`, `Inter`). `RaftScale` holds the Tailwind 4 scale at a
16 px root: `spacing` (4 px; `space(n)`), `radius`, `text` (size plus absolute
line height), `fontWeight`, `leading`, `trackingEm`, `ease` (incl. raft-ui
`slide`), `breakpoint`, `container`, `blur`, the default transition, and the
product `--border-width-3`.

## Verification

- `tool/tests/test_gen_tokens.py` (run by `tool/check-project`) covers:
  - the converter: sRGB primaries, achromatic endpoints, round trip, clipping,
    exact alpha, every `color-mix` space;
  - cascade resolution;
  - oracle parity: all 78 oracle entries, at most 1/255 per channel;
  - freshness: vendored hashes and `--check`.
- `packages/raft_ui/test/design_tokens_test.dart` repeats the oracle comparison
  on the emitted Dart constants and checks the `RaftTokens` wiring.
- The oracle stores translucent colours as canvas readbacks (premultiplied
  8-bit), so `rgb(250 250 247 / .1)` reads back as `245 245 245 26`. Both tests
  simulate that storage before they compare. Three opaque tokens differ by 1
  because their exact value sits within 0.02 of a .5 rounding boundary, where
  Chrome's float32 transfer function rounds the other way:
  - elegant-light `warning-soft` blue 222.484;
  - elegant-light `info-strong` red 9.501;
  - elegant-dark `line-strong` red 238.503.
