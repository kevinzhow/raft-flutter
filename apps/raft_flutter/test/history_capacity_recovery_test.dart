import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

const account = HistoryAccount('https://recovery.invalid', 'alice');
const scope = MessageHistoryScope(
  origin: 'https://recovery.invalid',
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
  test('released protection automatically restores writes without opening settings', () async {
    final db = DriftWorkspaceCache(
          NativeDatabase.memory(),
          historyBudget: 128 << 10,
          historyHardLimitEnabled: false,
        ),
        cap = db.messageHistory.capacity,
        owner = Object();
    addTearDown(db.close);
    cap.protect(
      owner,
      () => [
        HistoryProtectedRows(account, 'server', 'chat', [
          for (var i = 1; i <= 100; i++) 'row-$i',
        ]),
      ],
    );
    await db.messageHistory.acceptEvents(scope, rows(1, 100));
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect((await cap.usage(account)).protectedFull, isTrue);
    cap.release(owner);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    await db.messageHistory.acceptEvents(scope, rows(101, 101));
    expect(
      (await db.messageHistory.readPage(scope))!.rows.map((row) => row['id']),
      contains('row-101'),
    );
    expect((await cap.usage(account)).protectedFull, isFalse);
  });
  test(
    'changed protection recovers on its retry without a settings action',
    () async {
      final db = DriftWorkspaceCache(
            NativeDatabase.memory(),
            historyBudget: 128 << 10,
            historyHardLimitEnabled: false,
          ),
          cap = db.messageHistory.capacity;
      addTearDown(db.close);
      var held = true;
      cap.protect(
        Object(),
        () => held
            ? [
                HistoryProtectedRows(
                  account,
                  'server',
                  'chat',
                  const [],
                  wholeChannel: true,
                ),
              ]
            : [],
      );
      await db.messageHistory.acceptEvents(scope, rows(1, 100));
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect((await cap.usage(account)).protectedFull, isTrue);
      held = false;
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      await db.messageHistory.acceptEvents(scope, rows(101, 101));
      expect((await cap.usage(account)).protectedFull, isFalse);
      expect(
        (await db.messageHistory.readPage(scope))!.rows.map((row) => row['id']),
        contains('row-101'),
      );
    },
  );

  test('a transient file measurement failure does not permanently reject later writes', () async {
    final dir = await Directory.systemTemp.createTemp(
          'raft-capacity-recovery-',
        ),
        file = File('${dir.path}/workspace.sqlite'),
        moved = File('${dir.path}/moved.sqlite');
    final db = DriftWorkspaceCache(
      NativeDatabase.createInBackground(file),
      automaticHistoryMaintenance: false,
    );
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    await db.messageHistory.acceptEvents(scope, rows(1, 20));
    await db.messageHistory.capacity.usage(account);
    await file.rename(moved.path);
    await expectLater(
      db.messageHistory.capacity.maintain(account),
      throwsA(isA<FileSystemException>()),
    );
    await moved.rename(file.path);
    await db.messageHistory.acceptEvents(scope, rows(21, 21));
    expect((await db.messageHistory.readPage(scope))!.rows, hasLength(21));
  }, skip: !Platform.isLinux);
}
