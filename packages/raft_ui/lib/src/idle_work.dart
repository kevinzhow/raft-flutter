import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shared rules for deferred, low-priority work.
///
/// `SchedulerBinding.scheduleTask(..., Priority.idle)` is rejected while a
/// ticker is running, and Flutter retries a rejected task through `Timer.run`
/// (a zero-delay timer). One pending idle task therefore turns every running
/// animation into a hot event-loop spin: a pegged core on any platform, and a
/// starved native message pump on Windows. Raft code must not use
/// `Priority.idle` or re-arm zero-delay timers. Use [RaftIdleTimer] instead;
/// `test/idle_work_guard_test.dart` enforces this.
abstract final class RaftIdleWork {
  /// Shortest delay any deferred step may use. A positive delay always
  /// returns control to the platform event loop before the next step.
  static const minDelay = Duration(milliseconds: 1);

  /// Whether a frame is being produced or an animation ticker is running.
  /// Deferred work that is not needed for the current frame waits for this to
  /// clear.
  static bool get animating {
    final scheduler = SchedulerBinding.instance;
    return scheduler.schedulerPhase != SchedulerPhase.idle ||
        scheduler.transientCallbackCount > 0;
  }

  /// [delay] raised to at least [minDelay].
  static Duration positive(Duration delay) =>
      delay < minDelay ? minDelay : delay;
}

/// One-shot timer for deferred work with a positive delay and a retry gate.
///
/// [start] runs the task once, no sooner than `delay` (never less than
/// [RaftIdleWork.minDelay]). When the gate is closed, because [canRun] is
/// false or, with [yieldToAnimation], an animation or frame is in progress,
/// the timer polls again after [retry] instead of spinning. The timer never
/// re-arms itself with a zero delay.
class RaftIdleTimer {
  RaftIdleTimer({
    this.retry = const Duration(milliseconds: 250),
    Duration? maxRetry,
    this.canRun,
    this.yieldToAnimation = true,
  }) : maxRetry = maxRetry ?? retry;

  /// Poll interval while the gate is closed. After a few closed polls it
  /// doubles each time up to [maxRetry], so a gate that stays shut (a pane
  /// hidden behind another route) costs fewer and fewer wake-ups.
  final Duration retry;

  /// Longest poll interval.
  final Duration maxRetry;

  /// Extra caller gate (input quiet, route settled, ...).
  final bool Function()? canRun;

  /// Whether to wait for [RaftIdleWork.animating] to clear.
  final bool yieldToAnimation;

  Timer? _timer;
  VoidCallback? _task;
  Duration _nextRetry = Duration.zero;
  int _blockedInARow = 0;
  static const _steadyPolls = 4;

  /// Whether a run is pending.
  bool get isActive => _timer != null;

  /// Number of gate polls that found the gate closed (diagnostics, tests).
  @visibleForTesting
  int blockedPolls = 0;

  /// Replaces any pending run with [task] after [delay].
  void start(Duration delay, VoidCallback task) {
    _timer?.cancel();
    _task = task;
    _nextRetry = retry;
    _blockedInARow = 0;
    _timer = Timer(RaftIdleWork.positive(delay), _fire);
  }

  void _fire() {
    final task = _task;
    _timer = null;
    if (task == null) return;
    if ((yieldToAnimation && RaftIdleWork.animating) ||
        !(canRun?.call() ?? true)) {
      blockedPolls++;
      _timer = Timer(RaftIdleWork.positive(_nextRetry), _fire);
      // A short animation or a scroll clears quickly, so the first few polls
      // stay at [retry]; a gate that is still shut then backs off.
      if (++_blockedInARow > _steadyPolls) {
        final doubled = _nextRetry * 2;
        _nextRetry = doubled > maxRetry ? maxRetry : doubled;
      }
      return;
    }
    _task = null;
    task();
  }

  /// Drops the pending run, if any.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _task = null;
  }
}

/// Periodic timer that only runs while the app can be seen.
///
/// A plain `Timer.periodic` keeps waking the process (and the network, for a
/// poll) while the window is minimised or the app is backgrounded. This timer
/// stops on [AppLifecycleState.hidden], [AppLifecycleState.paused] and
/// [AppLifecycleState.detached], and restarts on return without firing
/// immediately: callers already refresh on [AppLifecycleState.resumed]. An
/// unfocused but visible window ([AppLifecycleState.inactive]) keeps running.
///
/// Use it for polls and clocks that only matter on screen. Work that must
/// continue in the background (a dock badge, a push-state reconcile) uses
/// `Timer.periodic` and says so in the idle guard's allowlist.
class RaftForegroundPeriodic {
  RaftForegroundPeriodic(this.interval, this.onTick) {
    _listener = AppLifecycleListener(onStateChange: _changed);
    _changed(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
  }

  final Duration interval;
  final VoidCallback onTick;
  late final AppLifecycleListener _listener;
  Timer? _timer;

  /// Whether the timer is currently armed.
  bool get isRunning => _timer != null;

  void _changed(AppLifecycleState state) {
    final visible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (visible && _timer == null) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- RaftForegroundPeriodic itself: the sanctioned periodic timer; it stops while the app is hidden, paused or detached.
      _timer = Timer.periodic(RaftIdleWork.positive(interval), (_) => onTick());
    } else if (!visible) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _listener.dispose();
  }
}
