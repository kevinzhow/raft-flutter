# Visual parity against the official Raft tool

raft-flutter is measured with the Raft team's own cross-platform visual
parity tool (`raft-source/packages/visual-testing`, CLI `src/cli.mjs`), not a
home-grown differ. The Flutter app is plugged in as a **provider**: it writes
captures in the official provider output contract and the official CLI does
`diff`, `site` and all scoring.

## Authorized baseline fixture repair (2026-10-09)

Human message `65b111e1` authorizes fixing defective test baselines. Five
`components.thread.message-row.md-wrap-*` cases previously seeded channel
tasks with `taskNumber` alone. Missing `status` made `TaskStatusIconRoot`
throw, and `MarkdownContentErrorBoundary` showed processed raw Markdown/HTML
instead of the intended message.

`tool/reference-patches/markdown-tasks.json` now declares complete public
task fixtures shared by both providers. All five are explicitly `in_progress`;
#606 and #607 match their message text. These are declared test states,
not claims about historical live tasks. A generated Vite host replaces only
that exact fixture block in the pinned reference. Neither the Source checkout
nor reference product components are edited. The three-theme runner applies
the same fixture repair.

Capture admission checks the pinned Source commit and exact patch anchor.
Repaired cases invalidate the old cache and must show real task chips with
valid states and no render error/raw-markdown fallback. Metadata records the
fixture SHA-256 and DOM evidence. Old PNGs and metadata are archived by hash
before replacement; the existing report links them alongside the current
image. The 99-case selection, message content, geometry and official scoring
thresholds remain unchanged. Repairing a React baseline does not pass Flutter.

## Message-row markdown cluster (2026-10-10)

Run `20261010T110648Z-flutter-cf9c833` reused the same React captures as
the `cfb67cc` run. All 99 PNGs are byte-identical. The run scored 82/99:
9 pass, 73 basic-pass and 17 different.

On the unfixed 0cc2888, four cases had dropped below the pass line because
the parity harness drifted from the app:

- `login.signing`: the fixture client's `.invalid` origin went to real DNS
  through the Android local-network check, so the providers never loaded.
- agent-detail `no-computer` / `computer-missing`: the directory row now
  wins over `GET /agents/:id`, so the seeded `createdAgents` was lost.
- `composer.member-suggestions`: people now come from the entity directory,
  which was not preloaded.

The fixed root causes in the markdown rows were these colours and metrics:

| Item | Web value | Old Flutter value |
| --- | --- | --- |
| brutal message inline code | `bg-black/5 text-black` | foreground ink on strong/5 |
| elegant message inline code | `bg-fill-muted text-foreground-strong` | foreground ink |
| link colour (light / dark) | Tailwind 4 blue-700 / blue-300: `#1447e6` / `#8ec5ff` | Tailwind 3 values |
| reference chip label baseline | Blink rounded ascent plus floored half-leading | fractional metrics |

Remaining causes, all measured from the side-by-side images:

1. **Line breaking.** Web uses `overflow-wrap: anywhere` for inline code. A
   token longer than a line moves to the next line first. SkParagraph breaks
   it at once on the current line. The code's padding placeholders also add
   break opportunities that Blink does not have, for example after `（`.
   Blink does not break after `/` before a letter, but ICU does.
2. **Host font fallback.** Chromium on this host draws `。` and `→` from Noto
   Sans Mongolian / Liberation Sans.
3. **List item gap.** It is 4px in Flutter (`blockSpacing`) and `mb-0.5`
   (2px) on the Web.
4. **Text rasterisation.** Chromium's text gamma and contrast differ from
   Flutter's Skia. About half of all ink pixels differ even when glyph
   positions match exactly, so text-dense captures stay at about 93–95%
   pixel-perfect after their layout matches.

Per-row classification of the 17 remaining `different` rows at that time
(run `20261010T112612Z`, `.local/parity-final/classify*.py`; superseded by
"Official-suite root causes (2026-10-11)" below). Each mismatched
pixel was put into one of four buckets:

- **AA**: another-image pixel within 1 device px differs by <= 40/255.
- **subpx**: the same, within 2 device px.
- **other**: everything left after AA and subpx.
- **visible**: differs by more than 40/255 after a 1-CSS-px Gaussian blur.

React used production fonts and `--disable-lcd-text --font-render-hinting=none`
(`textRendering.chromiumArgs` in all 99 metadata files).

| row | exact | AA | subpx | other | visible | remaining real difference |
| --- | --- | --- | --- | --- | --- | --- |
| ui.card.states.elegant | 6.83 | 6.66 | 0.12 | 0.06 | 0.00 | none: rasteriser only (text coverage, shadow blur ±1 level) |
| members.avatar-management | 5.05 | 4.55 | 0.28 | 0.23 | 0.00 | none: rasteriser and fractional border edges |
| message-row.deleted-human | 4.37 | 3.51 | 0.47 | 0.39 | 0.00 | none visible: badge border at fractional x, `+` icon stroke coverage |
| thread.message.row | 5.68 | 4.02 | 0.84 | 0.82 | 0.01 | `+` add-reaction icon stroke slightly heavier |
| create-agent.dialog-onboarding | 4.34 | 2.64 | 0.82 | 0.88 | 0.85 | section borders 0.3–0.7 CSS px off (Blink snaps borders to device px) |
| message-row.rich-content | 5.19 | 3.38 | 0.85 | 0.97 | 0.44 | link underline thickness/offset |
| message-row.long-inline-code | 5.76 | 3.78 | 0.86 | 1.12 | 0.67 | line with the 20px unknown-task badge does not grow: flutter_markdown_plus forces a strut, Web grows the line box (+2px below) |
| message-row.md-wrap-adjacent | 6.31 | 4.32 | 0.72 | 1.27 | 0.16 | `。` drawn by host fallback font (Noto Sans Mongolian) in Chromium |
| message-row.md-wrap-task607 | 7.34 | 4.48 | 1.05 | 1.81 | 0.70 | `→` / `。` host fallback fonts |
| message-row.md-link-ref | 6.99 | 3.81 | 1.21 | 1.97 | 1.31 | link underline 2px at baseline+2 (Web) vs font-metric ×2 (≈1.1px, 1px higher) |
| message-row.md-latest-release | 8.69 | 6.08 | 0.73 | 1.88 | 1.71 | Flutter breaks inside `` `/share/<token>` `` after `/` |
| message-row.md-wrap-slice1 | 9.10 | 5.98 | 1.24 | 1.88 | 1.76 | list item gap 4px vs `mb-0.5`; fallback `。`/`→` |
| composer.pending-mention-actions | 4.15 | 3.22 | 0.06 | 0.87 | 1.59 | composer keeps focus after button send (shadow-md); Source blurs on click send |
| message-row.md-wrap-clarify | 11.15 | 5.24 | 1.98 | 3.93 | 4.84 | break after `（` before inline code (padding placeholders add break opportunities) |
| settings.notifications.page | 6.79 | 1.08 | 0.44 | 5.27 | 6.21 | Android copy instead of Web push copy (platform content); panel left border height |
| message-share.selection | 5.81 | 1.31 | 0.04 | 4.46 | 6.63 | bottom-anchored real chat with date divider; square vs circular select checkbox; no Owner badge |
| message-row.md-wrap-status606 | 16.63 | 7.96 | 1.92 | 6.76 | 9.61 | long inline code breaks on the current line instead of moving down (`wrap-anywhere`); break after `/` |

