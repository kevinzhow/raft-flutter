import 'dart:async';

import 'package:raft_updater/raft_updater.dart' show AppUpdater;

/// How long an exit waits for the background database to close.
const Duration cacheExitBudget = Duration(seconds: 2);

/// What the exit waiter observed. The process still exits in every case.
enum CacheExitOutcome {
  /// No close function was supplied.
  absent,

  /// Close finished inside the budget.
  completed,

  /// The budget elapsed before close finished.
  timedOut,

  /// Close threw. The waiter still finishes.
  failed,
}

/// Prints `raft.cache_exit <outcome>`. Quit runs read this line.
void Function(String message) cacheExitLog = _logCacheExit;

void _logCacheExit(String message) {
  // ignore: avoid_print -- quit runs read this line from the process log
  print(message);
}

Future<CacheExitOutcome>? _inflight;

/// Waits for [close] for at most [budget].
///
/// A null [close] returns [CacheExitOutcome.absent] and does not start a
/// timer. Later calls, including a call after the first close finished, join
/// that same close and do not call [close] again.
Future<CacheExitOutcome> closeCacheWithin(
  Future<void> Function()? close,
  Duration budget,
) {
  if (close == null) {
    return Future<CacheExitOutcome>.value(CacheExitOutcome.absent);
  }
  return _inflight ??= _closeWithin(close, budget);
}

Future<CacheExitOutcome> _closeWithin(
  Future<void> Function() close,
  Duration budget,
) {
  final done = Completer<CacheExitOutcome>();
  final timer = Timer(budget, () {
    if (!done.isCompleted) done.complete(CacheExitOutcome.timedOut);
  });
  close()
      .then<void>(
        (_) {
          if (!done.isCompleted) done.complete(CacheExitOutcome.completed);
        },
        onError: (Object _, StackTrace _) {
          if (!done.isCompleted) done.complete(CacheExitOutcome.failed);
        },
      )
      .whenComplete(timer.cancel);
  return done.future;
}

/// Native `prepareExit` and the updater's required exit share this hook.
Future<CacheExitOutcome> Function()? cachePrepareExit;

/// Points both exit callers at [hook]. Null clears both.
void bindCacheExit(Future<CacheExitOutcome> Function()? hook) {
  AppUpdater.requiredExitHook = hook == null ? null : () => hook();
  cachePrepareExit = hook;
}

/// Closes with [cacheExitBudget] and logs `raft.cache_exit <outcome>`.
Future<CacheExitOutcome> closeCacheForExit(
  Future<void> Function()? close,
) async {
  final outcome = await closeCacheWithin(close, cacheExitBudget);
  cacheExitLog('raft.cache_exit ${outcome.name}');
  return outcome;
}

/// Drops the shared close so a test can start another one.
void resetCacheExitForTest() {
  _inflight = null;
}
