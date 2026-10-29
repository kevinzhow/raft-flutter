# Performance tuning

Goal: every frame's UI and raster work within 8.33 ms (120 Hz budget); the current Linux gate is no frame over 16.7 ms and no stutter. Scrolling, opening and resizing smoothness has priority over pixel parity ([AGENTS.md](../AGENTS.md)).

## Perf lab

`apps/raft_flutter/integration_test/perf_lab_test.dart` runs fixed scenarios (chat scrolling and row mounting, transitions, mobile `nav-*` flows through the production `RaftApp` with background data replay) in **profile mode** with synthetic fixtures; no real account is used. `tool/performance/lab.py` drives it:

```sh
python3 tool/performance/lab.py run --out .local/performance/lab/<name> [--themes brutal-light,elegant-light] [--scenarios 'steady-scroll,mount-*'] [--semantics platform|on|off] [--no-trace]
python3 tool/performance/lab.py compare .local/performance/lab/<before> .local/performance/lab/<after>
python3 tool/performance/lab.py summarize .local/performance/lab/<name>
```

The runner refuses to start on a noisy host (1-minute load above 0.35 x CPUs; `--allow-noisy` overrides and labels the run NOISY), and `compare` flags regressions in UI/raster p90/p99, over-budget frame counts and stutter. `--device macos` runs the lab on a Mac. Linux needs an X11 session (`DISPLAY`, `GDK_BACKEND=x11`). Scenarios, metrics, outputs and baselines: [performance lab](performance-lab.md). Other probes: `tool/performance/run.py` (message-scroll benchmark P01 used by CI, [message performance](message-performance.md)), `capture_sections.py`, `activity_preview.dart`, `cache_codec_benchmark.dart`.

## Android: page transitions on a device

```sh
python3 tool/performance/android_transitions.py --device <adb serial> \
  --out .local/performance/android-transitions/<run> [--themes brutal-light] [--scenarios nav-home-channel,nav-tabs]
```

This builds `integration_test/perf_lab_test.dart` as an ARM64 profile APK with the Gradle property `raftApplicationIdSuffix=.linkperf`, so its application id is `app.raft.raft_flutter.linkperf` and it never touches the real app. `lab.py` accepts only that package, forces `--keep-app-running` (no automatic uninstall) and fails if the real app's install time or data directories change. Do not invent other ways to run profile tests on a device. Pass `--abi x64 --device emulator-5580` for a functional check on an emulator only; its timings are not evidence for phones. Compare two runs with `lab.py compare <before>/run <after>/run`. See [Android transitions](android-transitions.md) and [Android installation](android-installation.md).

## Switches and probes

- `RAFT_ANDROID_PERFORMANCE_HINT` (`--dart-define`, default `true`): the Android Performance Hint (ADPF) session for the Dart UI thread; `false` disables it. Debug and non-Android builds never load it. To judge it, build two APKs from the same source (`true`/`false`; `android_transitions.py --define RAFT_ANDROID_PERFORMANCE_HINT=false`) and compare with the isolated `.linkperf` app. A run with zero reported sessions proves nothing. No real-phone gain is established yet ([Android Performance Hint](android-performance-hint.md)).
- `RAFT_ROUTE_FRAME_DIAGNOSTICS=true`: off by default; logs per-route frame costs (route categories only, no IDs or content) for real-device investigations; collect with `tool/performance/route_probe.py` ([route performance probe](route-performance-probe.md)).
- Profile builds only: debug-mode numbers are not meaningful. Compare identical fixtures, engine, renderer, view size and semantics mode.

Rules kept from earlier performance investigations:

- Workspace data notifications must not rebuild the root app or the mobile `Navigator`; the root refreshes only for account, onboarding and server-selection facts, and the last-visited URI is written only when it changes. Background preparation of off-screen rows waits for route idle (nothing starts during a push, pop or held predictive back).
- A long raster span with a tiny Dart UI cycle (e.g. 41.8 ms raster vs 0.9 ms UI) is a native present/`queueBuffer` wait, not a Dart rebuild; do not attribute it to widget cost. Compare identical fixtures under the isolated `.linkperf` app; a NOISY run is exploratory, not an acceptance baseline.
- Interactions must not wait on fixed timers: text-input debounces (search 200 ms, forward targets 250 ms) stay, but a click (Retry, first Activity tap) acts immediately. Known unmeasured candidates: `WorkspaceController.selectChannel` awaits the draft restore before the message GET; cold `bootstrap` waits for entities, translations and draft restore before the first directory/message publish; `loadServerDirectory` saves before publishing.
