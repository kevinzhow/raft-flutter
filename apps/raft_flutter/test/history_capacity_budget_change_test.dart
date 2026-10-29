import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/platform/history_capacity.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

const account = HistoryAccount('https://budget-change.invalid', 'alice');
const scope = MessageHistoryScope(
  origin: 'https://budget-change.invalid',
  principal: 'alice',
  server: 'server',
  channel: 'chat',
  parentChannel: 'chat',
  authority: 'member',
);
void main() {
  test('raising the limit during maintenance stops the earlier eviction goal', () async {
    final db = DriftWorkspaceCache(
      NativeDatabase.memory(),
      historyBudget: 128 << 10,
      historyHardLimitEnabled: false,
      automaticHistoryMaintenance: false,
    );
    addTearDown(db.close);
    await db.messageHistory.acceptEvents(scope, [
      for (var i = 1; i <= 2000; i++)
        {
          'id': 'row-$i',
          'channelId': 'chat',
          'seq': '$i',
          'content': 'body' * 64,
        },
    ]);
    var raised = false;
    Future<T> order<T>(Future<T> Function() action) async {
      final result = await action();
      if (result is HistoryDiskUsage && !raised) {
        raised = true;
        await db.customStatement(
          "INSERT INTO workspace_cache VALUES(?,?,'','history-budget','',?) ON CONFLICT(origin,principal,server,kind,id) DO UPDATE SET payload=excluded.payload",
          [account.origin, account.principal, '${5 << 30}'],
        );
      }
      return result;
    }

    final cap = SqliteHistoryCapacity(
      db,
      order,
      ready: () async {},
      advance: (_) async => 100,
      now: DateTime.now,
      defaultBudget: 128 << 10,
      automatic: false,
    );
    addTearDown(cap.close);
    final result = await cap.maintain(account);
    expect(raised, isTrue);
    expect(result.budget, 5 << 30);
    expect(
      (await db
              .customSelect(
                'SELECT count(*) AS n FROM raft_history_rows WHERE tombstone=0',
              )
              .getSingle())
          .read<int>('n'),
      2000,
    );
  });
}
