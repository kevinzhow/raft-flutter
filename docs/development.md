# Development workflow

## Prerequisites

- Flutter **3.47.6** / Dart 3.13.5, pinned in `.fvmrc`. Always call Flutter through `tool/flutter`: it looks for `.fvm/flutter_sdk` or `~/flutter-sdks/versions/3.47.6`, honours `RAFT_FLUTTER_BIN`, and refuses any other SDK version. Install with `fvm install && fvm use 3.47.6`.
- Python 3.11+ for the full engineering checks (some tooling uses `hashlib.file_digest`); use UTF-8 mode on Windows (`PYTHONUTF8=1`). Node 24 / pnpm only for the parity and generator tools that read a raft-source checkout.
- Per platform: Android SDK (+ NDK only to regenerate ADPF bindings), the Flutter Linux desktop toolchain, Xcode and CocoaPods for macOS and iOS, or Visual Studio C++ desktop build tools and the Windows SDK for Windows x64.

## Set up

```sh
tool/flutter pub get --enforce-lockfile        # repository root; Dart pub workspace
(cd apps/raft_flutter/tool/bindings_generator && ../../../../tool/flutter pub get --enforce-lockfile)
```

The second command is a separate package that whole-project analysis needs; it needs no NDK (regenerating bindings does, see [Android Performance Hint](android-performance-hint.md)). `tool/check-project` runs it for you.

## Run the app

```sh
cd apps/raft_flutter
../../tool/flutter run -d linux     # Linux; run tool/prepare-media-linux first
../../tool/flutter run -d macos     # macOS (Apple Silicon)
../../tool/flutter run -d <serial>  # Android emulator (see the install warning below)
```

The app talks to the official API `https://api.raft.build` by default; pass `--dart-define=RAFT_ORIGIN=http://localhost:13041` for a local server (or any other origin), or edit the origin on the login screen (see [Self-deploy](deployment.md)). For a local server see [local server stack](local-test-stack.md): `tool/raft-stack start|stop|status|ports` wraps the raft-source `raftdev` launcher and needs a git-ignored `.local/stack.json`.

Never use `flutter run/drive/test/install` on a device that holds the real (formal) app; Flutter may uninstall and reinstall it. Use `tool/android-install` (see [AGENTS.md](../AGENTS.md) and [Android installation](android-installation.md)).

`packages/raft_ui` components each ship an SDK Widget Preview for reviewing themes and states (`brutal-light`, `elegant-light`, `elegant-dark`).

### Windows

Use PowerShell and Python 3. The wrapper also finds FVM's pinned SDK under `%USERPROFILE%\fvm\versions\3.47.6`; `RAFT_FLUTTER_BIN` may point to its `flutter.bat`.

```powershell
python tool/flutter pub get --enforce-lockfile
Set-Location apps/raft_flutter
python ../../tool/flutter build windows --release --no-pub
Start-Process -FilePath "$PWD/build/windows/x64/runner/Release/raft_flutter.exe"
```

