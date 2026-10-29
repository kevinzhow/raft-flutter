import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as capacity;

void main() {
  test(
    'maintenance compacts pre-existing eviction receipts even below the quota',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final scope = capacity.scope('old');
      await capacity.store(
        cache,
        scope,
        capacity.rows('old', 1, 1000, bytes: 1),
      );
      await cache.customStatement(
        "UPDATE raft_history_rows SET tombstone=2,payload='{}',byte_size=0",
      );
      expect(
        await capacity.count(
          cache,
          'SELECT count(*) FROM raft_history_rows WHERE tombstone=2',
        ),
        1000,
      );
      await cache.messageHistory.capacity.maintain(capacity.account);
      expect(
        await capacity.count(
          cache,
          'SELECT count(*) FROM raft_history_rows WHERE tombstone=2',
        ),
        256,
      );
      expect(
        (await cache.messageHistory.capacity.usage(capacity.account)).rows,
        0,
      );
    },
  );

  test('eviction receipts stay bounded while old copies cannot resurrect bodies', () async {
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      historyBudget: 512 << 10,
      historyHardLimitEnabled: false,
      automaticHistoryMaintenance: false,
    );
    addTearDown(cache.close);
    final store = cache.messageHistory, scope = capacity.scope('cold');
    final original = capacity.rows('cold', 1, 1200, bytes: 4096);
    await capacity.store(cache, scope, original);
    final oldRevision = await store.revision(scope);
    final oldPage = MessageHistoryPage(
      {'messages': original},
      scope: scope,
      revision: oldRevision,
      before: null,
      after: null,
      local: false,
      limit: 1200,
    );
    await store.capacity.maintain(capacity.account);
    expect(
      await capacity.count(
        cache,
        'SELECT count(*) FROM raft_history_rows WHERE tombstone=2',
      ),
      lessThanOrEqualTo(256),
    );
    final compacted = original.first;
    // The oldest id sorts first in the LRU fixture and its receipt is compacted.
    final missing = await store.readContext(
      scope,
      compacted['id'] as String,
      radius: 0,
    );
    expect(missing, isNull);
    var reads = 0;
    final fresh = await MessageHistoryPages.load(
      cache: cache,
      scope: scope,
      current: () => true,
      held: () => const [],
      localFirst: false,
      remote: () async {
        reads++;
        return {
          'messages': [compacted],
        };
      },
    );
    expect(reads, 1);
    // An earlier request must fail, even after its individual receipt is gone.
    await store.acceptPage(oldPage);
    expect(
      await store.readContext(scope, compacted['id'] as String, radius: 0),
      isNull,
    );
    final reconciled = store.reconcilePage(scope, {
      'messages': [compacted],
    }, requestedRevision: oldRevision);
    await expectLater(reconciled, throwsA(isA<HistoryReadRetired>()));
    final legacy = {
      'version': 1,
      'windowKind': 'tail',
      'authority': scope.authority,
      'parentChannelId': scope.channel,
      'messages': [compacted],
    };
    await store.importWindow(
      scope.origin,
      scope.principal,
      scope.server,
      'window',
      scope.channel,
      legacy,
    );
    expect(
      await store.readContext(scope, compacted['id'] as String, radius: 0),
      isNull,
    );
    await store.acceptPage(fresh as MessageHistoryPage);
    expect(
      (await store.readContext(
        scope,
        compacted['id'] as String,
        radius: 0,
      ))!['messages'],
      hasLength(1),
    );
    final weight = await cache
        .customSelect('SELECT weight FROM raft_history_sizes')
        .getSingle();
    expect(weight.read<int>('weight'), greaterThan(0));
    await cache.clearAccount(scope.origin, scope.principal);
    expect(
      await capacity.count(cache, 'SELECT count(*) FROM raft_history_rows'),
      0,
    );
    expect(
      await capacity.count(cache, 'SELECT count(*) FROM raft_history_sizes'),
      0,
    );
  });

  test(
    'a compacted receipt boundary retries an in-flight HTTP response once',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        historyBudget: 512 << 10,
        historyHardLimitEnabled: false,
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final store = cache.messageHistory, scope = capacity.scope('cold');
      final rows = capacity.rows('cold', 1, 1200, bytes: 4096);
      await capacity.store(cache, scope, rows);
      var requests = 0;
      final result = await MessageHistoryPages.load(
        cache: cache,
        scope: scope,
        current: () => true,
        held: () => const [],
        localFirst: false,
        remote: () async {
          requests++;
          if (requests == 1) await store.capacity.maintain(capacity.account);
          return {
            'messages': [rows.first],
          };
        },
      );
      expect(requests, 2);
      expect(result['messages'], hasLength(1));
      expect(jsonEncode(result['messages']).contains('cold-1'), isTrue);
    },
  );
}