## Official-suite root causes (2026-10-11)

Starting point: integration 80769ee, official run `20261010T144652Z`
(published as `raft_flutter_parity/latest`): 83/99. Branch
`cindy/parity-official` fixes, each verified with a full 99-case run
(no case got worse in any step):

| fix | cause class | cases |
| --- | --- | --- |
| Composer Send no longer requests editor focus (Source only prevents the Send pointer-down blur) | missing state | composer.pending-mention-actions 95.85 -> 96.83 (pass) |
| `RaftCssText` aligns the glyph baseline SkParagraph actually paints (`round(reported)`, e.g. 12/20 Hanken reports 14.182, paints 14) | layout metric | 34 cases up, 0 down; create-agent.dialog-onboarding 95.66 -> 95.97 |
| CSS `font-black` renders the served 700 face (`RaftTypography.black`); w900 + `wght 700` was also synthetically emboldened (+29% ink) | font | dialog-onboarding -> 96.01 (pass) |
| Brutal departure badge keeps the 20px sender line (inherited 20/14 ratio at 10px grew the header by 1/3px) | layout metric | message-row.deleted-human 95.73 -> 96.57 (pass) |
| Message task chip label uses the Blink line box (13px on 16.25px: Blink baseline 12, Flutter rounded 12.63 -> 13) | layout metric | message.row +0.32, md-link-ref +0.20, rich-content +0.14, long-inline-code +0.07 |

Result on the branch: **86/99** (10 strict passes).

### Why the remaining 13 rows stay below 96%

Measured with a 1-device-px tolerance (`aa` = mismatches that disappear when
a pixel may match a neighbour within 40/255; `ifAA` = pixelPerfect if those
were equal):

* **Text rasterisation (dominant, not fixable in app code).** Flutter's
  SkParagraph shapes every run with FreeType *slight* (vertical) hinting:
  a 36px `C` (Hanken Grotesk) covers rows 75..99 for a baseline at 100,
  i.e. the overshoot is snapped away; Chromium with
  `--font-render-hinting=none` draws it unhinted (rows 74..100, partial
  coverage). Chromium also applies its A8 gamma/contrast, ~7% more ink.
  Glyph advances match to 0.01px, so the difference is pure coverage: 4-10%
  of all pixels in text-dense captures. No Dart API changes hinting.
* **Blink pixel snapping of box edges.** Blink paints borders/backgrounds at
  whole CSS px; Flutter paints fractional rects anti-aliased (e.g. 18.25px
  task chips, 0.5px-offset chip rows). Owned by the ext-suite border
  primitive work, not changed here.