CMake downloads Microsoft.WindowsAppSDK 1.7.250310001 from official NuGet and verifies its pinned SHA-256. The bundle includes the bootstrap DLL and Raft notification icons; it still requires Windows App Runtime 1.7 x64, including its notification singleton dependencies. This machine already had that runtime; fresh-machine installation has not been verified. See [Microsoft's deployment guide](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/tutorial-unpackaged-deployment).

If notification clicks offer to find an app for `raft-notification`, the explicit registration step below was verified on this machine. Run it from an **administrator PowerShell**, at the repository root, after building and verifying the complete bundle:

```powershell
$raftExe = (Resolve-Path 'apps/raft_flutter/build/windows/x64/runner/Release/raft_flutter.exe').Path
$raftSha = (Get-FileHash -LiteralPath $raftExe -Algorithm SHA256).Hash
./tool/windows-notification-register.ps1 -ExecutablePath $raftExe -ExpectedSha256 $raftSha
```

The script registers only Raft's machine protocol, validates the bundle/hash and refuses an existing key owned by another application. Repeat after moving the bundle. The app never triggers this administrator step automatically. Use Settings → Notifications → send a test notification to check display and return behavior; cold-click and full Windows acceptance remain pending ([evidence](windows-notifications.md)).

## Test and analyze

```sh
tool/flutter analyze --no-pub
tool/flutter test packages/raft_client/test packages/raft_sync/test packages/raft_ui/test --no-pub
cd apps/raft_flutter && ../../tool/flutter test test/<file>_test.dart --no-pub   # app tests
python3 -m unittest discover -s tool/tests -p 'test_*.py'                         # Python host tests
tool/ds-audit --check                                                            # design-system drift
```

Native flows: `tool/native-linux` (runs `integration_test/workspace_test.dart` on Linux) and `tool/native-test emulator-5580` (Android). Both need an isolated local server and a private fixture identity in the ignored `.local/test-user.json`; never put login data in source, assets or build arguments.

Chinese UI strings: add them as a new `packages/raft_ui/lib/src/l10n/zh_<feature>.dart` (a `const Map<String, String> zhCatalog<Feature>`), never to `localization.dart`; `tool/gen_l10n_index.py` (run by `tool/flutter`) merges the files into the git-ignored `zh_index.g.dart`, and `packages/raft_ui/test/zh_catalog_files_test.dart` rejects a key declared twice. Write the zh yourself: Web's zh-cn wording when Web has the same English string, otherwise wording in the catalog's existing terms; it needs no approval (Kevin, 2026-10-13). Only an app-wide terminology change (a word used across the catalog) goes to Kevin first. Every string a user can see must have its zh entry in the same change (`apps/raft_flutter/test/zh_catalog_test.dart` fails otherwise).

`tool/ds-audit` is an AST-based scan of `apps/raft_flutter/lib` for Material widgets, literal dimensions, fonts, radii and colors. It compares per-file and per-category counts with the checked-in `tool/ds-audit-baseline.json`; `--check` fails if any count grew and passes (with a "baseline can lower" note) when counts went down, so feature branches never edit the baseline; the integration owner runs `--update-baseline` after merges and commits it separately; and `// ds-allow: <reason>` marks reviewed platform-only code. Rules: [design-system migration](ds-migration.md).

### Lint rules (`tool/raft_lints`)

Code-pattern rules are analyzer-plugin lints in `tool/raft_lints` (package `analysis_server_plugin`), not regex tests. The plugin is enabled in the root `analysis_options.yaml` (the only place plugins can be configured; each rule must be listed under `diagnostics:` with severity `error`); a package that has its own `analysis_options.yaml` lists the root file in `include:`. Rules apply to `lib/` only:

| Rule | Flags |
| --- | --- |
| `avoid_render_index_assertion` | `m[k]!` inside render code (a function, method or getter returning a `Widget`, `List<Widget>` and so on, or a closure that returns a widget or is a `...builder:` argument, nested closures included). A lookup in `RaftTokens.colors` and an integer-literal index are exempt. |
| `avoid_render_single`, `avoid_render_where_without_or_else` | `.single`, and `firstWhere`/`lastWhere`/`singleWhere` without `orElse`, inside render code. |
| `avoid_unproxied_network_client` | `HttpClient`, `Dio`, `IOHttpClientAdapter`, `WebSocket.connect`, socket.io `io()`, `http.Client`/`IOClient`, `HttpClient.findProxyFromEnvironment` outside the proxy hook ([system proxy](system-proxy.md)). |
| `avoid_raw_image_decode` | `Image(...)`/`Image.network` etc., raw `ImageProvider`s, `RawImage`, `ImageDescriptor`, `backgroundImage:`; use `RaftSizedImage` (`RaftSizedImage.avatar` for avatars and icons, see [architecture](architecture.md)). |
| `avoid_builtin_underline`, `avoid_material_slider`, `avoid_material_feedback` | `TextDecoration.underline`; Material `Slider` family; `SnackBar`/`ScaffoldMessenger`/`MaterialBanner`. |
| `avoid_raw_bottom_sheet` | `showModalBottomSheet` / `showBottomSheet` / `showCupertinoSheet`, `ModalBottomSheetRoute`, `BottomSheet`, `DraggableScrollableSheet`, `CupertinoSheetRoute`; open a window with `showRaftPresented` (a `RaftPresentationPolicy`; a form with inputs uses `showRaftForm`, which builds a scaffold such as `RaftFormDialog` or `RaftDialogCard` that draws itself as a sheet below 768) and build sheet content with `RaftSheet`. Only `presentation.dart` is exempt. |
| `avoid_caught_exception_text` | A caught exception (catch clause, `catchError`/`onError` closure) interpolated, stringified, read for `message`/`error`/`response`/`stackTrace` or passed to `Text` outside log calls (app and raft_ui only). |
| `avoid_unreviewed_idle_work` | `scheduleTask`, `Priority.idle`, `Timer.run`/`periodic`, zero-delay timers, `Future(...)`/`microtask`, `scheduleMicrotask`, `.repeat()`, frame requests, post-frame callbacks passed by name, raw tickers ([idle CPU](idle-cpu.md)). |
| `avoid_imperative_notice_state` | Mutable `String`/`bool`/`Map<_, String>` variables named `*error`/`*notice`/`*warning`/`*failure` and `setError`/`setComposerError` calls (app and raft_ui only); hold notices in a `CauseNotice`. |
| `avoid_unreleased_resource` | A field assigned a controller/notifier, or a variable assigned a timer or `.listen` subscription, with no `dispose`/`cancel`/`close`/`stop` on it in the same file; unmatched `addObserver` / `ImageStream.addListener`. |
| `avoid_text_scale_factor` | Any reference to `textScaleFactor`, `MediaQuery.textScaleFactorOf` / `maybeTextScaleFactorOf`, or a `textScaleFactor:` argument; read `MediaQuery.textScalerOf(context).scale(fontSize)` or pass `textScaler:`. Implementing the getter in a `TextScaler` subclass is not a use. |
| `avoid_fixed_height_text` | A Flutter `SizedBox` / `Container` / `AnimatedContainer` with a numeric-literal or const `height:` (or `ConstrainedBox` / `Container` `constraints:` with `BoxConstraints(maxHeight:)`, `.tightFor(height:)`, `.expand(height:)` of such a value) whose `child:` is directly `Text`, `Text.rich`, `SelectableText`, `TextField` or `RaftCssText`. Use a minimum height. `double.infinity`, runtime values and wrapped text (`Center(child: Text)`) are not flagged. Files on the `legacyFixedHeightTextFiles` list (`text_scale.dart`) are skipped until their surfaces are fixed; remove entries, never add. |
| `avoid_pixel_text_height` | A numeric literal above 3 as `TextStyle(height:)` / `TextStyle.copyWith(height:)` (a pixel line height where a ratio is expected). |
| `off_grid_spacing` | A numeric literal in a spacing position that is not 0 or a multiple of 2: `EdgeInsets` / `EdgeInsetsDirectional` arguments, the `width` / `height` of a child-less `SizedBox` (a spacer), and `spacing:` / `runSpacing:` / `gap:` / `rowGap:` / `columnGap:` / `mainAxisSpacing:` / `crossAxisSpacing:`. Web's Tailwind `--spacing: 0.25rem` makes every step a multiple of 2px (`RaftSpace`, `packages/raft_ui/lib/src/space.dart`); use the step Web's class names (`p-1.5` is `RaftSpace.x1_5`), a border width as `RaftTokens.border` or `RaftSpace.hairline`. A value Web really uses off the grid (`gap-[5px]`, `mt-px`, a computed baseline offset) stays only with `// ds-allow: Web <file> <class>` on the line or the line above, naming the Web source. Arithmetic over tokens and on-grid raw numbers are not flagged. `RAFT_LINTS_SPACING_STATS=1 tool/raft-lints` also prints the literal inventory (off-grid, on-grid raw, zero). |

Suppress a reviewed site with a reason on the line above or at the end of the line: `// ignore: raft_lints/<rule> -- <why it is safe>` (the `raft_lints/` prefix is required; several rules: `raft_lints/a, raft_lints/b -- reason`; stacked comment lines do not combine).

`flutter analyze` and `dart analyze` print plugin results only if the plugin finishes before the main analysis first goes idle, which a warm analysis often wins, so the gate does not rely on them: `tool/raft-lints [path...]` resolves every `lib/` in-process and runs the same check functions (exit 1 on findings); `tool/raft-lints --test` runs the plugin's tests. The package is outside the pub workspace (it needs a newer `analyzer`), so run `tool/flutter pub get` in `tool/raft_lints` once; `tool/check-project` does this, scans, and runs the plugin tests. The analysis server resolves the plugin through `pub` on first use, so the first IDE or `flutter analyze` run needs the pub cache or network.

**Fast feedback while coding.** `tool/raft-lints --changed [--base REF]` lints only the `lib/` Dart files changed since the merge-base with `origin/cindy/integration` (committed, staged, unstaged and untracked) and finishes in about 3-5 s for 1 to 20 files; `tool/raft-lints PATH...` does the same for explicit files or directories, `--staged` for the staged files. Run `--changed` after each round of edits. It is not the gate: a change can alter findings in files that import it, which only the full scan (about 20 s) re-checks. The runner is an AOT snapshot built on first use into `.local/raft-lints-bin` (about 30 s once, rebuilt when the SDK or `tool/raft_lints` sources change; `dart run` is the fallback), and the analyzer's summary cache lives in `.local/raft-lints-cache`.

**Git hooks (`tool/install-git-hooks`, once per clone).** It sets `core.hooksPath` to `tool/git-hooks` in the clone's shared `.git/config`, so every worktree of the clone uses the hooks of its own checkout (`--status` shows it, `--uninstall` removes it). `pre-commit` runs `tool/raft-lints --staged`, only when a `lib/` Dart file is staged, and blocks the commit on findings; it lints the working-tree contents of the staged files. It does not run `dart format`, because `tool/check-project` does not enforce formatting. Bypass in an emergency with `git commit --no-verify`. `post-merge`, `post-checkout` (branch checkouts only) and `post-rewrite` (rebase; a rebase does not fire `post-merge`) call `tool/sync-pub-lock`, which runs `pub get --enforce-lockfile` in each directory whose `pubspec.lock` changed (root, `tool/raft_lints`, the bindings generator), prints one line, and never fails the git operation (a failure prints a warning with the command to run by hand). The main clone also has `rerere.enabled=true` and `rerere.autoupdate=true` (clone config, shared by its worktrees), so a conflict resolution is recorded and replayed by later rebases and merges; check `git diff` after a rebase that reused one.

## Merge gate: `tool/check-project`

`python3 tool/check-project` is the whole-project gate. It records the `tool/source-hash` of the tree, runs `pub get --enforce-lockfile` for the bindings generator and `tool/raft_lints`, then runs four independent checks **concurrently**: (1) the Python host tests in `tool/tests`, (2) `flutter analyze --no-pub`, (3) `tool/raft-lints` plus the plugin tests, and (4) every Dart test of `apps/raft_flutter`, `raft_client`, `raft_sync` and `raft_ui`, split into balanced shards that each run as one `flutter test` process from `apps/raft_flutter`. It fails if the source changed while it ran. It does **not** run `tool/ds-audit`, so run that separately. Run it behind `flock /tmp/raft-flutter-check.lock` so only one gate uses the machine at a time.

- **Sharding.** Test files are assigned longest-first to shards using the per-file seconds of the previous run (`.local/check-durations.json`, falling back to the main checkout's copy, then to file size). The default shard count is one per 3 CPUs not already busy (the 1-minute load average is subtracted), at most 8, with `-j 2..4` test processes per shard. On macOS the default is a single shard with up to `-j 8`: each `flutter test` process re-links the shared `native_assets` dylibs, so parallel shards race there. Override with `RAFT_CHECK_SHARDS`, `RAFT_CHECK_JOBS`; `RAFT_CHECK_SHARD_TIMEOUT_MINUTES` (default 60) kills a whole shard that stops producing a result.
- **Staggered shard start.** Every `flutter test` empties `build/native_assets/<os>/`, rewrites `native_assets.json` and builds the asset bundle before it copies the json to `build/unit_test_assets/NativeAssetsManifest.json`; a second process starting in that window made the first fail with `PathNotFoundException` (the whole shard's files "never ran"). The warm-up cannot prevent this because the tool redoes the native-assets step on every invocation, so the gate lets one shard at a time through startup: the next shard starts once the previous one's JSON event file has content (about 3 s each, 180 s cap), and each shard's wait is printed (`shard N startup started after ...`) and recorded in `engineering-run.json`.
- **A shard passes only if** `flutter test` exited 0, its log ends with `All tests passed!`, no test failed, and every file it was given produced a result. A shard that stalls and is killed by the watchdog (or crashes) fails, and the files that never ran are listed by name in `check-summary.txt`.
- **No retries.** A failed or timed-out test fails the gate. Nothing is re-run to hide flakiness; if a test only fails under load, lower `RAFT_CHECK_SHARDS` and fix the test.
- **Per-test timeout.** Plain `test()` cases are bounded by `dart_test.yaml` (60 s). `testWidgets` is bounded by `test/flutter_test_config.dart` in `apps/raft_flutter` and `packages/raft_ui`, which sets the binding's `defaultTestTimeout` to 60 s (`RAFT_TEST_TIMEOUT_SECONDS` overrides). `flutter_test` passes an explicit 10 minute timeout to every `testWidgets`, which silently overrides `dart_test.yaml`, so the config file is required. A test that legitimately needs longer must say so with `timeout: const Timeout(Duration(minutes: 3))` (or `Timeout.factor(2)`) on that test. A hanging test fails after a minute, including a hang in a tear-down. Because every test file now has the binding before its `main` runs, a test file cannot construct its own `AutomatedTestWidgetsFlutterBinding` subclass: use `RaftTestBinding.showShadows()` / `RaftTestBinding.semanticsBuilderFactory` from `test/flutter_test_config.dart`, and set `HttpOverrides.global = null;` in a plain `test()` that talks to a real loopback server (the binding installs flutter_test's always-400 mock client). Awaiting a future in a tear-down that was created in the `testWidgets` FakeAsync zone never completes, because its microtasks are not flushed once the body returns; that was the cause of the hangs fixed by `RaftClient.dispose` (it now waits for session writes only while some are pending).
- **Leak tracking.** `test/flutter_test_config.dart` (app and `packages/raft_ui`) calls `LeakTesting.enable()`, so every `testWidgets` is leak-tracked: a `ChangeNotifier`, `TextPainter`, `OverlayEntry`, `ImageInfo` ... created in a test and collected without `dispose()` fails that test **file** (the report is a `(tearDownAll)` failure that names the class and the test; `RAFT_LEAK_STACKS=1` adds creation stacks, `RAFT_LEAK_TRACKING=0` turns it off for a local run). Plain `test()` is not tracked. Fix the owner (dispose it in `State.dispose`, `addTearDown(x.dispose)` in the test). The global ignore list in the config is only for process-wide singletons and `Expando`-attached caches that live as long as their controller and are released by GC. A test file that still leaks (about 35 files, mostly dialog-scoped notifiers, share-flow staging and app-root services) starts its `main` with `leakDebt(const ['ClassName', ...])` and a comment: a per-file ledger that leaves the rest of the file and every other file tracked; paying a debt is deleting the line. A class that has an owner never goes in the global list. Regression tests for fixed leaks are in `test/leak_regressions_test.dart` (app) and `test/leak_regressions_test.dart` (raft_ui).
- **Outputs in `.local/`.** `host-collector-tests.txt`, `bindings-generator-pub-get.txt`, `raft-lints-pub-get.txt`, `analyze-all.txt`, `raft-lints.txt`, `raft-lints-tests.txt`; `test-shard-N.txt` (expanded log) and `test-shard-N.json` (JSON event stream) per shard; `all-project-tests.txt` (aggregate that ends in `All tests passed!` only when every shard passed); `check-summary.txt` (counts, failed test names, slowest 20 tests); `check-durations.json` (per-file seconds including suite compile time, the slowest 20 tests, and the wall time, used to balance the next run); `engineering-run.json` (`sourceHash`, `completed`, `checks` with one `test-shard-N.txt` entry per shard, `shards`, `failedTests`). The stdout JSON (`passed`, `sourceChanged`, `checks`) is unchanged apart from the extra shard keys.
- **Wall time.** Measured on a 16-CPU shared machine: a green run of 515 test files (4,412 tests) plus analysis takes about 5.5 to 6 minutes (4 shards of 5 to 6 minutes each, analysis and host tests alongside), against 35 to 60 minutes for the former serial run. The slowest single test takes about 15 seconds, so the 60 s per-test bound has wide margin.

### Theme sampling

Many Dart tests repeat one behaviour per theme variant (brutal-light, elegant-light, elegant-dark). By default each test file runs the default variant (brutal-light, always listed first) plus ONE other variant, picked by a stable hash of the file's package-relative path, so roughly half the files sample elegant-light and half elegant-dark. Tests do this by looping over `raftThemeMatrix([...])` from `package:raft_ui/test_themes.dart`; test names do not change, so the default variant keeps its name and duration history. Lists that only have brutal and elegant (no dark axis) run both.

Set `RAFT_TEST_ALL_THEMES=1` to run every variant of every test. `python3 tool/check-project --all-themes` and `tool/prepare-handoff --all-themes` set it for you, and `.local/engineering-run.json` records `themes: sampled|all`. Run the full matrix before merging to main, and whenever you change theme, token or recipe code.

Tests that are about theme differences (per-family tokens, audits, recipes) pass `full: true` to `raftThemeMatrix`, or iterate the theme set themselves, and always run the whole matrix: `design_tokens_test`, `dimension_contract_test`, `statusbar_audit_test`, `statusbar_standard_test`, `edge_to_edge_audit_test`, `system_bars_test`, `packages/raft_ui/test/recipes/*` and the `*_recipe_test.dart` files. A new per-theme test loop should use `raftThemeMatrix` with the default variant first; use `full: true` only when the test compares or audits themes.

## Nightly quality run: `tool/nightly-quality`

Machine-local (K8-Plus), not part of the gate. It resets `raft-flutter-wt/nightly` to `origin/cindy/integration` and writes `~/.local/share/raft-nightly/<date>/summary.md` (Chinese, plus `summary.json`, logs, lcov): (1) the app suite (and the `raft_ui` / `raft_client` / `raft_sync` suites) with coverage and a per-area summary; for each open PR against `cindy/integration`, a diff-coverage report of its changed executable lines that no test ran, measured on the PR's own tree with only the test files that can reach a changed file (`tool/affected_tests.py`, import closure) and cached per (PR head, merge-base); (2) `osv-scanner` over every `pubspec.lock`, listing what it cannot see (Podfile.lock, Gradle, bundled native libraries); (3) the app suite in a random order (`--test-randomize-ordering-seed`, the seed is in the summary and reproduces the order). Jobs 1 and 3 are one app run. The test jobs take the gate lock (`/tmp/raft-flutter-check.lock`, same flock as `tool/prepare-handoff`), wait up to `--lock-wait-minutes` and otherwise record "skipped: gate busy"; every run has a timeout. `tool/diff_coverage.py --lcov FILE[:RUN_DIR] --base REF` is also usable by hand on any lcov. cron runs `~/.local/bin/raft-nightly-quality` at 03:00 JST.

## Player changes

Anything under `platform/*player*`, `platform/attachment_stream.dart`, the inline media cards, the media viewer or the raft_ui video controls is verified on an Android emulator with the real `video_player`, not only with fake players: run the interaction suite (`tool/player-interactions`) and keep its recordings and log with the change. The full checklist is in [media playback](media-playback.md#checklist-for-player-changes). Attachment changes of any kind also run `tool/attachment-open-smoke/run` ([attachment open smoke](media-playback.md#attachment-open-smoke)).

## Behaviour parity checklists

Logic parity with the Web client (what happens on which event, not how it looks) is tracked row by row in `docs/behavior-parity/<domain>.md` (`read.md`, `realtime.md`). Each domain file is written only by its domain auditor; fix branches never edit it.

- **Rows.** `| ID | Web anchor | Web behaviour | Web ref | Flutter ref | Audit | Test hint | Notes |`. IDs are stable `BP-<DOMAIN>-NNN` and never reused. The anchor is `<path relative to packages/web/src>#<symbol>`, where the symbol is a function, const, store action or class member, `event:<socket event>` (the handler registered for that event), or `effect:<identifier>` (the `useEffect` that mentions it). The comment block at the top of the file is the machine-readable header: audited Web tag and commit (`web:`), the `scope:` files whose exported functions and store actions must each be covered by a row, and an `events:` glob list.
- **Status is computed, not written.** A row is `aligned` when a test in `apps/raft_flutter/test` or `packages/*/test` has its ID in the `test()` / `testWidgets()` description, for example `test('[BP-READ-014] markRead keeps the local clear when the user backs out', ...)` (a test with `skip:` does not count). `intended-difference` and `n-a` are declared in the **Audit** column, with the owner decision and date in Notes (the report warns when they are missing). Everything else is `open`, and the Audit column (missing / differs / in-progress / unverified / aligned) is the auditor's assessment at the audited commit. A fix branch therefore only adds a test with the ID in its name.
- **Report.** `tool/behavior-parity` prints counts per domain and a row table; `--json` for machines, `--summary` for counts only, `--domain read` to select one. Nothing generated is committed.
- **Drift check.** `tool/behavior-parity --web <Web checkout root>` compares the checkout with the fingerprints in `docs/behavior-parity/<domain>.fingerprints.json` (the hash of each anchored symbol's normalized source: comments, whitespace, quote style and trailing commas are ignored). Per row: `unchanged`, `CHANGED`, `MOVED` (symbol now uniquely defined in another file, new path printed), `REMOVED` (not found; `--rename-candidates` adds a similarity guess for renames). It also lists UNCOVERED Web candidates that no row anchors: socket events the Web registers (derived from the code) and exported functions or store actions of the `scope:` files. Anchors that do not resolve at the audited commit are audit errors (exit 1). `--fail-on-drift` exits 2 on any CHANGED / MOVED / REMOVED.
- **Re-audit.** After re-checking the CHANGED, MOVED and UNCOVERED items against a newer Web tag, the auditor updates the rows and the `web:` header and runs `tool/behavior-parity --web <checkout> --update-fingerprints` to rewrite the sidecars.
- **Tooling tests and validation.** `python3 -m unittest tool/tests/test_behavior_parity.py` covers parsing, symbol extraction, status and drift on small fixtures. How well the scanner agrees with a TypeScript-AST ground truth on real tags is in [behavior-parity/VALIDATION.md](behavior-parity/VALIDATION.md).

## Branches and batches

Work on one branch per task, ideally in its own `git worktree`, and keep to the files your task owns. While iterating run only the tests, `analyze` and `ds-audit` relevant to the change.

Before handing a branch over, run `tool/prepare-handoff`. It merges the latest `origin/cindy/integration` into your branch (stopping on conflicts so you resolve them, not the integrator), runs `tool/check-project` under the shared gate lock, and prints one line with the branch, commit, base and gate result to paste into the handoff message. A handed-over branch therefore fast-forwards onto `cindy/integration`. Docs-only branches may use `--no-check`. Conventions for contributors and agents (UI rules, data lifecycle, performance bar) are in [AGENTS.md](../AGENTS.md).

### System fonts in screenshot tests

The shared test helper `tool/testing/system_fonts.dart` resolves system fonts under `/usr/share/fonts` by default. To use the same font files on another host, set `RAFT_TEST_FONT_DIR` to a directory with the same tree: `opentype/noto/NotoSansCJK-{Regular,Bold}.ttc` and, for parity captures, `truetype/noto/NotoColorEmoji.ttf` and `truetype/noto/NotoSans-{Regular,Bold}.ttf`. The override changes only file locations; font families, load order and capture settings stay the same.

A screenshot test without all its required system fonts is reported as skipped with the missing paths and configuration hint. It emits no capture. The mobile tab bar configuration interaction test still runs without these screenshot fonts. A passing engineering gate with skipped screenshot tests does not certify those screenshots or parity coverage.
