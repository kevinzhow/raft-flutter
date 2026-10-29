# Performance lab

The perf lab measures the cost of every frame in fixed chat scenarios in profile mode.

- **Target:** each frame's UI-thread work and raster work fits in **8.33 ms**. That is the 120 Hz budget, and meeting it also gives 60 Hz headroom.
- **Acceptance gate (current, Linux 60 Hz):**
  - No UI or raster frame exceeds **16.7 ms**.
  - No stutter, meaning no vsync is skipped during continuous motion.

The Linux embedder runs at the display rate (59.92 Hz here). On Linux the lab therefore measures CPU and GPU work per frame, not FPS.

The lab complements P01 (`docs/message-performance.md`). P01 is the regression gate against a fixed reference. The lab explains where the time goes.

Mobile routing investigations also use the opt-in [route frame probe](route-performance-probe.md).

## Run it

```bash
# Linux (X11 session of the logged-in desktop)
export DISPLAY=:0 GDK_BACKEND=x11 XAUTHORITY=$(ls /run/user/1000/.mutter-Xwaylandauth.* | head -1)
python3 tool/performance/lab.py run --out .local/performance/lab/<name>            # both light themes, ~10 min
python3 tool/performance/lab.py run --out .local/performance/lab/<name> --scenarios steady-scroll,mount-*
python3 tool/performance/lab.py compare .local/performance/lab/<before> .local/performance/lab/<after>
python3 tool/performance/lab.py summarize .local/performance/lab/<name>            # rebuild summary.md/json
```

### `run` options

| Option | Effect |
|---|---|
| `--themes` | Themes to measure. Default `brutal-light,elegant-light`. |
| `--seconds` | Length of the continuous scenarios. Default 8. |
| `--semantics platform\|on\|off` | Semantics tree mode. Default `platform`, explained below. |
| `--no-trace` | Turns off framework phase collection and the engine timeline. Timings are cleanest, but there is no phase or raster attribution. |
| `--reference DIR` | Runs `compare` against `DIR` when the run finishes. |
| `-- <flutter drive args>` | Passes extra arguments through, for example `-- --no-enable-impeller`. |

### Diagnostic switches (environment of the app or driver)

| Variable | Effect |
|---|---|
| `RAFT_LAB_DEEP=1` | The driver keeps long self/inclusive/app lists and a pruned top-down call tree (`callTree`) of all CPU samples in `*.attribution.json`. Pair it with `FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=dart-flags=--max_profile_depth=600`, otherwise deep widget stacks lose their leaf frames. Native frames outside the VM (engine text/font code, GC) arrive without Dart callers. |
| `RAFT_LAB_FONT_KEYS=1` | After every frame the lab walks the render tree for text and writes a `fontKeys` note for each font combination (family, fallback list, weight, slant, variations, locale) that the idle font warm-up (`raftFontWarmUpStyles`) does not cover. The first use of such a combination is a 50-200 ms engine stall. |
| `RAFT_LAB_IDLE_SECONDS` | Length of the `idle-final` scenario (default 30): no input, window visible, after the last theme's scenarios. Select it with `--scenarios ...,idle-final`. **Not an idle proof:** the lab runs under the integration/test binding, which schedules a frame after every frame, so this phase shows ~60-120 frames/s and busy CPU. Measure real idle with `tool/idle-cpu/run.sh` (plain app, real workspace view). |

Every scenario record has `cpuSeconds` (whole process) and, on Linux, `uiThreadCpuSeconds` (on-CPU time of the Dart UI thread). On a busy host wall-clock frame times grow, CPU time much less; `mount-*` steps also record `cpuUs` per jump, and the summary prints the per-row UI-thread CPU. Prefer it when other work shares the machine.

### Run safeguards

- **Android isolation.** Android runs require a prebuilt APK whose aapt package identity is `app.raft.raft_flutter.linkperf`; the runner forces `--keep-app-running`. It refuses source-only drive or the official App APK. See [installation workflow](android-installation.md). Merely changing applicationId while retaining the official namespace is not safe for Flutter drive cleanup.

- **Single instance.** The app allows one instance per display. Before each launch, `run` waits for any other `bundle/raft_flutter` to exit (`--wait`). It retries a launch that lost the race.
- **Host load.** `run` refuses to start while the 1-minute load average is above 0.35 × CPUs (`--max-load`, `--wait-quiet`).
  - Contention distorts these numbers badly. One run taken at load 13–25, while other agents' test suites were running, measured 2–5× slower frames, including raster.
  - A run whose load ends above the limit is labelled **NOISY**, and `compare` warns about it.

### Output

`run` writes to the output directory. That directory is under `.local/` and is never committed.

| File | Contents |
|---|---|
| `<theme>-<scenario>.json` | Raw frames: vsync, build start, UI-thread time, raster start and duration, per-frame phase times, plus scenario extras. |
| `<theme>-<scenario>.attribution.json` | Host sampler output: CPU samples of the 5 worst UI frames, engine timeline events of the 5 worst raster frames, GC count and GC events. |
| `env.json` | Commit, Flutter/engine, renderer, CPU, GPU, host load. |
| `lab-hello.json` | Display Hz, DPR, semantics, VM profiler flags. |
| `summary.json`, `summary.md` | The summary. |
| `compare-<base>.md/.json` | Comparison output. |

`compare` flags a regression when any of these happen:

- UI or raster p90/p99 grows by more than 10% and by more than 0.5 ms.
- The count of frames over 16.7 ms grows.
- Stutter grows.
- The share of frames over 8.33 ms grows by more than 2 points.
- The 60 Hz gate goes from pass to fail.
- The per-row mount p50 grows.

`compare` also warns when fixture version, engine, CPU/GPU/renderer, view size or host load differ.

## Files