* **Line breaking (markdown rows).** Inline-code padding placeholders
  (U+FFFC) are ICU break opportunities, ICU breaks after `/` before a
  letter (Blink's ASCII table does not), SkParagraph force-breaks an
  over-long code token on the current line instead of moving it down first
  (`overflow-wrap: anywhere`), and Chrome's default `text-spacing-trim`
  halves adjacent CJK punctuation (`），`). A word-joiner fix needs a
  copy-stripping selection delegate; not done in this pass.
* **Host fallback fonts:** Chromium draws `→`/`。` from Liberation/Noto
  Sans Mongolian on this host.

| row | pixelPerfect | ifAA | aa | remaining difference |
| --- | --- | --- | --- | --- |
| members.avatar-management | 95.14 | 99.77 | 4.63 | text raster; chip/env rows behind the scrim sit 0.5px off (Blink snaps) |
| thread.message-row.rich-content | 94.94 | 99.06 | 4.12 | text raster; chip borders at fractional y (snap); link underline thickness |
| thread.message.row | 94.64 | 99.24 | 4.60 | text raster; 18.25px task chip border snap; `+` icon stroke |
| thread.message-row.long-inline-code | 94.32 | 98.90 | 4.58 | text raster; unknown-task line box does not grow (strut); code break position |
| thread.message-row.md-wrap-adjacent | 93.69 | 98.73 | 5.04 | text raster; `。` host fallback font |
| settings.notifications.page | 93.21 | 94.73 | 1.52 | platform copy: Android notification text instead of Web push copy (by design: no fabricated browser permission); panel left border height |
| thread.message-row.md-link-ref | 93.20 | 98.07 | 4.86 | text raster; link underline 2px at baseline+2 vs font metric |
| ui.card.states.elegant | 93.17 | 99.94 | 6.78 | shadow blur and gradient dither +-1 level (4.3% of pixels differ by exactly 1); text raster |
| thread.message-row.md-wrap-task607 | 92.66 | 98.19 | 5.53 | text raster; `→`/`。` fallback fonts |
| thread.message-row.md-latest-release | 91.31 | 98.12 | 6.80 | ICU breaks inside `/share/<token>` after `/` |
| thread.message-row.md-wrap-slice1 | 90.92 | 98.13 | 7.21 | list item gap 4px vs `li mb-0.5`; `），` punctuation trim; fallback `。`/`→` |
| thread.message-row.md-wrap-clarify | 88.86 | 96.07 | 7.21 | inline-code padding placeholder lets `（` + code break apart; cascades |
| thread.message-row.md-wrap-status606 | 83.37 | 93.24 | 9.87 | long inline code force-broken on the current line; break after `/` |

## One command

```bash
tool/parity run                       # React (cached) + Flutter capture, official diff + site, summary
tool/parity run --cases 'components.ui.*'   # recapture a subset; diff/site/summary still cover every case
tool/parity run --refresh-react       # also recapture the React baselines
tool/parity publish                   # copy site to the report hub, update latest, verify URLs + images
tool/parity summary                   # recompute build/parity/summary.json from the last diff
```

Environment overrides: `PARITY_RAFT_SOURCE` (raft-source checkout),
`PARITY_OUT` (default `build/parity`), `PARITY_TOOLCHAIN_PATHS` (file listing
the Node 24 / pnpm 10 binaries), `PARITY_REPORTS_ROOT`, `PARITY_BASE_URL`,
`PARITY_WEB_PORT` (Vite port for the React provider, default 4391),
`PARITY_SHARDS` (parallel `flutter test` processes, default 4).

Published report: <http://100.109.192.23:18931/raft_flutter_parity/latest/>
(each run is kept under `raft_flutter_parity/<UTC timestamp>/`).

## How it is wired

| Step | What runs | Output (`build/parity/`, gitignored) |
| --- | --- | --- |
| React baseline | official React provider spec + Playwright config, run as a generated copy with production fonts (see "Baseline fonts"; `--react-fonts upstream` runs the unmodified `cli.mjs capture --providers react`) — Playwright + `packages/web/visual-testing` Vite host, 390x844 @3x | `visual-testing-results/react/<case>.png` + `.metadata.json` |
| Flutter provider | `flutter test apps/raft_flutter/test/parity/parity_capture_test.dart`, sharded | `visual-testing-results/android/<case>.png` + `.metadata.json`, `android-case-map.json` |
| Diff | official `cli.mjs diff --pairs react__android --manifest shared` | `visual-testing-results/diff/react__android*` |
| Site | official `cli.mjs site --pairs react__android --skip-analysis --site-dir build/parity/site` | `site/` (storybook-style home, `latest/`, `runs/<id>/`) |
| Summary | `tool/parity` reads the official diff JSON + Flutter case map | `summary.json` (also `site/flutter-parity-summary.json`) |

The CLI runs with `SLOCK_VISUAL_REPO_ROOT=build/parity` and
`SLOCK_REACT_REPO_DIR=<raft-source>`, so every result lands outside the
raft-source tree (Playwright's scratch `packages/web/test-results/` is the only
write there; it is untracked).

Exact command of the FIRST (upstream-font) React baseline, kept for
reference; the current baseline uses production fonts, see below (run from
`raft-source/packages/visual-testing`, Node 24.21.0 first on `PATH`, all
`npm_config_*` variables unset):

```bash
SLOCK_VISUAL_REPO_ROOT=<flutter-worktree>/build/parity \
SLOCK_REACT_REPO_DIR=<raft-source> PLAYWRIGHT_WEB_PORT=4391 \
node src/cli.mjs capture --providers react --manifest shared --webPort 4391
```

Result: 152 Playwright tests passed (99 provider captures + the package's
metric specs), 99/99 React captures. Provenance (raft-source commit and dirty
files at capture time) is in `build/parity/react-source.json`.

One-time host setup that was needed: the pinned `@playwright/test` 1.59.1
wants `chromium_headless_shell-1217`, and Playwright refuses to download on
Ubuntu 26.04, so it was installed with
`PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntu24.04-x64 pnpm exec playwright install chromium`
from `raft-source/packages/web`.

### Provider identity

The CLI's pair model knows `react > android > ios > ohos`. The Flutter
provider therefore writes under provider **`android`** and records itself in
metadata as `"source": "flutter"`, `"providerType": "flutter-widget-test"`
(README: "If Android or Harmony renders KMP/shared UI, record that as the
provider `source`"). `diff --pairs react__android` and `site` work unmodified.

### Flutter capture contract

* Each official case is pumped in a `flutter test` widget test at the case
  viewport (`physicalSize = width x height x density`, `devicePixelRatio =
  density`, i.e. 390x844 @3x → 1170px wide like React).
* Theme follows the React render host: `.elegant` case ids → elegant light,
  everything else → brutal light, via `raftTheme(...)` / `RaftTokens`.
  No official case declares elegant-dark, so dark has 0 official units.
* Target platform is Android (`TargetPlatformVariant.only(android)`), so
  `RaftDensityScope` resolves to touch density exactly as on a phone.
* Real fonts: every family in the app's `FontManifest.json` (raft_ui
  HankenGrotesk/Geist/GeistMono/Inter/RaftDiagramSans, MaterialIcons) is loaded
  with `FontLoader`, plus the system Noto Sans CJK / Noto Color Emoji files
  for the families the theme names as fallbacks. Ahem is never used.
* The full viewport is rasterised (`RenderRepaintBoundary.toImage(pixelRatio:
  density)`) and cropped to the case target rect, like Playwright's clipped
  page screenshot (overlays/portals above the target are included; rects
  outside the viewport are clamped like React). `body` selectors and
  `modal-viewport` / `viewport-with-portal` contracts capture the viewport.
* A case that throws during build/layout fails and writes no image (it is
  counted as `flutter-capture-failed`, never as a stale or error-screen image).
* Metadata carries `typography` and `styleTokens` probes (README "style
  probes"), auto-collected from `RenderParagraph` / `RenderDecoratedBox`
  inside the target, plus the Flutter widgets exercised.

### Coverage map

`apps/raft_flutter/test/parity/case_map.dart` merges one map per group in
`apps/raft_flutter/test/parity/cases/*.dart`: `case id → ParityCase(builder)`.
A case without a builder is NOT COVERED. Reasons are explicit
(`ParityUncovered`): `harnessTodo` (builder not written yet),
`noFlutterSurface` (the Flutter app has no implementation of that surface),
`deviceOnly` (needs a real device). The map for every manifest case is written
to `build/parity/visual-testing-results/android-case-map.json`.

Builders compose the **real** raft_ui / app widgets in the same fixture frame
the React render host uses for that case id (frame size, padding, content
from `shared/fixtureData.json` etc.). They never patch product visuals; when
Flutter lacks a variant, the nearest product widget is rendered and the diff
shows the gap.

## Baseline fonts: production Google Fonts instead of the upstream Space Grotesk stub

**Deviation from the official spec, decided by the owner:** the target is the
production Web, so the React baseline must render the real raft-ui fonts.

Why: the upstream provider spec (`tests/react-provider.spec.ts`, `quietApi`)
fulfils raft-ui's font URL
(`css2?family=Geist…&family=Geist+Mono…&family=Hanken+Grotesk…&family=Inter…`)
with `packages/web/src/assets/fonts/fonts.css`, which only declares Space
Grotesk and Space Mono, and answers every other Google Fonts request with 502.
raft-ui's stacks (`Hanken Grotesk, system-ui, sans-serif`, Geist, Inter, Geist
Mono) therefore fell back to Chromium's system-ui (Noto Sans) — not what
production Web shows. (Production `index.css` imports only raft-ui's URL plus
the `Raft Quote Glyphs` woff2; the Space Grotesk URLs are not requested by the
product.)

What `tool/parity run` does now (raft-source untouched):

* `tool/parity-fonts/` (committed, 492 KB, OFL): the exact CSS Google returns
  for raft-ui's URL to the pinned Chromium 147 UA (identical to the headed
  Chrome 147 response) and all 22 woff2 files it references, sha256-pinned in
  `manifest.json`. `tool/parity fonts` verifies, `--refresh` refetches.
