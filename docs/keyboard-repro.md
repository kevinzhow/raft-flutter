# Keyboard inset repro (Android)

Blank keyboard-height gap under the composer after: keyboard open, Home, return.

## Entrypoint

`apps/raft_flutter/integration_test/keyboard_repro_main.dart` runs the production `RaftApp` (real `MainActivity`, phone shell, composer, `KeyboardInsetGuard`) on the perf-lab fixtures, without login. It is a profile/debug-only target under `integration_test/`; it is never part of `lib/` or a release build.

```sh
cd apps/raft_flutter
../../tool/flutter build apk --profile --target-platform android-x64 \
  --android-project-arg=raftApplicationIdSuffix=.linkperf \
  -t integration_test/keyboard_repro_main.dart
adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # only the .linkperf package
```

Open `lab-kb`, tap the composer, press Home, return (`am start`, recents, home swipe). `adb logcat -s flutter:*` shows `raft-inset` lines (`KeyboardInsetLogger`, profile/debug only).

## Root cause (Android 17 emulator, gesture navigation)

`ime.isVisible` is false from the return on, yet the engine reports the old inset again:

```
onResume                          imeVisible=true  imeBottom=883   (stale, window still stopped)
engine viewInsets.bottom          0                                (correct, first dispatch)
IME animation prepare/start       imeVisible=false imeBottom=0     (system no-op animation, ~0.5 s after resume)
IME animation end                 imeVisible=false imeBottom=0
engine viewInsets.bottom          883 px = 336 dp                  <- stale, stays
```

Flutter's `ImeSyncDeferringInsetsCallback` caches the `WindowInsets` of the last IME animation in `lastWindowInsets` and re-dispatches that cache in `onEnd`. The no-op animation after resume produces no new dispatch, so `onEnd` replays the insets cached at the last keyboard show. The previous guard probed only at the `resumed` lifecycle event, when the engine value was still 0.

Reproduces with Home key, home swipe, recents and a 20 s background. Does not reproduce when the keyboard is dismissed with Back before Home, or after a screen lock.

## Fix

- `MainActivity.onResume` observes IME animations on the decor view and, after each one ends, re-dispatches `rootWindowInsets` (posted, so it runs after Flutter's replay and before the next frame).
- `KeyboardInsetGuard` also reconciles when the engine inset has been non-zero and unchanged for `keyboardInsetSettleDelay` while the platform says the IME is hidden (net for OEMs where `onEnd` never fires).