| File | Role |
|---|---|
| `apps/raft_flutter/integration_test/perf_lab_test.dart` | Scenarios. Uses a desktop split host: `RaftChatView`, plus a 440 px thread pane when a thread is open. |
| `apps/raft_flutter/integration_test/perf_lab/fixtures.dart` | Fixed content (`fixtureVersion`), the dio route adapter, the realtime event client, and a loopback PNG server. |
| `apps/raft_flutter/integration_test/perf_lab/navigation_activity.dart` | Mutable server/event replay during every `nav-*` entry and return, with assertions against accepted production state. |
| `apps/raft_flutter/integration_test/perf_lab/navigation_host.dart` | Fresh background SQLite cache and platform delivery seam for the actual `RaftApp` navigation host. |
| `apps/raft_flutter/integration_test/perf_lab/probe.dart` | FrameTiming capture, framework phase blocks, clock alignment, implementation-neutral finders, and the sampler handshake. |
| `apps/raft_flutter/test_driver/perf_lab_driver.dart` | The `flutter drive` driver. It also acts as the VM-service sampler and writes every file on the host. |
| `tool/performance/lab.py` | `run`, `summarize`, `compare`. Unit tests are in `tool/tests/test_perf_lab.py`. |

The lab does not change product code.

The lab is robust to the list implementation:

- It finds rows only by the product's `ValueKey('message-<id>')`.
- It finds the timeline as the vertical `Scrollable` under `RaftChatView` with the most scrollable content.
- "Older" and "latest" are derived from the scroll position's axis direction. This works for reversed lists, for top-anchored lists, and for the two-sided center sliver introduced in `2b3f334`.

## Scenarios

All channels come from the product's own network-page path, through a mock dio adapter.

### Mobile navigation with background data changes (fixture v4)

`nav-*` scenarios launch the production `RaftApp`, including its root router,
session restore, system-font theme, retained mobile pages and background SQLite
cache. They do not mount a static approximation of a detail page. Each theme
gets a fresh named SQLite database, so a previous build cannot warm its disk
cache. The isolated package remains `app.raft.raft_flutter.linkperf`.

During each entry and return, a fixed replay overlaps the transition:

- A teammate creates a message with PNG attachments or long Markdown, edits
  it, and changes its task state with the production `message:updated` contract.
- Another channel receives a message while offscreen; its accepted ledger
  remains available on the next visit.
- K8+ accepts a newer machine status version. Agent activity changes, an Agent
  is created/deleted, and an Agent edit triggers the production directory's
  debounced HTTP revalidation. No manual `setState` substitutes for an event.
- HTTP responses are asynchronous (80 ms transport delay plus the existing
  message-page delay); image responses arrive after 120 ms. Real PNG decoding,
  attachment URL resolution, read receipts and coalesced cache writes run.
- Android returns dispatch the system's `flutter/backgesture` protocol to the
  production route, including a held progress interval. A rejected predictive
  return fails the run. This is a reproducible protocol replay on the phone;
  actual physical gestures still need the formal-App ADB capture.

Every `opens` entry contains `liveActivity.events`, acceptance counts checked
against the message ledger/entity directory, workspace notification count,
request/response counts, image requests, cache reads/completed writes and
predictive-back count. An ignored event or a failed refresh fails the scenario.
All mutation timers are joined before the next transition. The original static
captures remain historical controls, not acceptance evidence for this workload.
`summary.json` also aggregates these counters under `navigationActivity`, so
frame improvements can be reviewed alongside the work actually completed.

The replay covers behaviours observed in the real-App investigation and their
production handlers. Its fixed event rates and latency are controlled inputs,
not an exact recording of the production server. Network transport/socket
delivery and OS push/link/share delivery are replaced locally; the UI, routing,
reducers and database remain production code. Compare only identical v4 inputs,
engine, renderer, view and semantics, and retain host-noise warnings.

```bash
python3 tool/performance/android_transitions.py --device <serial> \
  --out .local/performance/navigation-live/<run> --themes brutal-light \
  --scenarios nav-computer-detail,nav-home-channel,nav-channel-thread
```

Do not pass `--no-pub` when switching between an integration/profile build and
a normal release build. The pinned SDK also skips platform plugin registration
when that option is used. Regenerate tooling for the actual build mode so the
profile App includes `integration_test` and the normal release excludes it.

**Mixed history.** 600 rows in a fixed 20-row cycle:

| Row kind | Share |
|---|---|
| Plain CJK/Latin/emoji text | 40% |
| Long CJK Markdown | 15% |
| 30-line code block | 10% |
| 1–3 PNG images | 10% |
| Reactions (6 emoji) | 10% |
| PDF/zip attachments | 5% |
| Thread summary | 5% |
| Task chip | 5% |

**Images.** Generated PNGs of 1600×1200, 1200×1600, 2048×1152 and 800×800, with photographic entropy, served from 127.0.0.1.

| Scenario | What it does | Gate kind |
|---|---|---|
| `steady-scroll` | Scrolls 1200 px/s toward older history for 8 s (`animateTo`, linear). | continuous |
| `fling` | Six ballistic flings at 6000 px/s through the list's own physics (`goBallistic`), alternating direction. | fling |
| `image-scroll` | Steady 1200 px/s through 240 photo rows (1–3 large PNGs each). The in-memory image cache churns. | continuous |
| `older-drag` | Touch drag at 1800 px/s, held for 8 s, starting from the newest 50 rows of a 300-row channel. The older page (250 ms latency) lands mid-drag. | continuous |
| `scrollbar-drag` | Desktop only. A mouse holds the timeline's scrollbar thumb in the 600-row channel and drags it from the latest end to the top of the track and back, each way over half the scenario. Records `thumbErrorMaxPx` (sampled distance between the thumb and the pointer; must stay within 2 px) and `olderPagesServed`. | continuous |
| `scrollbar-sweep` | As `scrollbar-drag`, but full-track sweeps of 500 ms each way for the whole scenario: every frame jumps several screens. | continuous |
| `arrival-scrolled-up` | The reader drags 2.5k px up. Then 4 `message:new` events per second from teammates arrive for 8 s. Records `anchorDriftPx` of the row being read, which must be 0. | events |
| `resize` | Drives the engine view's size every frame, 700–940 px wide. This measures app relayout only; see the platform notes. | continuous |
| `open-cold` | First visits to two channels. The page arrives after 150 ms. Records time-to-visible of the newest row and that open's worst frame. | transitions |
| `open-warm` | Revisits, including the 600-row channel. The cached window shows first, then the network refresh lands. | transitions |
| `channel-switch` | Ten rapid switches between two warm channels, 300 ms dwell. | transitions |
| `thread-open` | A cold thread open (150 ms network), then four cached reopens, closing in between. | transitions |
| `section-drag` | Mobile opt-in: hold Chat toward Tasks, oscillate within the page, then roll back. Requires populated/warmed Chat, Tasks and Files. | continuous |
| `section-back-drag` | Mobile opt-in: fully accept Tasks, then hold a reverse drag exposing Chat and roll back to Tasks. | continuous |
| `section-cycle` | Mobile opt-in: Chat → Tasks → Files → Tasks → Chat twice, checking accepted sections. | transitions |
| `mount-<kind>` | One channel per row kind with 120 rows of that kind. Jumps 0.9 viewport per step. Per-row cost = UI time of the mounting frame ÷ rows mounted in it. Kinds: plain, markdown, code, image, attachments, reactions, thread-summary, task. | mount |
| `keyboard` | On the chat page, taps the composer and slides the soft-keyboard inset open and closed. An unfiltered Android run includes it. A desktop run includes it only with `--scenarios keyboard`. The measured windows are the inset slides, not the hold between them. The report shows the worst UI and raster milliseconds of those frames, how many exceed 8.33 ms and 16.7 ms, the build, layout and paint counts of each frame, and the UI thread's on-CPU time during the slides. | keyboard |

