import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

class VacuumFailureCache extends DriftWorkspaceCache {
  VacuumFailureCache()
    : super(
        NativeDatabase.memory(),
        historyBudget: 128 << 10,
        historyHardLimitEnabled: false,
        automaticHistoryMaintenance: false,
      );
  bool failVacuum = false;
  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) {
    if (failVacuum &&
        (statement.startsWith('PRAGMA incremental_vacuum') ||
            statement == 'VACUUM')) {
      throw StateError('Synthetic temporary compaction failure');
    }
    return super.customStatement(statement, args);
  }
}

const account = HistoryAccount('https://vacuum-recovery.invalid', 'alice');
const scope = MessageHistoryScope(
  origin: 'https://vacuum-recovery.invalid',
  principal: 'alice',
  server: 'server',
  channel: 'chat',
  parentChannel: 'chat',
  authority: 'member',
);
List<Map<String, dynamic>> rows(int first, int last) => [
  for (var i = first; i <= last; i++)
    {'id': 'row-$i', 'channelId': 'chat', 'seq': '$i', 'content': 'x' * 8192},
];
void main() {
  test('compaction failure does not preserve a retired full-budget admission block', () async {
    final db = VacuumFailureCache(),
        cap = db.messageHistory.capacity,
        owner = Object();
    addTearDown(db.close);
    cap.protect(
      owner,
      () => [
        HistoryProtectedRows(
          account,
          'server',
          'chat',
          const [],
          wholeChannel: true,
        ),
      ],
    );
    await db.messageHistory.acceptEvents(scope, rows(1, 100));
    expect((await cap.maintain(account)).protectedFull, isTrue);
    cap.release(owner);
    db.failVacuum = true;
    await expectLater(cap.maintain(account, compact: true), throwsStateError);
    await db.messageHistory.acceptEvents(scope, rows(101, 101));
    expect(
      (await db.messageHistory.readPage(scope))!.rows.map((row) => row['id']),
      contains('row-101'),
    );
  });
}
