import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as fixture;

void main() {
  test(
    'full compaction cannot skip legacy windows that are still being imported',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'raft-compaction-import-',
      );
      final file = File('${dir.path}/workspace.sqlite');
      final old = DriftWorkspaceCache(
        NativeDatabase(file),
        messageHistoryEnabled: false,
        automaticHistoryMaintenance: false,
      );
      for (var i = 1; i <= 3; i++) {
        final id = 'old$i';
        await old.write(
          fixture.account.origin,
          fixture.account.principal,
          'one',
          'window',
          id,
          {
            'version': 1,
            'windowKind': 'tail',
            'authority': 'member',
            'parentChannelId': id,
            'messages': fixture.rows(id, 1, 1, bytes: 128),
            'hasMore': false,
            'historyLimited': false,
          },
        );
      }
      await old.customStatement('PRAGMA auto_vacuum=NONE');
      await old.customStatement('VACUUM');
      await old.customStatement(
        'UPDATE workspace_cache SET rowid=rowid+100000',
      );
      await old.close();
      final cache = DriftWorkspaceCache(
        NativeDatabase(file),
        automaticHistoryMaintenance: false,
        historyAvailableSpace: (_) async => 1 << 40,
      );
      addTearDown(() async {
        await cache.close();
        await dir.delete(recursive: true);
      });
      final history = cache.messageHistory;
      expect(await history.migrateLegacy(fixture.scope('chat'), limit: 1), 1);
      expect(
        await history.readContext(fixture.scope('old3'), 'old3-1', radius: 0),
        isNull,
      );
      await history.capacity.maintain(
        fixture.account,
        compact: true,
        allowFullVacuum: true,
      );
      await history.migrateLegacy(fixture.scope('chat'), limit: 4);
      expect(
        await history.readContext(fixture.scope('old3'), 'old3-1', radius: 0),
        isNotNull,
      );
    },
  );
}