Mobile section scenarios require explicit selection and a mobile viewport. They warm 600 task-tagged messages, 600 tasks and 240 PNG files, asserting visible tags, actual cards and decoded thumbnails before timing. They are not included implicitly in desktop runs. The `keyboard` scene is not part of a default desktop run. Compile scenario/theme defines into the isolated APK; changing runner options does not override defines baked into a prebuilt artifact.

This build's VM timeline events do not carry `tts` or `tdur` on the UI or raster thread. The host sampler still counts that absence. Scene CPU is the change in the first field of `/proc/<pid>/task/<tid>/schedstat`, nanoseconds spent on CPU, from scenario start to scenario end. The raster thread is the kernel name `1.raster`, or `io.flutter.rast` when the 15-character comm truncates `io.flutter.raster`. The UI thread is `1.ui` or `io.flutter.ui` when that name exists. Otherwise it is the main thread, because Android merges the UI task onto the platform thread, and the report prints that kernel name. It is a whole-scene total, not a per-frame number. The slide's schedstat total is a separate number and stays empty on Android. Rounds inside one launch share a cache, so the independent sample is the launch batch, not the round. Pair one old-build launch with one new-build launch and resample those launches whole with `cluster_ratio_ci`. `paired_ratio_ci` resamples rounds and is not that count. Neither is what `compare` flags yet. Each launch records one warmup keyboard cycle. That cycle is marked `warmup` and is not a sample. The record also stores the round index, whether the fixture was reset, the scenario-clock window, and the host load. `RAFT_LAB_BATCH`, `RAFT_LAB_PAIR` and `RAFT_LAB_ORDER` name the launch when the host alternates an old batch with a new batch.

For read-only native evidence, start this watcher against a new output directory **before** the runner:

```bash
python3 tool/performance/capture_sections.py --device <device> --run .local/performance/lab/<new-name>
```

It watches capture notes, verifies that the isolated fixture is resumed, saves ADB screenshots, and records/pulls the requested video. It does not install applications or send input. Completed directories are refused. Reverse screenshots/video setup for forward/cycle runs is outside measured intervals; the dedicated back-drag scenario skips that setup. Install the official release separately through `tool/android-install`, after profiling completes.

### Metrics

- **UI thread time per frame.** From the engine build start to the end of the frame's last pipeline block. It covers build, layout, paint, compositing, and also the semantics, finalize-tree and post-frame work that runs after the engine's build span ends at scene submission.
  - Engine `FrameTiming.buildDuration` misses that post-submission work. With semantics on it adds 10–40%.
  - The summary keeps both: `uiUs` (UI thread) and `uiBuildUs` (engine build span).
- **Phases.** `FlutterTimeline` block collection in profile mode: BUILD, LAYOUT, PAINT, COMPOSITING, SEMANTICS, FINALIZE TREE, POST_FRAME.
  - Lazy slivers build their children during LAYOUT, so most row construction appears as "layout".
- **Worst-frame attribution.**
  - UI thread: the host sampler takes Dart VM CPU samples, native frames included, at 1 kHz. It keeps those inside the five worst UI frames (±1 ms) and reports:
    - top inclusive and self functions
    - app-code functions (`appInclusive`)
    - cost categories: font fallback, text layout, build, layout, paint, semantics, Markdown, image decode
  - Raster: engine (Embedder stream) timeline events inside the five worst raster frames.
  - Category shares are lower bounds. A sample whose native stack cannot be walked back into Dart is counted in no category.
- **Clock alignment.** FrameTiming uses the engine clock; samples and blocks use the Dart timeline clock. They are aligned from a persistent frame callback, and the summary records `clockMatched`.
- **Stutter.** For continuous scenarios only: a frame that starts more than 1.5 vsync periods after the previous one.
- **Over-budget counts.** Frames whose UI or raster time exceeds 8.33 ms or 16.7 ms.

### Fairness and determinism

- **Fixed inputs.** Content, sizes and network latencies are fixed. Bump `fixtureVersion` whenever any of them changes; `compare` warns across versions.
- **Fresh workspace, warm process.** Each theme gets a fresh workspace, so "cold" means a cold app state. Process-level caches persist after the first theme: fonts, glyph atlases, the fontconfig cache. Swapping theme order (`elegant,brutal`) moved build p90 by less than run-to-run noise.
- **View size.** On this machine the view is whatever the window manager allows. The Xwayland root is 1024×768, so the 1280×720 default window becomes 1009×741 or 957×689 logical px depending on WM state. Overriding the view size in-process is not possible: the engine drops frames whose size does not match the surface. The size is recorded per scenario, and `compare` warns when it differs.
- **Instrumentation overhead.** A run with `--no-trace` (no phase blocks, no Embedder/GC timeline) matched the traced run's engine build p50/p90 and raster p90 within run-to-run noise (±10%).
- **Semantics.** The Linux GTK embedder enables semantics unconditionally (`platformSemanticsEnabled: true`), so Linux users always pay for the semantics tree. macOS enables it only when assistive technology is active. The default `platform` mode measures the Linux reality; `--semantics off` models a typical Mac.