* The official spec and Playwright config are copied into
  `build/parity/react-provider/` and patched; every patch anchor must match
  exactly once or the run stops. Changes: path wiring (spec runs outside its
  package); raft-ui's URL and its gstatic files are fulfilled from the cache
  (the legacy Space Grotesk URL mapping and the Quote Glyphs file stay as
  upstream); the font-readiness assertions probe Hanken Grotesk, Geist, Geist
  Mono, Inter (400/700) + Raft Quote Glyphs and require each family's files to
  be served; every capture's metadata gains `fontFaces` (document.fonts
  status) and `platformFonts` (the faces Chromium actually drew, via CDP
  `CSS.getPlatformFontsForNode`). Everything else is the official spec,
  invoked with the same env as the CLI's `runReactProvider`.
* Verified across all 99 captures (glyphs drawn): Hanken Grotesk 45,327,
  Geist Mono 16,262, Inter 521, Geist 45; system fonts only for glyphs outside
  the served subsets (Noto Sans CJK 1,060 for Chinese text, plus 32 symbol
  glyphs from Noto Sans Mongolian/DejaVu Sans Mono) — the same fallback the
  production page gets on this host. E.g. `components.ui.card.states` →
  Hanken Grotesk only; `components.ui.card.states.elegant` → Inter + Geist;
  `message-row.long-inline-code` → Hanken Grotesk + Geist Mono.

Flutter side: `packages/raft_ui/assets/fonts` were compared with Google's
served files (fontTools, every Google-served codepoint, wght 300–700,
outlines + advances + vertical metrics): Geist 1.800, Geist Mono 1.701 and
Hanken Grotesk 3.013 are identical. Inter 4.001 had the same outlines at
opsz 14 but carried the `opsz` axis, and raft_ui's theme varies opsz up to 32
for elegant headings, while Google serves Web a wght-only Inter (opsz pinned
at 14). `Inter.ttf` is now derived from the same pinned upstream file with
opsz pinned at 14 (`tool/parity-fonts/derive_inter.py`, provenance in
`docs/inter-font-provenance.json`); it is outline-identical to every Google
Inter subset at all tested weights. The theme's `FontVariation('opsz')` is now
inert, matching Web. raft_ui tests: 571 passed.

## Text rendering: React captures emulate Android Chrome

**Owner decision:** the official cases are mobile (390x844 @3x) and their
production target is Android, where Chrome rasterises text with grayscale
anti-aliasing and subpixel glyph positioning (fractional advances). Desktop
Linux Chromium — what the pinned Playwright headless shell is — defaults to
LCD subpixel AA (coloured fringes) and hinted, whole-pixel glyph advances.
Flutter draws grayscale AA with fractional advances, so the desktop default
added rasteriser noise to every text pixel and shifted text runs by whole
pixels.

Flags (added to the generated Playwright config as `launchOptions.args`,
`tool/parity run --react-text-render android`, the default; `desktop` restores
the Chromium default): `--disable-lcd-text --font-render-hinting=none`.
`--disable-lcd-text` forces grayscale AA; `--font-render-hinting=none`
disables FreeType hinting, which on Linux is what enables subpixel
positioning and unrounded advances. No other flag was needed.

