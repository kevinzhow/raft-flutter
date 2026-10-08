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
| React baseline | official `cli.mjs capture --providers react --manifest shared` (Playwright + `packages/web/visual-testing` Vite host, 390x844 @3x) | `visual-testing-results/react/<case>.png` + `.metadata.json` |
| Flutter provider | `flutter test apps/raft_flutter/test/parity/parity_capture_test.dart`, sharded | `visual-testing-results/android/<case>.png` + `.metadata.json`, `android-case-map.json` |
| Diff | official `cli.mjs diff --pairs react__android --manifest shared` | `visual-testing-results/diff/react__android*` |
| Site | official `cli.mjs site --pairs react__android --skip-analysis --site-dir build/parity/site` | `site/` (storybook-style home, `latest/`, `runs/<id>/`) |
| Summary | `tool/parity` reads the official diff JSON + Flutter case map | `summary.json` (also `site/flutter-parity-summary.json`) |

The CLI runs with `SLOCK_VISUAL_REPO_ROOT=build/parity` and
`SLOCK_REACT_REPO_DIR=<raft-source>`, so every result lands outside the
raft-source tree (Playwright's scratch `packages/web/test-results/` is the only
write there; it is untracked).

Exact React baseline command used for the current cache (run from
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