## Baseline (this machine)

**Environment**

| Item | Value |
|---|---|
| CPU | AMD Ryzen 7 8845HS, 16 threads |
| GPU | AMD Radeon 780M (radeonsi) |
| OS | Ubuntu, Linux 7.0, GNOME/Mutter Xwayland |
| Flutter | 3.47.6 (engine `692136cb65`), profile mode |
| Renderer | **Impeller (OpenGLES)**, detected from raster events (`ReactorGLES::React`, `RenderPassGLES`) |
| Display | 59.92 Hz, DPR 1.0 |
| Semantics | Embedder-enabled |

The runs below were taken on a quiet host, with start load between 2.4 and 5.8. A run taken while other agents were running test suites (load 13–25) was 2–5× slower, raster included. It is kept out of this report.

Run `baseline-2b3f334`: product `2b3f334` plus the lab, fixture `perf-lab-fixture-v1`, view 1009x741 px, semantics `platform` (embedder on), host load at start 3.4.

### Frames per scenario

UI is UI-thread time and raster is raster-thread time, in ms: p50 / p90 / p99 / max.

| Scenario | Theme | Frames | UI thread | Raster | Frames > 8.33 ms (either) | > 16.7 ms UI / raster | Stutter | GC | Semantics % of UI | 60 Hz gate |
|---|---|---|---|---|---|---|---|---|---|---|
| steady-scroll | brutal | 464 | 1.1 / 3.8 / 9.0 / 162.2 | 2.3 / 3.0 / 3.8 / 21.1 | 1.1% | 3 / 1 | 3 | 54 | 25.1 | **fail** |
| steady-scroll | elegant | 447 | 1.1 / 4.0 / 11.2 / 223.3 | 2.3 / 2.8 / 3.5 / 4.3 | 1.8% | 4 / 0 | 4 | 50 | 19.1 | **fail** |
| fling | brutal | 696 | 1.2 / 4.5 / 8.6 / 10.6 | 2.5 / 3.1 / 3.6 / 4.2 | 1.1% | 0 / 0 | 0 | 90 | 28.5 | pass |
| fling | elegant | 696 | 1.2 / 4.5 / 9.2 / 12.4 | 2.3 / 2.8 / 3.4 / 4.0 | 1.4% | 0 / 0 | 0 | 84 | 27.2 | pass |
| image-scroll | brutal | 482 | 1.3 / 3.9 / 7.4 / 9.2 | 1.9 / 2.4 / 3.0 / 7.4 | 0.2% | 0 / 0 | 0 | 114 | 39.0 | pass |
| image-scroll | elegant | 482 | 1.2 / 3.0 / 6.7 / 8.7 | 1.8 / 2.1 / 3.0 / 4.7 | 0.2% | 0 / 0 | 0 | 100 | 38.7 | pass |
| older-drag | brutal | 499 | 0.4 / 0.5 / 0.9 / 5.7 | 2.6 / 2.9 / 3.2 / 3.3 | 0.0% | 0 / 0 | 0 | 6 | 37.6 | pass |
| older-drag | elegant | 499 | 0.4 / 0.4 / 0.5 / 5.0 | 2.7 / 3.0 / 3.9 / 4.5 | 0.0% | 0 / 0 | 0 | 6 | 36.0 | pass |
| arrival-scrolled-up | brutal | 473 | 0.7 / 1.4 / 14.9 / 27.9 | 2.0 / 2.5 / 3.0 / 4.2 | 7.0% | 3 / 0 | 0 | 57 | 8.6 | **fail** |
| arrival-scrolled-up | elegant | 474 | 0.8 / 1.6 / 16.2 / 19.5 | 2.5 / 3.1 / 3.8 / 4.1 | 7.0% | 2 / 0 | 0 | 61 | 8.6 | **fail** |
| resize | brutal | 470 | 7.9 / 11.5 / 13.9 / 16.8 | 0.0 / 0.0 / 0.0 / 2.2 | 32.6% | 1 / 0 | 11 | 243 | 17.6 | **fail** |
| resize | elegant | 473 | 8.6 / 10.3 / 15.0 / 122.2 | 0.0 / 0.0 / 0.0 / 2.8 | 61.3% | 1 / 0 | 2 | 208 | 15.9 | **fail** |
| open-cold | brutal | 105 | 0.1 / 0.9 / 14.0 / 14.7 | 2.2 / 2.4 / 3.0 / 9.1 | 2.9% | 0 / 0 | 0 | 13 | 14.0 | pass |
| open-cold | elegant | 106 | 0.2 / 1.5 / 16.9 / 17.3 | 2.5 / 2.9 / 4.0 / 4.4 | 1.9% | 2 / 0 | 0 | 10 | 12.3 | **fail** |
| open-warm | brutal | 137 | 0.1 / 0.3 / 22.5 / 25.8 | 2.3 / 2.5 / 2.9 / 3.0 | 5.1% | 4 / 0 | 0 | 23 | 7.2 | **fail** |
| open-warm | elegant | 137 | 0.1 / 0.3 / 29.7 / 31.4 | 2.3 / 2.6 / 3.1 / 3.3 | 7.3% | 3 / 0 | 0 | 18 | 11.7 | **fail** |
| channel-switch | brutal | 189 | 0.1 / 8.9 / 21.1 / 21.3 | 2.3 / 2.6 / 3.0 / 3.6 | 11.1% | 10 / 0 | 0 | 50 | 10.0 | **fail** |
| channel-switch | elegant | 190 | 0.1 / 10.3 / 21.6 / 23.0 | 2.1 / 2.6 / 3.2 / 3.7 | 11.6% | 10 / 0 | 0 | 46 | 12.7 | **fail** |
| thread-open | brutal | 259 | 0.2 / 7.2 / 23.1 / 23.9 | 2.3 / 2.6 / 3.5 / 3.8 | 9.3% | 15 / 0 | 0 | 48 | 13.1 | **fail** |
| thread-open | elegant | 260 | 0.3 / 8.2 / 23.9 / 28.3 | 2.8 / 3.5 / 3.8 / 5.5 | 10.0% | 17 / 0 | 0 | 47 | 11.7 | **fail** |

### New-row mount cost