Evidence (`tool/parity render-evidence` → `build/parity/render-evidence/`:
neutral ink on white in the production fonts, same Chromium, 3x; plus the
refreshed captures' metadata):

| check | desktop default | `--disable-lcd-text --font-render-hinting=none` |
| --- | --- | --- |
| (a) LCD pixels (per-channel coverage spread > 0.08) in the synthetic text page | 25,321 | **0** (0 chromatic pixels at all) |
| (a) pixels that are not a single-coverage blend of two flat colours, `components.settings.notifications.page` | 41,297 | **0** |
| (a) same, `components.ui.badge.states` | 3,359 | 752 (dark-pink text on pink badge: a text colour below the flat-colour threshold, grayscale on inspection) |
| (b) badge text run widths (Shared / Installed / Update / Built In / task #273 / Install) | 46 / 54 / 47 / 47 / 62 / 43 | 46 / 52.84 / 46.5 / 45.48 / 59.80 / 41.69 |
| (b) synthetic runs: Hanken 400 14px, Hanken 700 16px, Geist 400 14px, Inter 600 18px, Geist Mono 400 13px | 378 / 431 / 309 / 408 / 424 | 367.31 / 427.03 / 304.64 / 406.39 / 413.41 |
| (b) Flutter `TextPainter`, same strings and fonts | | 367.30 / 427.02 / 304.64 / 406.39 / 413.40 |
| (c) faces loaded (document.fonts) | Geist, Geist Mono, Hanken Grotesk, Inter | same; all 99 captures have every Geist / Geist Mono / Hanken Grotesk / Inter / Raft Quote Glyphs face `loaded` |

With the flags Chromium's text advances match Flutter's to within 0.01 px.
Across the 99 refreshed captures, 942 of 1,969 probed text runs have
fractional widths (`textRendering.textRunWidths` in each React metadata JSON;
the rest are elements whose box width comes from layout, e.g. block
elements sized by their container, not from their text).

## Capture determinism: animations and carets

* **React animations:** the upstream spec takes screenshots with Playwright's
  default `animations: "allow"`, so animated elements were caught mid-frame:
  Skeleton's `animate-pulse` at opacity ~0.999 (greys 231/243 instead of the
  at-rest #e5e5e5 = 229 / 242), and the Spinner mid-rotation (arc at 3
  o'clock) because its `animation: none` style does not reach the rotating
  inner element. The generated spec now passes `animations: "disabled"` to all
  four screenshot calls (the run stops if upstream's call count changes):
  finite animations/transitions finish, infinite ones reset to their initial
  frame — the at-rest first frame the Web shows before animating.
* **Spinner frame:** React's at-rest frame is rotation 0 (arc centred on 12
  o'clock). Flutter's `RaftSpinner` under reduced motion paints rotation 0,
  i.e. its own t=0 frame (brutal has no dash phase). The two t=0 frames
  differ in arc start angle (Flutter's arc spans ~9:30–12:30); that is a
  `RaftSpinner` painter difference left for the UI track, not a capture issue.
* **Flutter caret:** Playwright captures with `caret: "hide"`. The harness
  already made the theme's cursor colour transparent, but product fields now
  set `cursorColor` explicitly, so the harness also sets every
  `RenderEditable.cursorColor` to transparent for the captured frame and
  repaints with a zero-duration pump (no blink-timer advance, no product
  change). Verified: `components.ui.selection-popover.states` shows no caret.

Effect on integration 053ffa0 (Flutter identical before/after; React refreshed
with the new option): skeleton 60.15% → 62.36%, spinner 98.11% → 98.94%
(basic-pass), selection-popover 95.39% → 95.43%; four other cases moved by
<= 0.04pp; total stays 29/99 (29.29%), mean pixelPerfect over 95 captured
80.38% → 80.42%.

## Scoring

Unit = official case x variant x theme. Every default case (non-skipped,
non-pending, the CLI's default selection) declares exactly one variant and one
theme, so units = cases.

* **passing** = official diff status `same | pass | basic-pass`
  (pixelPerfectSimilarity > 96%; this is the site's own pass count).
  `strictPass` (> 99%) is reported separately.
* **failing** = both providers captured, status `different`.
* **not covered** = no Flutter builder (any reason).
* **percentage = passing / total**.

## Latest result (production-font baseline)

Report: <http://100.109.192.23:18931/raft_flutter_parity/latest/> (every run
is kept as `raft_flutter_parity/<UTC timestamp>/`). Machine-readable:
`latest/flutter-parity-summary.json`, per-case table `latest/flutter-parity-summary.md`.

| baseline | units | React | Flutter | passing (>96%) | strict (>99%) | failing | not covered | percentage | mean pixelPerfect of 92 captured |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| upstream font stub (run 20261008T220459Z) | 99 | 99 | 92 | 4 | 1 | 88 | 7 | 4.04% | 74.08% |
| production fonts + opsz-pinned Inter | 99 | 99 | 92 | 4 | 1 | 88 | 7 | 4.04% | 74.36% |
| + Android text rendering (current) | 99 | 99 | 92 | 5 | 1 | 87 | 7 | **5.05%** | 74.81% |

Android text rendering (current vs the previous row): passes are now
titlebar 99.48% (pass), spinner 98.11%, composer.empty 97.13%,
section-eyebrow 96.49% (new) and agent-detail.workspace 96.25%. 69 cases
improved, 1 got worse, 22 unchanged (|delta| <= 0.05pp). Top movers:
message.row +4.11pp, message-row.deleted-human +3.25, long-inline-code +2.65,
md-wrap-task607 +2.22, composer.states +2.20, composer.as-task-selected +2.18,
files.list +1.76; only drop message-row.rich-content -4.70 (82.00%): the React row
reflowed with the new advances (now 386 px tall vs Flutter's 380), which
shifts every line below the change.

Production fonts vs upstream stub (previous row vs first row): the pass set
was unchanged (titlebar 99.32%, spinner 98.11%, composer.empty,
agent-detail.workspace). Per-case pixelPerfect: 72 cases improved, 10 got
worse, 10 unchanged (|delta| <= 0.05pp); largest gains button.states +1.70pp,
message.row +1.58, message-row.deleted-human +1.42, long-inline-code +1.35,
card.states +1.20; largest drops spinner -0.44, md-wrap-status606 -0.41,
md-wrap-task607 -0.37. Text is a small fraction of most captures and the
remaining gaps are layout/component differences, so correct fonts move scores
only slightly; the gain is that text comparisons are now letterform-true.

By theme: brutal-light 4/94, elegant-light 0/5, elegant-dark 0/0 (no official
case declares dark; the React host only renders brutal and `.elegant`).

Caveat on `screens.members.agent-detail.workspace` (basic-pass): it passes
only because both screens are mostly white; the Flutter screen
(FleetInspection "Workspace files") is visibly different from React's tabbed
agent page. The official metric counts exact pixel matches, so large blank
areas inflate full-viewport scores — read screen-level numbers with the
side-by-side images.

Not covered (7):

| case | gap | reason |
| --- | --- | --- |
| components.ui.badge.states | noFlutterSurface | no shared Badge widget; only private single-use labels |
| components.ui.status-dot.states | noFlutterSurface | no standalone status dot (only private avatar presence overlay) |
| components.thread.composer.pending-mention-actions | noFlutterSurface | no Add/Notify/Ignore pending-mention strip; send response field ignored |
| components.thread.comment-anchor | noFlutterSurface | no attachment comments surface/API use |
| components.members.avatar-management | noFlutterSurface | no agent avatar picker |
| screens.members.agent-detail.reminders | noFlutterSurface | FleetDetail has no reminders; nothing requests reminders |
| components.home.notification-center.states | invalidBaseline | React fixture renders an empty 390x844 box; an empty-vs-empty 100% would be hollow |

Reproducibility: two consecutive Flutter captures of all 92 cases were
byte-identical.

## Extension suite (raft-flutter additions, not official cases)

Surfaces the official 99-case set does not cover are compared on the **same
official framework** in a separate suite, so official and added coverage
never mix. The official manifest, specs and Source checkout are untouched;
everything below is generated from this repository.

| piece | file | role |
| --- | --- | --- |
| manifest | `tool/parity-ext/cases.json` (generated by `tool/parity-ext/build-cases.py`) | `sharedCases.json` schema; ids `components.computers.<surface>.<theme>`; per-case `viewport` (desktop 1280 wide, density 1), `capture.selector` (React crop), `capture.androidKey` (the Flutter `ValueKey` of the same region), `capture.interactions` / `capture.androidInteractions` |
| fixture | `tool/parity-ext/fixtures/computers.json` | data both providers render (machines in every state, the two official agents placed on `computer-mbp`, workspaces, follow-up API routes) |
| React render host | `tool/parity-ext-web.mjs` + `tool/parity-ext/host/*.tsx` | the pinned official Vite host with generated, anchor-checked additions: the `parityTheme` root override (brutal-light / elegant-light / elegant-dark, as `tool/theme-parity-web.mjs`), the host files appended to a generated `VisualTestingCases.tsx` whose default export asks the extension registry first (official ids fall through unchanged), and the fixture as `virtual:parity-ext/computers` |
| React provider | generated copy of the official spec/config (same as `tool/parity`) plus three anchored patches | answer the fixture's `routes` and the case's machine list with `page.route`, a `hover` interaction, park the pointer after click-only interactions (Flutter taps leave no hover); `deviceScaleFactor` follows each case's density; `reuseExistingServer: false` |
| Flutter provider | `test/parity/parity_capture_test.dart` with `PARITY_MANIFEST` / `PARITY_EXT_FIXTURES`; builders in `test/parity/cases/ext_computers.dart` | desktop cases run with `TargetPlatform.linux` (pointer density); `capture.androidKey` selects the crop; `capture.androidInteractions` tap/hover keyed widgets |
| diff / site | official `cli.mjs diff` and `site` with `--manifest tool/parity-ext/cases.json` | unmodified CLI |
| runner | `tool/parity-ext/run {run,summary,publish}` | reuses `tool/parity`; output `build/parity-ext/`; publish to `raft_flutter_parity_ext/<stamp>` + `latest` (never `raft_flutter_parity/`) |

```bash
python3 tool/parity-ext/build-cases.py          # regenerate manifest + fixture
tool/parity-ext/run run                          # React (cached) + Flutter, official diff + site
tool/parity-ext/run run --cases 'components.computers.detail.*' --refresh-react
tool/parity-ext/run publish
```

Text rendering uses the same Chromium flags as the official run (`--disable-lcd-text
--font-render-hinting=none`, see "Text rendering"), so remaining text
differences are layout or style, not rasteriser noise.

### Computers cases (41 surfaces x 3 themes = 123)

Derived from Web `Sidebar.tsx` computers mode + `ComputerRow`,
`MachineDetailPanel.tsx`, `AddMachineDialog.tsx` + `ComputerCommandGuide.tsx`
at raft-source 26f77ef:

* list (240x800 Sidebar column): rows, every row state (online current with
  description, outdated, offline, upgrading, low disk, legacy daemon), empty,
  loading, selected row, hovered row;
* detail (976-wide desktop detail column, 1280x2000 so nothing scrolls):
  whole panel, then one crop per section — header, identity, Name,
  Description, Info, Agents on this computer, Agent Workspaces, Computer
  service card, Recovery guide, Delete;
* detail states: offline (+ its recovery card crop), up to date, upgrading,
  low disk, legacy daemon, one-click upgrade (`remote_computer_upgrade_v2`);
* interactions: editing name / description, agent selection mode, all agents
  selected (bulk bar), scanned workspaces, recovery guide expanded, offline
  install/setup commands expanded, restart in progress;
* dialogs: restart/reset selected agents, stop agents, delete workspace,
  cannot delete (agents assigned), delete computer, Add Computer (type and
  connect steps);
* runtime usage (RuntimeAccountUsageChip, `computer-usage` fixture machine
  with a fresh Claude snapshot and no Codex snapshot, times relative to the
  fixture instant): Info section with the chip health Status, and the usage
  hover card after hovering the Claude chip.

Not covered on purpose: CreateAgentDialog
from "Create" (covered by the official create-agent cases), the Add
Computer "connected" step (needs a live socket event).

### Computers result (run 20261010T134947Z, ea1c3d5)

Report: <http://100.109.192.23:18931/raft_flutter_parity_ext/latest/>
(`raft_flutter_parity_ext/<stamp>`; the official `raft_flutter_parity/` is
untouched).

| | React | Flutter | passing (>96%) | failing | Flutter capture failed |
| --- | --- | --- | --- | --- | --- |
| before (pre-port UI, same suite) | 117 | 18 | 3 | 15 | 99 (no matching section / control) |
| after | 117 | 117 | 23 | 94 | 0 |

Before, the Computer detail was a Material `ListView` (Status / Hostname /
OS / version tiles and an action list) and the rail rows were one-line nav
items, so 99 section, state, interaction and dialog cases had nothing to
capture. After the port every case renders the same structure; all 117
crops have identical sizes on both sides.

Reading the numbers: the official metric is exact-pixel equality, so text
anti-aliasing (light-on-dark mono code, Chromium vs Skia stem darkening)
and Chromium's pixel snapping of borders at fractional layout positions
(the Description line box is 22.75px, so everything below it sits at .75)
keep text-dense crops near 86–95% even when geometry matches. The
remaining delta>24 mismatch per case is 0.5–11%; the highest are the
small row/agent crops (one row of text over a 50px crop) and the bulk bar.
Remaining channel deltas of 1-2 on flat translucent fills are Chromium's
blend arithmetic, not token values: Chromium quantises the colour to 8-bit
RGBA before compositing and its 8-bit pipeline truncates, while Flutter
blends in float and rounds. Checked numerically: brutal `bg-brutal-orange/10`
over white is (254,245,240) in Chromium = alpha 26/255 then truncation,
(254,246,241) in Flutter = alpha 0.1 rounded; elegant-dark `bg-info-soft`
over `layer-panel` is 29.53/46.58/49.78 exactly, Chromium (29,46,49), Flutter
(30,47,50).

### Live agent activity bar cases (8 surfaces x 3 themes = 24)

Derived from Web `components/layout/LiveAgentActivityBar.tsx`
(`LiveAgentActivityBarPresentation`), the raft-ui `liveAgentActivityBar`
recipe, `MainLayout.tsx` / `MobileBottomBarStack.tsx` (placement) and
`utils/liveAgentActivity.ts` (only `working` / `thinking` items show).
`tool/parity-ext/build-live-activity.py` appends the ids
`components.liveactivity.<platform>.<kind>.<theme>` to `cases.json` (run it
after `build-cases.py`); the React side is `host/LiveActivityCases.tsx`, the
Flutter side `test/parity/cases/ext_live_activity.dart`. The capture is the bar
itself (`[data-testid="live-agent-activity-bar"]` / `ValueKey
live-agent-activity-bar`) on the sidebar surface it sits in:

* desktop (240 wide, 1x): the Sidebar `bottomSlot`, inside `border-r` on the
  canvas (brutal: cream); kinds tool-finished, working, thinking, compacting,
  long (truncated);
* mobile (390 wide, 3x): `mobile-live-activity-slot`, elegant floating
  (`fixed inset-x-0 bottom-0`), brutal in flow above the tab bar; kinds
  tool-finished, thinking, long.

Web spec: one strip for the newest live item (`items[0]`, expiry 90 s,
heartbeat refreshes in place, terminal activity clears), flush with its
container (no outer margin). Elegant: `rounded-lg border border-line-muted
bg-layer-panel shadow-raft-md px-3 py-2` (dark: transparent border). Brutal:
`border-t-2 border-black bg-white px-3` (`md:bg-brutal-cream`), no radius or
shadow. Row `min-h-8 items-center gap-2`: 36px agent avatar (`size-9`, 1px
border, black in brutal, pixel art or image), 10px `Status` dot (elegant
semantic warning orange; brutal fixed busy `#FFD440` with a black border), one
ellipsised line of text (elegant 13px sans `foreground-muted`; brutal 14px
mono `black/60`). Nothing is tappable; the text has a hover tooltip. The
220 ms elegant enter/exit motion in raft-ui never runs in the product because
the connected wrapper unmounts instead of passing a null child. Production
Flutter now uses `RaftLiveAgentActivityBar` (`packages/raft_ui`), fed by
`NativeLiveAgentActivityBar` from `ChatAgentPresentation`.

| | before (old bar) | after |
| --- | --- | --- |
| mean pixel-perfect similarity | 70.96 % | 95.78 % |
| passing (basic-pass or better) | 0 / 24 | 11 / 24 |

What changed: floating card instead of a top-bordered strip, 36px avatar
(pixel art was missing before), status dot colours per theme (orange in
elegant, not a fixed yellow), 13px sans / 14px mono text. The remaining
difference is Chromium vs Skia text rasterisation (see "Text rendering").

### Conversation header cases (16 surfaces x 3 themes = 48)

`python3 tool/parity-ext/build-channel-header.py` appends
`components.channelheader.<platform>.<state>.<theme>` (run after
`build-cases.py`; other families are kept). Derived from Web
`ChatPanel.tsx` + `ui/PanelHeader.tsx`, `ChannelDescription.tsx`,
`OverflowSheet.tsx` (OverflowMenuTrigger), `ThreadPanel.tsx` and the raft-ui
`panelHeader` / `conversationPanel` / `panel` (attached edge) recipes.

* React (`host/ChannelHeaderCases.tsx`) mounts the real ChatPanel in the
  desktop main column (1280 - rail 64/56 - 240 sidebar) or the 390 page, and
  ThreadPanel `presentation="side"` in the 400px thread column (mobile: inside
  `.thread-side-column`, as MainLayout), clipped to a window at the top:
  header + Chat/Tasks/Files strip (120px; thread 64px).
* Flutter (`cases/ext_channel_header.dart`) mounts the real `WorkspaceView` at
  the case viewport, opens the channel / DM / thread through the controller
  and clips the same window.
* States: channel with short / long / no description, authored newline in the
  description (the reported bug), private, agent DM, human DM (desktop),
  side thread, hovered Search button (desktop).

Result (`cindy/channel-header`): before 9/48 passing (mean exact-pixel
similarity 0.798; the 3 hover cases had no keyed Search button), after
33/48 (mean 0.965). The 15 remaining are 0.92-0.96: text antialiasing on
Elegant text, sub-pixel baseline offsets (thread title, mobile meta line) and
the tooltip surface of the hover case. All 99 official values are unchanged.

### Settings cases (40 surfaces x 3 themes = 120)

`python3 tool/parity-ext/build-cases.py` also writes
`components.ext-settings.<surface>.<theme>` and
`tool/parity-ext/fixtures/settings.json`. Derived from Web
`layout/Sidebar.tsx` `settingsSidebarGroups` + `SettingsSidebarList.tsx`
(desktop Settings rail: Personal / Workspace / Resources), `SettingsPanel.tsx`
(every Workspace tab and AboutSection), `ReleaseNotesPanel.tsx`
(`/release-notes`) and `AboutFeedbackDialog.tsx` (the
`@botiverse/hands-feedback-react` My Feedback workspace).

* React (`host/SettingsCases.tsx`) mounts the real Sidebar in Settings mode
  (route primed before render) beside SettingsPanel / ReleaseNotesPanel in the
  1216px desktop frame (1280 minus the rail); props select tab, role
  (owner / member / guest) and the resolved server flags (Labs, AI Providers,
  IM Bridges). Flutter (`cases/ext_settings.dart`) mounts `WorkspaceSettings`.
* Crops: the rail (`settings-navigation`), the panel (`settings-panel`), About
  sections, single release cards; states: release notes loading / error /
  empty and feedback empty / loading / error through per-case `routeSets`
  (`{"$pending": true}` never answers, `{"$status": N}` fails) honoured by both
  providers.
* The fixture restates the official spec payloads for the Workspace tabs
  (billing, usage, members, invites, join links, agreement, translation,
  integrations) plus Labs, MCP, release notes and feedback tickets; unmatched
  Flutter requests get the official catch-all body, and Flutter answers flag
  evaluation from the case props. `PARITY_EXT_LOG_REQUESTS=<dir>` lists every
  `/api` request a React case makes.
* The QR code is encoded by `RaftQrMatrix`, a port of the `uqr` encoder Web
  uses (unit-tested module-for-module), from the React host's origin.
* The feedback workspace renders in `ui-sans-serif, system-ui`; product code
  names `system-ui` and the harness maps it to the host's Noto Sans (what
  Chromium's fontconfig picks).

Result (`cindy/parity-settings`):

| group | before | after |
| --- | --- | --- |
| Settings rail (18) | 0 passing, mean 0.810 | 4 passing, mean 0.883 |
| About (15) | 0 passing, 9 capture failures (no sections), mean 0.705 | 9 passing, mean 0.966 |
| Release Notes (24) | 6 passing, 9 capture failures, mean 0.864 | 14 passing, mean 0.970 |
| Feedback (15) | 1 passing, mean 0.795 | 9 passing, mean 0.971 |
| Server Profile, Labs, AI Providers, IM Bridges, MCP (30) | 8 passing | 28 passing, mean 0.979 |
| Plan & Billing, Administration, Applications (18) | 2 passing | 0 passing, mean 0.79 (not ported) |
| total (120) | 17 passing, 18 capture failures | 64 passing, 0 capture failures |

The "before" Workspace tab numbers predate the fixture alignment (Flutter
then answered 404 where React had data), so they are not comparable to the
"after" column; Billing, Administration and Applications still render the
pre-port management pages. The remaining rail delta is text rasterisation and
a 1px sub-pixel heading offset; `nav.row-hover.elegant` (0.04) differs only by
one channel level everywhere in the `bg-fill-strong/80` hover fill (Chromium
quantises the alpha before blending, see the Computers result). Official
set: 98 values unchanged; `components.settings.root.page` (shared rail rows)
0.9743 -> 0.9905.

### Outlier review (select-all, bulk-restart, workspace-scan)

The official `pixelPerfectSimilarity` (visual-testing
`src/sharp-image-diff.mjs`) flattens both PNGs on white, pads them to the
larger size and counts pixels whose RGBA is exactly equal; no threshold, no
alpha effect here (both captures are opaque, same size). An earlier
diagnostic here reported higher equality (76% vs 35.7% for select-all
elegant-dark) because it measured the luminance of the difference image,
which rounds single-channel 1-level differences to 0. Per-channel max delta
(after the fixes below):

| case | equal | delta 1-2 | delta 3-24 | delta >24 |
| --- | --- | --- | --- | --- |
| detail.select-all.elegant-dark | 35.7% | 51.4% | 9.0% | 3.8% |
| dialog.bulk-restart.elegant-dark | 71.4% | 21.3% | 3.9% | 3.5% |
| detail.workspaces-scanned.brutal | 74.2% | 16.6% | 3.9% | 5.3% |

* delta 1-2: the large selected/tinted fills (blend arithmetic above).
* delta 3-24: full-width single-pixel rows at border and fill edges. Total
  coverage is equal, distributed differently: Flutter paints the edge at the
  layout's .75 position (anti-aliased), Chromium snaps border and background
  edges to whole pixels. Same offset on every edge of a crop, so no layout
  drift.
* Real differences found and fixed: (1) elegant Avatar is `border-2
  border-transparent bg-clip-padding`; `RaftAvatarSlot` painted `fill-muted`
  under the transparent border, a visible ring on tinted rows (no official
  case changes: all 99 official values are identical with and without it);
  (2) the bulk-restart option cards (`Card` root `border-[0.5px] ...
  dark:border-transparent`) drew a 1px `line-muted` ring in elegant-dark and
  dropped the `shadow-raft-xs` inset top light. The card edge profiles now
  match Chromium to within 1 level.

## Known harness limitations

* React baseline fonts deviate from the official spec on purpose (production
  Google Fonts, see "Baseline fonts").
* Flutter captures are host `flutter test` rasters (software Skia, Linux), not
  Android device screenshots; Impeller/GPU antialiasing on a phone can differ
  slightly. Fonts are the app's bundled fonts; CJK/emoji come from the host's
  Noto files because flutter_test has no OS fallback chain (`sans-serif` is
  mapped to Noto Color Emoji to stand in for Android's emoji fallback).
* No injectable clock: product code that calls `DateTime.now()` renders with
  the host clock (TZ is pinned to Asia/Shanghai). Current fixtures' labels are
  unaffected, but relative-time labels could drift.
* `ctx.target` only wraps widgets the builder creates; rows deep inside a
  product composite (message rows in `RaftChatView`) are captured through a
  clipped window aligned to React's element rect, so style probes there
  include neighbouring paragraphs.
* The mobile nav, mobile home header, create-channel dialog and settings
  destination list are public product widgets (`WorkspaceMobileTabBar`,
  `WorkspaceMobileHomeHeader`, `CreateChannelDialog`, `WorkspaceSettings`)
  that both `WorkspaceView` and the builders mount; no builder copies app code.
* State substitutions are documented per case in `notes` and in metadata
  (`flutter.notes`), e.g. create-agent dialogs (React never selects a runtime
  because its host lacks the runtime-options mock), composer image preview
  (React baseline shows an upload-limit error state), lifecycle actions
  (Flutter has no "More actions" menu; its restart confirmation is captured).
* Several React baselines have fixture defects (raw markdown/HTML shown in
  mono in some `message-row.md-*` cases; notification-center empty). These
  are measured as-is; they lower scores without being Flutter gaps.
* The React baseline was captured from a raft-source checkout at 26f77ef with
  pre-existing local edits (additive diagnostic cases in
  `VisualTestingCases.tsx`); see `build/parity/react-source.json`.
