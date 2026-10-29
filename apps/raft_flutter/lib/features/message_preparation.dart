import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show RaftIdleTimer;

/// Platform Back progress can be driven without an animation ticker or
/// Flutter pointer events. Quiet input alone does not make that route idle.
bool messagePreparationRouteIsIdle(ModalRoute<dynamic>? route) {
  if (route == null) return true;
  bool moving(Animation<double>? animation) =>
      animation?.status == AnimationStatus.forward ||
      animation?.status == AnimationStatus.reverse;
  return route.isCurrent &&
      !route.navigator!.userGestureInProgress &&
      !moving(route.animation) &&
      !moving(route.secondaryAnimation);
}

/// Prepares bounded message batches between frames while input is idle.
///
/// Replacement and disposal cancel queued work, including a task already
/// submitted to the scheduler. Callers own the current authority and decide
/// whether their pane is idle through [isIdle].
class MessagePreparation {
  MessagePreparation({
    required this.isIdle,
    void Function(VoidCallback)? scheduleIdle,
  }) : _scheduleIdle = scheduleIdle ?? ((task) => task()) {
    // Never `SchedulerBinding.scheduleTask(Priority.idle)`: Flutter retries a
    // rejected idle task through Timer.run, a zero-delay hot loop while any
    // animation runs (see RaftIdleWork). The timer's positive-delay poll
    // yields to the platform loop and waits out animation, frames and
    // [isIdle]; it backs off to one wake-up a second while a pane stays
    // hidden.
    _timer = RaftIdleTimer(
      maxRetry: const Duration(seconds: 1),
      canRun: isIdle,
    );
  }
  final void Function(VoidCallback) _scheduleIdle;

  final bool Function() isIdle;
  final _jobs = Queue<VoidCallback>();
  late final RaftIdleTimer _timer;
  int _revision = 0;
  bool _disposed = false;

  /// Replaces pending work with at most 64 messages in nearest-first order.
  void replace(Iterable<VoidCallback> jobs) {
    cancel();
    if (_disposed) return;
    _jobs.addAll(jobs.take(64));
    _arm(const Duration(milliseconds: 250));
  }

  /// Cancels pending work without changing any cache or application state.
  void cancel() {
    ++_revision;
    _timer.cancel();
    _jobs.clear();
  }

  void _arm(Duration delay) {
    if (_disposed || _jobs.isEmpty) return;
    _timer.start(delay, _run);
  }

  void _run() {
    if (_disposed || _jobs.isEmpty) return;
    final revision = _revision;
    _scheduleIdle(() {
      if (_disposed || revision != _revision) return;
      if (isIdle()) _jobs.removeFirst()();
      _arm(const Duration(milliseconds: 16));
    });
  }

  /// Cancels all work and retires this preparation owner.
  void dispose() {
    _disposed = true;
    cancel();
  }
}
