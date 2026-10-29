# Startup theme flash (Android)

Report: with a non-default theme (Elegant) the app first shows the default look and then jumps.

## Entrypoint

`apps/raft_flutter/integration_test/theme_flash_main.dart` runs the production startup sequence (`RootErrorBoundary`, `deferFirstFrame`, `RaftApp.restore`) on perf-lab fixtures, without login, on REAL persisted `SharedPreferences`, so a cold start reads the stored appearance from disk. Profile/debug only.

```sh
cd apps/raft_flutter
../../tool/flutter build apk --profile --target-platform android-x64 \
  --android-project-arg=raftApplicationIdSuffix=.linkperf -t integration_test/theme_flash_main.dart
adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # only the .linkperf package
# seed once: "<mode> <family> [icon] [nodefer]"
adb shell 'echo "dark elegant blue" > /data/local/tmp/raft-theme-flash.txt; chmod 644 /data/local/tmp/raft-theme-flash.txt'
adb shell am start -n app.raft.raft_flutter.linkperf/<enabled launcher alias>   # then: rm the seed file
adb shell am force-stop app.raft.raft_flutter.linkperf
adb shell screenrecord --time-limit 7 /sdcard/x.mp4 & adb shell am start -W -n <alias>   # cold start, record
```

The seed run also switches the launcher icon colour through `NativeAppIcon`, because a profile build cannot be toggled with `pm enable` from the shell.

## Cause (Android 17 emulator, 2026-10-12)

Frame extraction at 30 fps of cold starts (Elegant light, Elegant dark, Brutal; yellow and blue icon):

- The window shows the icon-colour splash (system splash on Android 12+, icon colour `#FBD23C` yellow or `#25CAEF` blue, with the mark) from process start until the first Flutter frame, then cross-fades (about 0.15 s) into the app. In dark Elegant that is yellow to `#0B0B09`.
- No Flutter frame is ever painted with the default family: the first frame is released only by `finishStartup()`, after `restore()` read `raft.mode` / `raft.light`. Even with `deferFirstFrame` removed (`nodefer`), the stored preferences are already loaded, so the first rendered frame is the stored theme.
- The window background (`setBackgroundDrawableResource`) is never visible after the first frame: the Flutter `SurfaceView` punches through it.

So the "default theme" the owner sees is the icon-colour splash (native), not a Flutter frame.

## Fix (Dart)

`storedAppearance()` reads `raft.mode` / `raft.light` synchronously from the preloaded `DevicePreferences`. `_RaftAppState.appearance` starts from it, so the first built `MaterialApp` has the stored family and mode on every path (the deferred first frame is no longer the only guard). Unknown stored values fall back per key instead of failing the restore. `RootErrorBoundary`'s fallback app uses the same reader. Tested in `test/startup_appearance_test.dart`.

## Splash

The icon-colour splash was the visible "default theme". It is replaced by the stored theme's canvas plus the chosen icon as a tile; see "Launch screen" in [custom-app-icons.md](custom-app-icons.md). Device frame evidence: `/tmp/splash/<case>/sheet.png` and `frames.txt` (Android API 37 emulator).

## Desktop (Linux profile build under xvfb; macOS needs a Mac recording)

Same entrypoint, real persisted preferences (`THEME_FLASH_SEED=<file>` holds `<mode> <family>`, `THEME_FLASH_CACHE=<dir>` keeps the workspace cache so the second cold start is cache-first, `THEME_FLASH_PRESENTATION=<json>` stores the Appearance-section choices). `DBUS_SESSION_BUS_ADDRESS=disabled:` keeps the GApplication from forwarding to another running instance. Capture: `ffmpeg -f x11grab -framerate 30` from before launch; one capture at a time under `flock /tmp/raft-flutter-linux-capture.lock`.

What desktop showed (before = origin/cindy/integration):

- Linux shows no native window colour: GTK maps the window on the first Flutter frame (`first_frame_cb`), so the first frame the user sees is already Flutter UI.
- The theme (rail, sidebar, canvas) was already the stored family on the first rendered frame in 27 of 28 cold starts (Elegant light and dark, with and without a seeded presentation). One cold start (Elegant light, cache-first) rendered the Brutal rail (`#FFD541`) and sidebar (`#FFFAEE`) for about 0.9 s before Elegant; it did not recur in the 27 other baseline launches, and 12 more launches of an instrumented build (first build brutal and `restoring=true`, appearance read 6 ms later, first frame released after the rebuild) shows the ordering that normally prevents it. The synchronous `storedAppearance()` removes the dependency on that ordering.
- Reproducible every launch: the sidebar and chat first render with the DEFAULT personal presentation (desktop default: empty sidebar sections hidden, font `md`) and switch to the stored choices (here: empty sections shown, font `lg`) about 0.3 s later. `PersonalPresentationStore.bind` read the stored value with an awaited storage read, after the first build. Frames: `/tmp/theme-flash/desktop-presentation-base-vs-fixed.png`.

Fix: `bind` reads the preloaded `DevicePreferences` synchronously (`SynchronousSearchMemoryStorage`), so the first build already has the stored font, `hideEmptySections`, live-activity and model-name choices; one notification, no defaults frame. Test: `test/personal_presentation_test.dart`.

macOS (`macos/Runner/MainFlutterWindow.swift`, not compilable on this host): the nib window is `visibleAtLaunch=NO`; `AppDelegate` orders it in at `applicationDidFinishLaunching`, before the deferred first Flutter frame, with the default NSWindow colour and a `FlutterView` that paints black until then. The window and `FlutterViewController.backgroundColor` now use the stored theme's canvas (white for every light family, `#141411` for dark; `mode=system` follows the app appearance), read from NSUserDefaults (`flutter.raft.mode`). Needs a Mac recording to confirm.
