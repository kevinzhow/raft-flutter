# Idle CPU and frame scheduling

Trigger: 6785f8f2 (idle message preparation starved Windows input). A task submitted with
`SchedulerBinding.scheduleTask(..., Priority.idle)` is rejected while any ticker runs, and Flutter retries
it through `Timer.run` (zero delay). One pending task plus one running animation is a hot event-loop spin:
about 4,000 zero-delay timers per second on Linux desktop, about 37,000 on the Android emulator.

## Rules

- Never use `Priority.idle`/`scheduleTask`, and never re-arm a zero-delay timer. Deferred work uses
  `RaftIdleTimer` (positive delay, waits out animation and frames, backs off while its gate stays shut).
- Polls and clocks that only matter on screen use `RaftForegroundPeriodic`; it stops on
  hidden/paused/detached and does not fire on resume (owners already refresh on resume).
- A perpetual animation must use a State `vsync` (TickerMode mutes hidden subtrees; `Offstage` does not) and
  stop under reduced motion. Hidden-but-retained subtrees wrap `TickerMode(enabled: visible)`.
- Both helpers live in `packages/raft_ui/lib/src/idle_work.dart`.

## Guards

- The `avoid_unreviewed_idle_work` lint (`tool/raft_lints`, run by `tool/raft-lints`) flags, in all workspace
  `lib/` code, scheduleTask, Priority.idle, Timer.run, zero-delay timers, `Future(...)`/`Future.microtask`,
  scheduleMicrotask, `.repeat(`, Timer.periodic/Stream.periodic, frame requests, self-registering post-frame
  callbacks and raw tickers. Each use needs `// ignore: raft_lints/avoid_unreviewed_idle_work -- <why it cannot
  loop or spin>`. scheduleTask and Priority.idle have no legitimate use, so no ignore is accepted for them in review.
- `apps/raft_flutter/test/idle_frames_test.dart`: real WorkspaceView on the desktop fixture, two minutes of
  app time per screen; no running ticker, at most the known data polls request a frame, and nothing polls
  while the app is hidden.
- `packages/raft_ui/test/idle_work_test.dart`: helper behaviour and "hidden or TickerMode-off or reduced
  motion means no ticker" for every perpetual raft_ui animation.

## Measuring

`tool/idle-cpu/run.sh <label> [seconds] [scenario,...]` builds `apps/raft_flutter/tool/idle_cpu_lab.dart` as a
Linux profile app (Xvfb when `DISPLAY` is unset) and prints one JSON line per scenario: process CPU %
(`/proc/self/stat`), frames/s, `Priority.idle` admission retries/s, timers/s by creation site. It is a plain
app on purpose: `flutter_test` live bindings schedule a frame after every frame and hide this bug class.
On Android pass the same settings with `--dart-define-from-file` (see the header of the lab file) and build
with `--android-project-arg=raftApplicationIdSuffix=.linkperf` (isolated app id, AGENTS.md).

Focused text fields blink their caret (2 frames/s); that is expected and excluded from the zero-frame rule.

## Linux frame pacing (display refresh rate)

Flutter 3.47.6's GTK embedder installs no vsync callback, so the engine paces frames with a fixed 1/60 s timer,
and GDK 3 caps a GL-rendered window's frame clock at 60 Hz (a window committed through `eglSwapBuffers` never gets
a measured refresh interval). `apps/raft_flutter/linux/runner/vsync_driver.cc` fixes both: it releases each engine
frame on the GTK frame clock and fills the clock's refresh interval from the monitor's mode. It only reacts to an
engine request: the tick callback stays registered while frames are requested and is dropped after a few ticks
without a request, so idle stays at 0 frames.

Delivery rules (a count in `RAFT_LINUX_VSYNC_STATS=1` output for each):

- **tick**: the engine asked, the next frame-clock tick releases the frame.
- **late after a tick**: the engine asked after a tick that found nothing waiting (the previous frame took a
  little longer than one refresh to finish): the frame starts at once instead of idling a whole period. A refresh
  releases at most one frame, so the rate never exceeds the display's.
- **timer**: no tick by the next boundary (hidden or occluded window, a compositor that sends no frame
  callbacks, Xwayland where the GDK clock never ticks): a timer on the same boundary grid releases the frame, so
  pacing is never slower than the engine's own timer. After 30 timer deliveries in a row ticks are only probed
  every 60th delivery.
- A tick less than 3/4 of an interval after the previous boundary is ignored ("early ticks ignored"): a frame
  clock that is not paced by the display must not release frames faster than the refresh rate.

`RAFT_LINUX_VSYNC=0` restores the engine's timer, `RAFT_LINUX_VSYNC=timer` never uses ticks.
`RAFT_LINUX_VSYNC_STATS=1` prints once a second: GDK backend, requested and delivered counts, the split above,
the median/max lateness of a delivery against its refresh, and the mean wait for the tick and the engine's gap
between a delivery and its next request. A delivered count is not a completed-frame count: judge jank by
FrameTiming (`tool/performance/lab.py`).

The UI isolate runs on its own thread (`RAFT_LINUX_UI_THREAD=platform` restores the engine default, the GTK
main thread). On the main thread each frame's build starts only after GTK has painted the previous frame, which
costs several ms at 2x scale: frames of 3 ms of work missed a 120 Hz refresh about one time in ten. Measured on
a headless 120 Hz, 2x compositor: frame interval p99 14.4 ms (platform thread) vs 9.2 ms (own thread).
`RAFT_LINUX_IMPELLER=0|1` selects Skia or Impeller for A/B measurements.

Flutter upgrade: upstream is moving all desktop embedders to merged platform/UI threads (macOS and Windows already
log a deprecation warning when unmerged). In 3.47.6 Linux `fl_dart_project_set_ui_thread_policy(
FL_UI_THREAD_POLICY_RUN_ON_SEPARATE_THREAD)` is public and warns about nothing. After an upgrade confirm the
policy still exists (the runner stops compiling if it is removed) and re-run the Linux pacing lab if its behaviour
changes.

On a Flutter upgrade, re-check that `FlutterEngineProcTable` / `FlutterProjectArgs` still match the vendored
`flutter_embedder.h` (the driver refuses to patch an engine whose layout it does not recognise and leaves the
60 Hz timer).
