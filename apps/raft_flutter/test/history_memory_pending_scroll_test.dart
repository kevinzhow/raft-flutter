import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_memory.dart';
import 'package:raft_flutter/data/message_history.dart';

void main() {
  testWidgets('scrolling during a proof still finishes deferred trimming', (
    tester,
  ) async {
    final changes = ValueNotifier(0),
        proving = Completer<void>(),
        finish = Completer<void>();
    var position = 0, captures = 0;
    final rows = <String, List<Map<String, dynamic>>>{
      for (var n = 1; n <= 2; n++)
        '$n': [
          {'id': '$n', 'seq': '$n'},
        ],
    };
    final pool = HistoryMemoryPool((scope, versions) async {
      if (!proving.isCompleted) {
        proving.complete();
        await finish.future;
      }
      return [
        for (final id in versions.keys) (id: id, bytes: 1, durable: true),
      ];
    }, activeLimit: 1);
    addTearDown(() {
      pool.close();
      changes.dispose();
    });
    pool.register(
      changes,
      HistoryMemoryPort(
        changes: changes,
        stamp: () => changes.value,
        capture: () async {
          captures++;
          final sampled = position;
          return [
            HistoryMemoryWindow(
              scope: const MessageHistoryScope(
                origin: 'https://scroll.invalid',
                principal: 'fixture',
                server: 'fixture',
                channel: 'fixture',
                parentChannel: 'fixture',
                authority: 'fixture',
              ),
              versions: Map.of(rows),
              active: true,
              current: () => sampled == position,
              release: (ids) {
                ids.forEach(rows.remove);
                return ids;
              },
            ),
          ];
        },
      ),
    );
    final work = pool.maintain();
    await proving.future;
    pool.samplePosition(changes, () => position++);
    await tester.pump(const Duration(milliseconds: 200));
    finish.complete();
    await work;
    await tester.pump(const Duration(seconds: 1));
    expect(captures, 2);
    expect(
      rows,
      hasLength(1),
      reason: 'A stale proof must not leave the budget unenforced',
    );
  });
}
