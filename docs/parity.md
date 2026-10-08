# Visual parity against the official Raft tool

raft-flutter is measured with the Raft team's own cross-platform visual
parity tool (`raft-source/packages/visual-testing`, CLI `src/cli.mjs`), not a
home-grown differ. The Flutter app is plugged in as a **provider**: it writes
captures in the official provider output contract and the official CLI does
`diff`, `site` and all scoring.

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
* Some app compositions live in private `WorkspaceView` methods (mobile nav,
  mobile home header, create-channel, settings destination list); those
  builders copy that code and say so in `notes` — if the app changes, the
  copy must follow.
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
