import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/history_size_counters.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as fixture;

void main() {
  test(
    'updates, deletes and new rows remain exact across a backfilled prefix',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final db = cache.messageHistory, scope = fixture.scope('chat');
      await db.acceptEvents(scope, fixture.rows('chat', 1, 1205, bytes: 128));
      final counter = HistorySizeCounters(cache);
      expect(await counter.backfillNow(), isFalse);
      expect(
        await fixture.count(cache, 'SELECT sum(rows) FROM raft_history_sizes'),
        1000,
      );
      await db.acceptEvents(scope, [
        ...fixture.rows('chat', 100, 100, bytes: 4096),
        ...fixture.rows('chat', 1205, 1205, bytes: 4096),
      ]);
      await cache.customStatement(
        "DELETE FROM raft_history_rows WHERE message_id IN ('chat-20','chat-1204')",
      );
      await db.acceptEvents(
        scope,
        fixture.rows('chat', 1300, 1300, bytes: 4096),
      );
      while (!await counter.backfillNow()) {}
      expect(
        await fixture.count(cache, 'SELECT sum(rows) FROM raft_history_sizes'),
        1204,
      );
      expect(
        await fixture.count(
          cache,
          'SELECT sum(payload) FROM raft_history_sizes',
        ),
        await fixture.count(
          cache,
          'SELECT sum(byte_size) FROM raft_history_rows',
        ),
      );
      await cache.clearAccount(
        fixture.account.origin,
        fixture.account.principal,
      );
      expect(
        await fixture.count(cache, 'SELECT count(*) FROM raft_history_sizes'),
        0,
      );
      expect(
        await fixture.count(
          cache,
          'SELECT count(*) FROM raft_history_cache_sizes',
        ),
        0,
      );
    },
  );
}