Each step jumps 0.9 viewport into fresh rows of one kind.

| Row kind | Theme | Rows | Per row, µs (p50 / p90) | Mounting frame, ms (p50 / max) | Frames > 16.7 ms | Follow-up frames, ms (p50) |
|---|---|---|---|---|---|---|
| plain | brutal | 106 | 2309 / 2977 | 19.6 / 27.2 | 12 | 2.0 |
| plain | elegant | 108 | 2294 / 3144 | 17.2 / 23.4 | 10 | 2.2 |
| markdown | brutal | 52 | 4562 / 5354 | 9.4 / 14.0 | 0 | 1.6 |
| markdown | elegant | 50 | 4352 / 4970 | 8.8 / 13.0 | 0 | 1.7 |
| code | brutal | 35 | 10656 / 11748 | 12.8 / 22.1 | 7 | 2.9 |
| code | elegant | 34 | 9054 / 13180 | 13.2 / 21.5 | 3 | 3.3 |
| image | brutal | 53 | 6157 / 7628 | 13.1 / 19.0 | 4 | 11.1 |
| image | elegant | 52 | 5729 / 8735 | 11.9 / 18.9 | 3 | 10.7 |
| attachments | brutal | 91 | 4162 / 5257 | 16.5 / 23.5 | 8 | 1.7 |
| attachments | elegant | 85 | 3969 / 5112 | 13.0 / 20.6 | 5 | 1.7 |
| reactions | brutal | 110 | 4908 / 5821 | 29.6 / 34.9 | 18 | 1.9 |
| reactions | elegant | 110 | 4710 / 5614 | 27.8 / 39.7 | 19 | 2.1 |
| thread-summary | brutal | 89 | 3648 / 4297 | 13.7 / 20.0 | 2 | 1.5 |
| thread-summary | elegant | 79 | 3303 / 5435 | 10.7 / 28.9 | 4 | 1.6 |
| task | brutal | 110 | 3088 / 3887 | 18.5 / 25.3 | 16 | 1.8 |
| task | elegant | 110 | 2662 / 3699 | 15.6 / 27.0 | 7 | 2.1 |

### Transitions

| Scenario | Theme | Opens | Newest row visible, ms (p50 / max) | Worst UI frame per open, ms |
|---|---|---|---|---|
| open-cold | brutal | 2 | 192 / 200 | 14.0, 14.7 |
| open-cold | elegant | 2 | 189 / 200 | 17.3, 16.9 |
| open-warm | brutal | 3 | 33 / 210 | 25.8, 18.4, 18.8 |
| open-warm | elegant | 3 | 23 / 218 | 31.4, 19.0, 14.9 |
| channel-switch | brutal | 10 | 28 / 31 | 19.2, 20.6, 18.1, 19.6, 20.5, 20.0, 19.3, 21.1, 19.1, 21.3 |
| channel-switch | elegant | 10 | 29 / 31 | 20.9, 21.4, 21.6, 22.9, 18.5, 18.4, 20.9, 18.1, 18.6, 20.2 |
| thread-open | brutal | 5 | 86 / 239 | 23.8, 23.9, 22.2, 22.2, 23.1 |
| thread-open | elegant | 5 | 84 / 240 | 28.3, 24.3, 22.0, 23.9, 21.1 |

### Semantics on (Linux default) vs off (typical macOS), elegant-light (`sem-off-2b3f334`)

| Scenario | Semantics % of UI | UI p50 / p90 / p99, on → off (ms) | Frames > 8.33 ms, on → off | UI > 16.7 ms, on → off |
|---|---|---|---|---|
| steady-scroll | 19.1 | 1.1/4.0/11.2 → 0.5/2.9/8.9 | 1.8% → 1.3% | 4 → 4 |
| fling | 27.2 | 1.2/4.5/9.2 → 0.6/3.2/6.7 | 1.4% → 0.0% | 0 → 0 |
| image-scroll | 38.7 | 1.2/3.0/6.7 → 0.5/2.3/4.9 | 0.2% → 0.2% | 0 → 0 |
| older-drag | 36.0 | 0.4/0.4/0.5 → 0.4/3.5/8.1 | 0.0% → 0.8% | 0 → 0 |
| arrival-scrolled-up | 8.6 | 0.8/1.6/16.2 → 0.1/0.9/13.3 | 7.0% → 5.9% | 2 → 0 |
| resize | 15.9 | 8.6/10.3/15.0 → 6.4/7.7/10.1 | 61.3% → 5.7% | 1 → 1 |
| open-cold | 12.3 | 0.2/1.5/16.9 → 0.1/0.5/15.4 | 1.9% → 2.9% | 2 → 1 |
| open-warm | 11.7 | 0.1/0.3/29.7 → 0.1/0.2/17.9 | 7.3% → 4.4% | 3 → 2 |
| channel-switch | 12.7 | 0.1/10.3/21.6 → 0.1/7.6/23.4 | 11.6% → 8.5% | 10 → 6 |
| thread-open | 11.7 | 0.3/8.2/23.9 → 0.2/6.5/19.1 | 10.0% → 10.0% | 17 → 5 |
| mount-plain | 12.1 | 0.2/15.4/22.0 → 0.1/12.0/23.0 | 10.9% → 10.3% | 10 → 2 |
| mount-markdown | 15.9 | 0.2/7.9/12.3 → 0.2/5.6/7.6 | 9.3% → 0.5% | 0 → 0 |
| mount-code | 9.8 | 0.2/9.3/19.1 → 0.2/9.2/15.5 | 11.7% → 11.9% | 3 → 0 |
| mount-image | 25.2 | 1.4/9.3/17.9 → 0.7/8.9/13.4 | 11.6% → 11.6% | 3 → 0 |
| mount-attachments | 16.6 | 0.1/10.7/19.4 → 0.2/10.2/13.3 | 11.9% → 11.8% | 5 → 0 |
| mount-reactions | 14.9 | 0.2/24.3/31.9 → 0.2/16.0/26.5 | 11.3% → 11.7% | 19 → 15 |
| mount-thread-summary | 10.5 | 0.2/9.7/18.8 → 0.2/8.6/12.9 | 11.7% → 10.8% | 4 → 0 |
| mount-task | 13.1 | 0.2/15.0/22.2 → 0.2/11.3/13.8 | 11.2% → 10.4% | 7 → 0 |

