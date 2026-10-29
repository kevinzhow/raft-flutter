import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/cache_exit.dart';
import 'package:raft_updater/raft_updater.dart' show AppUpdater;

void main() {
  final originalLog = cacheExitLog;
  tearDown(() {
    cacheExitLog = originalLog;
    resetCacheExitForTest();
    bindCacheExit(null);
  });

  test('close finishes before the waiter can return exit', () async {
    final order = <String>[];
    final lines = <String>[];
    cacheExitLog = lines.add;
    final outcome = await closeCacheForExit(() async {
      order.add('close');
    });
    order.add('exit');
    expect(outcome, CacheExitOutcome.completed);
    expect(order, ['close', 'exit']);
    expect(lines, ['raft.cache_exit completed']);
    expect(cacheExitBudget, const Duration(seconds: 2));
  });

  test('a close that does not finish times out and still returns', () async {
    final outcome = await closeCacheWithin(
      () => Completer<void>().future,
      const Duration(milliseconds: 30),
    );
    expect(outcome, CacheExitOutcome.timedOut);
  });

  test('a missing close is absent and does not wait', () async {
    final started = DateTime.now();
    final outcome = await closeCacheWithin(null, const Duration(seconds: 5));
    expect(outcome, CacheExitOutcome.absent);
    expect(DateTime.now().difference(started).inSeconds, 0);
  });

  test('a failing close is failed and does not throw', () async {
    final outcome = await closeCacheWithin(
      () async => throw StateError('close failed'),
      const Duration(seconds: 1),
    );
    expect(outcome, CacheExitOutcome.failed);
  });

  test('repeated calls share one close, including after it finished', () async {
    var calls = 0;
    final gate = Completer<void>();
    Future<void> close() {
      calls++;
      return gate.future;
    }

    final first = closeCacheWithin(close, const Duration(seconds: 1));
    final joined = closeCacheWithin(close, const Duration(seconds: 1));
    expect(calls, 1);
    gate.complete();
    expect(await first, CacheExitOutcome.completed);
    expect(await joined, CacheExitOutcome.completed);

    final again = await closeCacheWithin(close, const Duration(seconds: 1));
    expect(again, CacheExitOutcome.completed);
    expect(calls, 1);
  });

  test('bindCacheExit shares one hook and clears both callers', () async {
    var calls = 0;
    bindCacheExit(() async {
      calls++;
      return CacheExitOutcome.completed;
    });
    await AppUpdater.requiredExitHook!.call();
    expect(await cachePrepareExit!.call(), CacheExitOutcome.completed);
    expect(calls, 2);
    bindCacheExit(null);
    expect(AppUpdater.requiredExitHook, isNull);
    expect(cachePrepareExit, isNull);
  });
}
