# Design tokens

The Flutter tokens are a deterministic translation of the raft-ui design-system
CSS, tuned so Flutter paints the same bytes as the parity Chromium:

- Opaque colours come from a conversion rule that reproduces Chromium 147
  bit-exactly (657/657 sampled opaque tokens, 77/77 opaque recipe literals).
- Translucent colours are fitted against swatches sampled from that Chromium
  (`tool/design-source/chrome-oracle.json`), because Chromium's compositing is
  not a plain `c·a + d·(1−a)` (see "Translucent colours").

The older canvas-readback snapshots in `docs/theme-tokens/*.json` are kept as a
second, legacy oracle.

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
tool/gen-tokens --sample-chrome [--raft-source DIR]
                           # re-sample tool/design-source/chrome-oracle.json, then regenerate
tool/recipes/run           # recipes read tool/recipes/chrome-literal-fits.json (written by gen-tokens)
```

Re-sample the Chrome oracle whenever a vendored source, component-roles.css or
a recipe literal changes; the tests check that the oracle's source hashes match
the manifest. Order after a source change: `tool/recipes/run` →
`tool/gen-tokens --sample-chrome` → `tool/recipes/run` (picks up new literal
fits) → tests.

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

**Colour conversion** (`parse_color` in `tool/gen-tokens`; the same code is
ported to `tool/recipes/lib/css-value.mjs` and to `raftMixColors` in
`packages/raft_ui/lib/src/recipes/recipe_runtime.dart`):

1. `oklch(L C H / A)` / `oklab()` → OKLab → sRGB on **Chromium's path** (the
   rule that makes the bytes exact). Blink converts OKLab → LMS → XYZ-D65, then
   Bradford-adapts to XYZ-D50 (`skcms_AdaptToXYZD50`, D65 = 0.3127/0.3290),
   then applies the inverse of skcms' sRGB gamut matrix (`SkNamedGamut::kSRGB`,
   ICC s15Fixed16 values such as 0.436065674). Every step runs in float32,
   and the sRGB transfer function is evaluated in float32 too. The D50 round
   trip and the quantised matrix move channels by up to ~0.15/255 compared
   with the exact CSS Color 4 maths, which flips 8-bit rounding for some
   tokens. For example, `--success` oklch(0.714 0.176 153.079) is red 31.53 in
   exact maths but 31.39 in Chromium, so it paints 31, not 32. The exact maths
   is kept as a fallback: `RAFT_TOKENS_PIPELINE=spec`. It is within 1/255 of
   Chrome on all channels and off by 1 on 8 of the 657 opaque swatches.
   `#hex`, `rgb()`, `rgba()`, `transparent`, `black` and `white` are also
   accepted.
2. `color-mix()` supports `srgb-linear`, `srgb`, `oklab` and `oklch` (shorter
   hue; a powerless hue takes the other colour's hue). Mixing is premultiplied
   and uses CSS Color 5 percentage normalisation, so
   `color-mix(in srgb-linear, rgb(… / .16) 78%, X)` has alpha
   `.78 × .16 + .22 = .3448`. Colours authored as `oklch()` are mixed in
   OKLab/OKLCH from their authored coordinates, like Blink; an authored hue is
   never powerless.
3. Painting: gamma-encode (sign preserving), clip each channel to [0, 1], round
   to 8 bits. Chrome clips per channel; it does not apply the CSS Color 4
   chroma-reduction gamut map. Examples: `primary-strong` → `#655000`,
   `accent-strong` → `#c00064`. About ten tokens per theme are outside sRGB.
   Note that Chrome on a wide-gamut display would show these more saturated.
4. Opaque colours emit `Color(0xffRRGGBB)`.

**Translucent colours.** Chromium 147 does not composite `rgba(c, a)` as
`c·a + d·(1−a)`. Fitting the samples shows that it blends premultiplied 8-bit
values: the source is premultiplied with an 8-bit alpha, the destination term
`d·(255−a8)/255` is truncated, and `srgb-linear` mixes keep a float source. So
no colour with the authored alpha reproduces Chrome's bytes in Flutter, whose
Skia raster blends in float. A model of Chrome's blend reproduced 201 of 216
samples, so the generator does not model it. Instead it fits against samples:

- `tool/gen-tokens --sample-chrome` paints every token in the three theme
  scopes and reads the bytes back from a PNG screenshot (never canvas
  `getImageData`). It uses `tool/chrome-oracle.cjs` and the Playwright Chromium
  the parity harness uses, launched with `--disable-lcd-text
  --font-render-hinting=none` at DPR 1, with the shipped cascade (Tailwind
  @theme vars, foundation.css, fonts.css, product `:root.dark`,
  component-roles.css). Each swatch is painted over white, black,
  layer-canvas, layer-panel, layer-card, layer-popover and layer-canvas-muted.
  The recipe literals are sampled the same way.
- For each translucent token, `fit_translucent` searches a grid of alphas
  within ±4/255 of the authored alpha. For each alpha and channel it
  intersects the source values whose float source-over lands inside Chrome's
  rounding interval on white, black and the theme canvas (required). The other
  backdrops are kept when they still intersect. Among solutions with at least
  0.05 output levels of margin, it picks the alpha closest to the authored one
  and keeps each channel as close to its authored value as the central half of
  the interval allows.
- The result is emitted as `Color.from(alpha:, red:, green:, blue:)` with the
  authored alpha in a comment. `RaftTokens` therefore no longer reports the
  exact CSS alpha for translucent tokens (e.g. `ink-10` is 0.101961, not 0.1).
- Recipe literals use the same fit, written to
  `tool/recipes/chrome-literal-fits.json` and emitted by `gen_dart.mjs` as
  `CssColor(argb, src, paint)`. Fits are only computed for literals whose
  source text is at most 60 characters, because longer sources are not
  emitted.
- Shadow layer colours are not fitted, because they are blurred.

**Exceptions** (translucent swatches no non-negative Flutter source-over can
reproduce):

- In elegant dark, Chrome truncates the destination term, so black at 0.6 and
  at 0.3 over the canvas (`layer-backdrop`, `field-inset-top`) lands one
  level lower than any source ≥ 0 can reach.
- `button-accent-edge` (out-of-gamut accent at 28%) would need red above 1.0.
- 22 translucent-black recipe literals miss the dark canvas by 1 for the same
  truncation reason. White, black and the light surfaces are exact.

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
  - the converter: primaries, round trip, clipping, every `color-mix` space;
  - cascade resolution;
  - the Chrome oracle:
    - every opaque token is byte-equal (657/657);
    - the spec maths is off by one on `--success`;
    - fitted translucent tokens reproduce Chrome on white/black/canvas for
      212/216 swatches, the 4 misses being the listed exceptions;
    - every opaque recipe literal equals Chrome;
    - the oracle's source hashes match the manifest;
  - the legacy readback oracle: 78/78 exact after simulating premultiplied
    storage;
  - freshness: vendored hashes, `.g.dart` files and the literal fits.
- `packages/raft_ui/test/design_tokens_test.dart` renders the emitted Dart
  colours with Flutter's own rasteriser:
  - opaque bytes must equal the oracle;
  - every translucent token is painted over the 7 backdrops and must equal
    Chrome on white/black/canvas except the 4 exceptions;
  - more than 90% must match on the other surfaces (measured: 94% in the
    Python model).