### List rewrite: `baseline-ed1eced` → `baseline-2b3f334`

Both runs used fixture v1 on a quiet host, brutal-light. The v1 `older-drag` and `arrival-scrolled-up` are omitted because their drags and arrivals were not valid yet.

| Scenario | UI p99 (ms) | UI max (ms) | UI > 16.7 ms | Visible ms p50 / per-row µs p50 |
|---|---|---|---|---|
| steady-scroll | 8.1 → 9.0 | 157.9 → 162.2 | 4 → 3 |  |
| fling | 8.8 → 8.6 | 11.5 → 10.6 | 0 → 0 |  |
| image-scroll | 8.6 → 7.4 | 18.7 → 9.2 | 1 → 0 |  |
| resize | 27.1 → 13.9 | 29.5 → 16.8 | 56 → 1 |  |
| open-cold | 24.8 → 14.0 | 32.1 → 14.7 | 3 → 0 | 287 → 192 ms |
| open-warm | 39.3 → 22.5 | 55.0 → 25.8 | 6 → 4 | 99 → 33 ms |
| channel-switch | 56.9 → 21.1 | 62.5 → 21.3 | 18 → 10 | 109 → 28 ms |
| thread-open | 112.7 → 23.1 | 159.0 → 23.9 | 29 → 15 | 986 → 86 ms |
| mount-plain | 49.2 → 26.8 | 54.8 → 27.2 | 12 → 12 | 4017 → 2309 µs |
| mount-markdown | 17.5 → 13.9 | 21.4 → 14.0 | 4 → 0 | 5936 → 4562 µs |
| mount-code | 48.6 → 21.3 | 67.7 → 22.1 | 21 → 7 | 18581 → 10656 µs |
| mount-image | 29.5 → 18.8 | 37.1 → 19.0 | 17 → 4 | 9009 → 6157 µs |
| mount-attachments | 35.8 → 21.0 | 37.3 → 23.5 | 24 → 8 | 6125 → 4162 µs |
| mount-reactions | 64.9 → 34.6 | 71.4 → 34.9 | 18 → 18 | 7511 → 4908 µs |
| mount-thread-summary | 27.8 → 15.3 | 30.2 → 20.0 | 21 → 2 | 5085 → 3648 µs |
| mount-task | 37.3 → 24.4 | 37.8 → 25.3 | 17 → 16 | 4505 → 3088 µs |

