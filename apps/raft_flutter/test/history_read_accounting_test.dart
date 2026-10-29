import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as fixture;

void main() {
  test(
    'reading 50 saved messages does not rewrite unchanged size counters',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final scope = fixture.scope('chat');
      await fixture.store(
        cache,
        scope,
        fixture.rows('chat', 1, 100, bytes: 100),
      );
      final before = await cache.messageHistory.capacity.usage(fixture.account);
      await cache.customStatement('UPDATE raft_history_rows SET touched=0');
      await cache.customStatement(
        'CREATE TEMP TABLE counter_writes(n INTEGER)',
      );
      await cache.customStatement('INSERT INTO counter_writes VALUES(0)');
      await cache.customStatement(
        'CREATE TEMP TRIGGER counter_write_probe AFTER UPDATE ON raft_history_sizes BEGIN UPDATE counter_writes SET n=n+1; END',
      );
      final page = await cache.messageHistory.readPage(
        scope,
        before: BigInt.from(100),
      );
      expect(page!.rows, hasLength(50));
      expect(
        await fixture.count(
          cache,
          'SELECT count(*) FROM raft_history_rows WHERE touched>0',
        ),
        50,
      );
      expect(await fixture.count(cache, 'SELECT n FROM counter_writes'), 0);
      final after = await cache.messageHistory.capacity.usage(fixture.account);
      expect(after.rows, before.rows);
      expect(after.accountBytes, before.accountBytes);
      await cache.messageHistory.acceptEvents(
        scope,
        fixture.rows('chat', 101, 101, bytes: 100),
      );
      expect(
        (await cache.messageHistory.capacity.usage(fixture.account)).rows,
        101,
      );
      expect(
        await fixture.count(cache, 'SELECT n FROM counter_writes'),
        greaterThan(0),
      );
      await fixture.store(
        cache,
        scope,
        fixture.rows('chat', 1, 100, bytes: 100),
      );
      expect(
        (await cache.messageHistory.capacity.usage(fixture.account)).rows,
        100,
      );
      expect(
        await fixture.count(cache, 'SELECT payload FROM raft_history_sizes'),
        await fixture.count(
          cache,
          'SELECT sum(byte_size) FROM raft_history_rows',
        ),
      );
    },
  );
}
