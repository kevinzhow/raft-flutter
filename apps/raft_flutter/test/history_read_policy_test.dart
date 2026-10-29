import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_read_policy.dart';

void main() {
  final key = (
    'origin',
    'alice',
    'server',
    'channel',
    'authority',
    'ticket',
    'page',
  );
  test('verification uses age, foreground visit and authority, without expiring messages', () {
    var now = DateTime.utc(2026, 10, 15);
    final policy = HistoryReadPolicy(now: () => now), owner = Object();
    addTearDown(policy.close);
    expect(policy.claim(owner, 0, key, now), isFalse);
    now = now.add(const Duration(hours: 24));
    final old = now.subtract(const Duration(hours: 24));
    expect(policy.claim(owner, 0, key, old), isTrue);
    expect(policy.claim(owner, 0, key, old), isFalse);
    expect(policy.claim(owner, 1, key, old), isTrue);
    expect(policy.claim(Object(), 1, key, old), isTrue);
    expect(policy.claim(owner, 1, key, now, force: true), isTrue);
    expect(policy.claim(owner, 1, key, now, force: true), isTrue);
    policy.forget(owner);
    expect(
      policy.claim(owner, 1, key, now.add(const Duration(days: 1))),
      isTrue,
    );
    policy.close();
    expect(policy.claim(owner, 2, key, null, force: true), isFalse);
  });

  test(
    'identical in-flight requests share one wire read and retry after failure',
    () async {
      final policy = HistoryReadPolicy(),
          held = Completer<Map<String, dynamic>>();
      addTearDown(policy.close);
      var calls = 0;
      Future<Map<String, dynamic>> read() {
        calls++;
        return held.future;
      }

      final first = policy.fetch(key, HistoryReadReason.aged, read);
      final second = policy.fetch(key, HistoryReadReason.manual, read);
      expect(calls, 1);
      expect(identical(first, second), isTrue);
      held.complete({'messages': []});
      await first;
      await second;
      expect(policy.counts[HistoryReadReason.aged], 1);
      expect(policy.counts[HistoryReadReason.manual], isNull);
      await expectLater(
        policy.fetch(
          key,
          HistoryReadReason.manual,
          () async => throw StateError('offline'),
        ),
        throwsStateError,
      );
      await policy.fetch(key, HistoryReadReason.manual, () async {
        calls++;
        return {};
      });
      expect(calls, 2);
      expect(policy.counts[HistoryReadReason.manual], 2);
    },
  );
}