In the fixture-v1 run above, `older-drag` (the drag did not move with semantics on) and `arrival-scrolled-up` (the arrivals were the user's own messages) were not valid. Use fixture v2 for those two scenarios.

## Worst offenders (ranked by frame-budget damage)

Numbers come from the quiet runs on `2b3f334` (both themes) unless stated otherwise. Attribution comes from the sampler's five worst UI frames per scenario.

1. **System font fallback stalls: the only frames that exceed 100 ms.**
   - Worst `steady-scroll` frames are 162 / 84 / 75 ms (brutal) and 223 / 178 / 103 ms (elegant). On the old list they were 158 and 432 ms. The worst `resize` frame is 122 ms.
   - In every case 80–86% of the CPU samples (58% for resize) are inside `libfontconfig` (`FcPatternGetString`, `FcStrCmpIgnoreCase`, `FcFontSetMatch`), under LAYOUT.
   - Mechanism: the first time a frame lays out a character that the bundled Latin fonts lack (CJK, kana, emoji), the engine asks fontconfig for a fallback face. The theme falls back to *system* `Noto Sans CJK JP/SC` and `sans-serif` (`packages/raft_ui/lib/src/theme.dart:102-104`).
   - These stalls are first-use only, which is why p90 stays low. Each one is still a visible hitch of 5–25 dropped frames.
   - Fix: bundle subset CJK and emoji fonts and list them as explicit fallbacks. Warm the glyph ranges off-screen at idle after the first frame.
2. **Row mount cost: every burst of new rows misses the budget.**
   - Mounting 0.9 viewport of fresh rows costs 9–30 ms in one frame. Per row:

     | Row kind | UI time per row |
     |---|---|
     | Plain | 2.3 ms |
     | Thread summary | 3.3–3.6 ms |
     | Task | 2.7–3.1 ms |
     | Attachments | 4.0–4.2 ms |
     | Markdown | 4.4–4.6 ms |
     | Reactions | 4.7–4.9 ms |
     | Image | 5.7–6.2 ms |
     | Code | 9.1–10.7 ms |

   - At 1200 px/s about one row mounts per frame, so `steady-scroll` p90 is 4 ms. Flings, channel switches, thread opens and jumps mount many rows at once and drop frames.
   - LAYOUT is 55–67% of mount frames, and that includes child build inside the sliver.
   - Hot app code in the worst frames:

     | Function | Share of worst-frame samples |
     |---|---|
     | `RaftTimelineRenderViewport.performLayout` | 8–24% inclusive |
     | `_RenderRowExtentRecorder.performLayout` | 7–22% |
     | `raftCodeSpan` / `_RaftCodeBlockState.build` (code highlighting in build) | 5–6% |
     | `AttachmentImageRepository.synchronize` / `canRead` → `WorkspaceController._retainsAttachment`, run per image row in `didChangeDependencies` | 14–20% of image mounts |
     | `_ReactionSpritePainter.paint` | 12 ms of PAINT in the worst reaction frame |

3. **Semantics is always on under Linux: 9–39% of UI time.**
   - Share of UI time by scenario: `image-scroll` 39%, `fling` 27%, `steady-scroll` 19–25%, `resize` 16–18%.
   - Turning semantics off (`--semantics off`, the typical macOS state) halves steady and fling p50.
   - It cuts elegant `resize` frames over 8.33 ms from 61% to 6%, and `thread-open` frames over 16.7 ms from 17 to 5.
4. **Resize relayouts every mounted row each frame.**
   - UI p50 is 7.9–8.6 ms, and 33–61% of frames exceed 8.33 ms.
   - Hot: `RaftTimelineRenderViewport.performLayout`, and `estimateRow` → `_EstimatingChildDelegate.estimateMaxScrollOffset` (8–17%).
   - It is also the GC hot spot: 208–243 GCs in 8 s, with 56–99 GC events overlapping the worst frames.
5. **Transitions drop at least one 60 Hz frame each time.**

   | Transition | Worst UI frame | Newest row visible after |
   |---|---|---|
   | `channel-switch` (warm, 10 switches) | 18–23 ms | 28 ms |
   | `thread-open` | 22–28 ms | 86 ms warm, 240 ms cold incl. 150 ms network |
   | `open-warm` | 15–31 ms | — |
   | `open-cold` | 14–17 ms | — |

   - Cost is LAYOUT plus BUILD of a full viewport of fresh rows, the same as #2. Mount cost is the lever here too.
6. **GC pressure in image paths.** `image-scroll` runs about 100–114 GCs in 8 s (about 1 s of GC across threads). `mount-image` runs 1.6 s of GC.
7. **Raster is healthy.**
   - Impeller GLES raster p99 is ≤ 4 ms in every scenario on this GPU.
   - The worst raster frames are dominated by `ReactorGLES::React`/`FlushOps`, with `Canvas::saveLayer` present from `Opacity` layers (gap #6).
   - `resize` frames rasterize 0 ms because the engine drops frames whose size mismatches the surface; see the platform notes.

Lab findings that need product follow-up:

- **Touch drag on row content did not scroll when semantics was on.** With semantics on (the Linux default), a synthetic touch drag starting on row content in the middle of the timeline did not scroll (0 px moved). The same drag scrolled 14.7k px with semantics off, and from the avatar gutter. The lab now drags from the gutter. Reproduce with real touch or trackpad input before treating this as a product bug.
- **Live arrivals do not move the reader.** The row being read stays put while teammates' messages arrive (`anchorDriftPx` 0, no remounts). An arrival authored by the signed-in user does follow the newest row, as designed.

## Best practices and our status

Sources were checked in October 2026. Status refers to the current `cindy/integration` tree.

| # | Practice | Why it matters | Status | Evidence | Action |
|---|---|---|---|---|---|
| 1 | **Avoid system font fallback on first use.** Bundle the CJK and emoji fonts the UI actually renders, list them in `fontFamilyFallback`, and warm them off-screen at idle ([Flutter fonts](https://docs.flutter.dev/cookbook/design/fonts), [FontLoader](https://api.flutter.dev/flutter/services/FontLoader-class.html)). | A missing glyph makes the engine query the platform font manager (fontconfig / CoreText). The first query for a character costs tens of ms inside LAYOUT. | **Missing** | `packages/raft_ui/lib/src/theme.dart:102-104` falls back to system `Noto Sans CJK JP/SC`, `sans-serif`. `packages/raft_ui/pubspec.yaml` bundles only Latin fonts. No emoji font. Measured: worst steady-scroll frames 158–432 ms, 80–86% in libfontconfig. | Bundle subset CJK and emoji fonts. Warm them in `SchedulerBinding.scheduleTask(..., Priority.idle)` after the first frame. |
| 2 | **Keep `build` pure and cheap.** Parse and highlight once, cache by content, don't build per frame ([best practices](https://docs.flutter.dev/perf/best-practices)). | Row mount cost is paid on every scroll into new rows. | **Partial** | `RaftMessageBody.build` (`packages/raft_ui/lib/src/message_body.dart`) splits and parses Markdown and fences per build. `raftCodeSpan` highlighting runs in `_RaftCodeBlockState.build`. Code rows cost 9–10.7 ms per row (2b3f334). `raftTextMetricsCache` (`panel_layout.dart`) is done. | Cache parsed blocks and highlighted spans by (content, theme). |
| 3 | **Bound `SelectionArea`.** One selectable region per message, or enable selection on demand ([SelectableRegion](https://api.flutter.dev/flutter/widgets/SelectableRegion-class.html), [SelectionContainer.disabled](https://api.flutter.dev/flutter/widgets/SelectionContainer/SelectionContainer.disabled.html)). | Every Text under a region registers as a selectable and adds geometry work. | **Partial** | `message_body.dart:302` wraps each prose block, so there can be several areas per message. | Use one region per message, created lazily on hover or long-press. |
| 4 | **Treat semantics cost as real on Linux.** Use `ExcludeSemantics` for decorative nodes, `MergeSemantics` for compound chips, and keep the node count low ([3.32 semantics speed-up](https://flutter.dev/blog/whats-new-in-flutter-3-32)). | It runs after scene submission but on the same UI thread. | **Partial** | Many `ExcludeSemantics` (icons, avatars). No `MergeSemantics` in rows. Measured 9–39% of UI time (image-scroll 39%, fling 27%). Semantics off cuts resize frames over 8.33 ms from 61% to 6%. | Merge reaction and task chips. Profile nodes per row. |
| 5 | **Place RepaintBoundary deliberately.** `SliverChildBuilderDelegate` already adds one per row ([RepaintBoundary](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html)). | Extra boundaries help only for subtrees that repaint at a different rate. | **Done (defaults)** | `message_timeline.dart` delegates keep `addRepaintBoundaries`. Raster p99 ≤ 4 ms everywhere. | Add boundaries only around animated badges or spinners. |
| 6 | **Avoid saveLayer, Opacity and antialiased clips.** Use alpha colours, `FadeTransition`, and `Clip.hardEdge` ([best practices](https://docs.flutter.dev/perf/best-practices)). | `saveLayer` costs an offscreen pass. | **Partial** | `thread_replies.dart:222,253` (`Opacity` on "·" and "draft"), `recipe_surface.dart:438` (`RaftOpacityCompositing.layer`), `mounted_reaction_recipe.dart:202`. `Canvas::saveLayer` appears in the worst raster frames. | Replace with alpha colours. Prefer `alphaFilter` or plain alpha. |
| 7 | **Decode images at display size** with `ResizeImage` / `cacheWidth`, reserve the aspect box, and bound the cache ([ResizeImage](https://api.flutter.dev/flutter/painting/ResizeImage-class.html), [ImageCache](https://api.flutter.dev/flutter/painting/ImageCache-class.html)). | Avoids full-resolution decode and layout shift. | **Done for attachments, partial elsewhere** | `apps/raft_flutter/lib/data/attachment_image_repository.dart:331` `ResizeImage(policy: exact)`. Avatars use `Image.network` without `cacheWidth` (`packages/raft_ui/lib/src/components.dart:382,443`). | Add `cacheWidth` to avatars. Reduce `AttachmentImageRepository.synchronize`/`canRead` per row; it is 14–20% of worst image-mount frames. |
| 8 | **Move parsing to isolates** (`Isolate.run`/`compute`) only for large inputs, after caching ([isolates](https://docs.flutter.dev/perf/isolates)). | Spawning and copying cost more than parsing one message. | **Missing (low priority)** | No `Isolate.run` or `compute` in `lib/`. | Cache first (#2). Consider isolates for very long messages or initial window parsing. |
| 9 | **Avoid rebuild cascades.** Use fine-grained listenables or `select` ([best practices](https://docs.flutter.dev/perf/best-practices)). | One `notifyListeners` should not rebuild every visible row. | **Partial** | `WorkspaceController` has 78 `notifyListeners()` calls. A reaction-viewer fetch per mounted reaction row (`hydrateReactionViewer`) notifies the whole workspace. Per-agent presence uses `ListenableBuilder` (`chat_view.dart:1792`). | Notify per message, or batch viewer snapshots. |
| 10 | **O(1) keyed reuse** (`findChildIndexCallback`) and estimated extents ([SliverChildBuilderDelegate](https://api.flutter.dev/flutter/widgets/SliverChildBuilderDelegate-class.html)). | Keeps elements on insert or prepend. Stable scroll range. | **Done** | `message_timeline.dart` two-sided center sliver with `indexOfId` lookup and `estimateRow`. History prepends never move the reader. Measured `anchorDriftPx` 0. | Keep. `estimateMaxScrollOffset` is still 8–17% of resize frames. |
| 11 | **No shader warm-up needed with Impeller.** Shaders are precompiled ([Impeller](https://docs.flutter.dev/perf/impeller)). | Removes first-use shader-compile jank. | **Done** | Impeller is the default on macOS and Linux in 3.47 (Linux raster events confirm GLES Impeller). No SkSL bundle. | On macOS, A/B against `--no-enable-impeller` with this lab. |
| 12 | **Frame scheduling.** Defer non-visible work to idle (`SchedulerBinding.scheduleTask` + `Priority.idle`, ≤ 1 ms chunks). Skip expensive loads while flinging (`Scrollable.recommendDeferredLoadingForContext`). Avoid work in post-frame callbacks. ([scheduleTask](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/scheduleTask.html), [recommendDeferredLoadingForContext](https://api.flutter.dev/flutter/widgets/Scrollable/recommendDeferredLoadingForContext.html)) | Keeps bursts (mount, switch, open) inside a frame. | **Missing** | No `scheduleTask`, `Priority` or `recommendDeferredLoadingForContext` in `lib/`. Many `addPostFrameCallback` calls. | Defer image begin, reaction-viewer fetch and row-extent bookkeeping during flings. Chunk channel-switch work. |
| 13 | **Measure in profile mode on device, per frame, against the refresh budget** ([UI performance](https://docs.flutter.dev/perf/ui-performance), [rendering performance](https://docs.flutter.dev/perf/rendering-performance)). | Debug timings mislead. Average FPS hides spikes. | **Done** | This lab, plus P01. | Run `lab.py compare` on every performance change (AGENTS.md). |
| 14 | **Learn from 120 Hz apps.** Superlist's [`super_sliver_list`](https://github.com/superlistapp/super_sliver_list) shows extent estimation, correction and `jumpToItem` for huge variable-extent lists. Its lessons largely match our center-sliver rewrite. | Large variable-extent lists without jumps. | **Done (own implementation)** | `message_timeline.dart`. | — |

Impeller status notes:

- Opt-out on macOS is `FLTEnableImpeller=false` in Info.plist; there is none in `apps/raft_flutter/macos/Runner/Info.plist`.
- Known issues to watch: [#193927](https://github.com/flutter/flutter/issues/193927) (macOS text smearing under memory pressure) and [#192915](https://github.com/flutter/flutter/issues/192915) (Linux flicker on VM GPUs).

## Running on macOS (120 Hz ProMotion)

The macOS run is kept brief because the current gate is Linux 60 Hz.

### Requirements

- The pinned Flutter SDK (`tool/flutter`, selected by `.fvmrc`), Xcode with command-line tools, and CocoaPods.
- An Apple-silicon Mac with a ProMotion display: a built-in MacBook Pro panel, or an external 120 Hz display. Build arm64; under Rosetta, x64 may be capped at 60 Hz.

### Command

```bash
python3 tool/performance/lab.py run --out .local/performance/lab/mac-<name> --device macos
# equivalent to:
cd apps/raft_flutter && ../../tool/flutter drive --profile -d macos --driver=test_driver/perf_lab_driver.dart --target=integration_test/perf_lab_test.dart --dart-define=RAFT_LAB_THEMES=brutal-light,elegant-light
```

### Refresh rate

- The lab records `FlutterView.display.refreshRate` in `lab-hello.json` and in every scenario record, through `binding.platformDispatcher.views.first.display.refreshRate`. Expect 120.
- On a Mac the gate becomes the 8.33 ms frame budget. Stutter is counted against the 8.33 ms vsync period automatically.

### Platform differences

- **No Linux-only assumptions in the lab path.**
  - `/proc` CPU ticks and `getconf` are guarded by `Platform.isLinux` and report `null` on macOS.
  - `glxinfo`, the `DISPLAY` check and the single-instance `ps` check run only on Linux.
  - `run` on macOS reads the CPU from `sysctl` and the GPU from `system_profiler`.
- **Sandbox.** The app writes no files. All data travels over the VM service and the driver writes it on the host. The loopback image server needs `com.apple.security.network.server`, which `DebugProfile.entitlements` already grants.
- **Isolated Linux-only parts.**
  - P01's X11 `tool/performance/resize-window.py` is not used by the lab. Lab `resize` drives the engine view size from Dart, so it is portable but excludes window-server and compositor resize cost.
  - Font-fallback attribution matches fontconfig on Linux and CoreText (`CTFont*`, `FontParser`) on macOS.
- **Semantics.** It is usually off on macOS. Use `--semantics on` to model VoiceOver users.
