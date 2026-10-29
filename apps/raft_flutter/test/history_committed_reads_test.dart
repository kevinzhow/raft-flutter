import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_flutter/data/cached_history_window.dart';
import 'package:raft_flutter/data/reading_positions.dart';

import 'message_history_store_test.dart' as fixture;

class _Gate extends QueryInterceptor {
  bool draft = false, read = false;
  bool holdMutation = false;
  final reached = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    if (draft &&
        sql.startsWith('DELETE FROM workspace_cache') &&
        args.contains('hold')) {
      draft = false;
      reached.complete();
      await release.future;
    }
    await super.runCustom(executor, sql, args);
    if (holdMutation &&
        sql.startsWith('UPDATE raft_history_rows SET payload')) {
      holdMutation = false;
      reached.complete();
      await release.future;
    }
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final rows = await super.runSelect(executor, sql, args);
    if (read &&
        (sql.contains('FROM workspace_cache') ||
            sql.contains('raft-history-snapshot'))) {
      read = false;
      reached.complete();
      await release.future;
    }
    return rows;
  }
}

void main() {
  late Directory directory;
  late DriftWorkspaceCache cache;
  late _Gate gate;
  final scope = fixture.scope();

  Future<dynamic> committed() => cache.readCommittedWindow(
    scope.origin,
    scope.principal,
    scope.server,
    'window',
    scope.channel,
  );

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('raft-history-read-pool-');
    gate = _Gate();
    cache = DriftWorkspaceCache(
      NativeDatabase.createInBackground(
        File('${directory.path}/cache.sqlite'),
        readPool: 1,
      ).interceptWith(gate),
      automaticHistoryMaintenance: false,
    );
    await cache.write(
      scope.origin,
      scope.principal,
      scope.server,
      'window',
      scope.channel,
      {
        ...fixture.legacy(scope.channel),
        'messages': fixture.rows(1, 100),
        'windowSize': 50,
      },
    );
    await cache.customStatement(
      "UPDATE workspace_cache SET payload=json_set(payload,'\$.windowSize',50) WHERE kind='message-history'",
    );
  });
  tearDown(() async {
    if (!gate.release.isCompleted) gate.release.complete();
    await cache.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'committed window returns while a separate cache write is held',
    () async {
      gate.draft = true;
      final writing = cache.write(
        scope.origin,
        scope.principal,
        scope.server,
        'draft',
        'hold',
        {'text': 'next'},
      );
      await gate.reached.future.timeout(const Duration(seconds: 5));
      try {
        final saved = await committed().timeout(const Duration(seconds: 3));
        expect((saved as Map)['messages'], hasLength(50));
        expect((saved['messages'] as List).last['id'], 'chat-100');
      } finally {
        gate.release.complete();
        await writing;
      }
    },
  );

  test(
    'a revoke invalidates a captured window before it is returned',
    () async {
      gate.read = true;
      final reading = committed();
      await gate.reached.future.timeout(const Duration(seconds: 5));
      final revoked = cache.revokeChannel(
        scope.origin,
        scope.principal,
        scope.server,
        scope.channel,
      );
      gate.release.complete();
      expect(await reading, isNull);
      await revoked;
      expect(await committed(), isNull);
    },
  );

  for (final account in [false, true]) {
    test(
      '${account ? 'account clear' : 'server revoke'} invalidates a captured window',
      () async {
        gate.read = true;
        final reading = committed();
        await gate.reached.future;
        final purging = account
            ? cache.clearAccount(scope.origin, scope.principal)
            : cache.revokeServer(scope.origin, scope.principal, scope.server);
        gate.release.complete();
        expect(await reading, isNull);
        await purging;
        expect(await committed(), isNull);
      },
    );
  }

  test(
    'a read started while the purge is queued cannot see retained rows',
    () async {
      gate.draft = true;
      final writing = cache.write(
        scope.origin,
        scope.principal,
        scope.server,
        'draft',
        'hold',
        {},
      );
      await gate.reached.future;
      final purging = cache.revokeChannel(
        scope.origin,
        scope.principal,
        scope.server,
        scope.channel,
      );
      try {
        expect(await committed().timeout(const Duration(seconds: 3)), isNull);
      } finally {
        gate.release.complete();
        await writing;
        await purging;
      }
    },
  );

  for (final other in ['channel', 'server', 'account']) {
    test(
      'a different $other purge does not invalidate this snapshot',
      () async {
        gate.read = true;
        final reading = committed();
        await gate.reached.future;
        final purging = switch (other) {
          'channel' => cache.revokeChannel(
            scope.origin,
            scope.principal,
            scope.server,
            'other',
          ),
          'server' => cache.revokeServer(
            scope.origin,
            scope.principal,
            'other',
          ),
          _ => cache.clearAccount(scope.origin, 'other'),
        };
        gate.release.complete();
        expect((await reading as Map)['messages'], hasLength(50));
        await purging;
      },
    );
  }

  test(
    'closing rejects an in-flight snapshot and waits for its connection',
    () async {
      gate.read = true;
      final reading = committed();
      await gate.reached.future;
      var closed = false;
      final closing = cache.close().then((_) {
        closed = true;
      });
      expect(await committed(), isNull);
      expect(closed, isFalse);
      gate.release.complete();
      expect(await reading, isNull);
      await closing;
      expect(closed, isTrue);
    },
  );

  test(
    'metadata and message bodies come from the same committed transaction',
    () async {
      gate.holdMutation = true;
      final writing = cache.transaction(() async {
        await cache.customStatement(
          "UPDATE workspace_cache SET payload=json_set(payload,'\$.windowSize',75) WHERE kind='message-history'",
        );
        await cache.customStatement(
          "UPDATE raft_history_rows SET payload=json_set(payload,'\$.content','new body')",
        );
      });
      await gate.reached.future;
      try {
        final old =
            await committed().timeout(const Duration(seconds: 3)) as Map;
        expect(old['windowSize'], 50);
        expect(old['messages'], hasLength(50));
        expect((old['messages'] as List).first['content'], 'Accepted 51 中文');
      } finally {
        gate.release.complete();
        await writing;
      }
      final updated = await committed() as Map;
      expect(updated['windowSize'], 75);
      expect(updated['messages'], hasLength(75));
      expect((updated['messages'] as List).first['content'], 'new body');
    },
  );

  test('ordinary reads still wait for their own pending writes', () async {
    gate.draft = true;
    final writing = cache.write(
      scope.origin,
      scope.principal,
      scope.server,
      'draft',
      'hold',
      {'text': 'next'},
    );
    await gate.reached.future;
    var returned = false;
    final reading = cache
        .read(scope.origin, scope.principal, scope.server, 'draft', 'hold')
        .then((value) {
          returned = true;
          return value;
        });
    try {
      expect((await committed() as Map)['messages'], hasLength(50));
      expect(returned, isFalse);
    } finally {
      gate.release.complete();
      await writing;
    }
    expect(await reading, {'text': 'next'});
  });

  test('thread metadata, uint64 ordering and parent revocation keep their semantics', () async {
    final sequences = [
      '1',
      '9007199254740993',
      '9223372036854775809',
      '18446744073709551615',
    ];
    await cache.write(
      scope.origin,
      scope.principal,
      scope.server,
      'thread-window',
      'parent-message',
      {
        ...fixture.legacy('thread'),
        'threadChannelId': 'thread',
        'parentChannelId': scope.channel,
        'parentMessageId': 'parent-message',
        'messages': [
          for (final seq in sequences) fixture.row(seq, channel: 'thread'),
        ],
      },
    );
    Future<dynamic> thread() => cache.readCommittedWindow(
      scope.origin,
      scope.principal,
      scope.server,
      'thread-window',
      'parent-message',
    );
    final saved = await thread() as Map;
    expect((saved['messages'] as List).map((m) => m['seq']), sequences);
    expect(
      saved,
      await cache.read(
        scope.origin,
        scope.principal,
        scope.server,
        'thread-window',
        'parent-message',
      ),
    );
    gate.read = true;
    final reading = thread();
    await gate.reached.future;
    final purging = cache.revokeChannel(
      scope.origin,
      scope.principal,
      scope.server,
      scope.channel,
    );
    gate.release.complete();
    expect(await reading, isNull);
    await purging;
    expect(await thread(), isNull);
  });

  test('known empty and limited tails match ordered reads', () async {
    for (final limited in [false, true]) {
      await cache.messageHistory.acceptPage(
        await fixture.page(cache.messageHistory, scope, [], limited: limited),
      );
      expect(
        await committed(),
        await cache.read(
          scope.origin,
          scope.principal,
          scope.server,
          'window',
          scope.channel,
        ),
      );
      expect((await committed() as Map)['messages'], isEmpty);
    }
  });

  test(
    'context and legacy windows still take the ordered compatibility path',
    () async {
      await cache.customStatement(
        "UPDATE workspace_cache SET payload=json_set(payload,'\$.windowKind','context') WHERE kind='message-history'",
      );
      expect(
        await committed(),
        await cache.read(
          scope.origin,
          scope.principal,
          scope.server,
          'window',
          scope.channel,
        ),
      );
      await cache.customStatement('DELETE FROM workspace_cache WHERE kind=?', [
        'message-history',
      ]);
      await cache.customStatement('DELETE FROM raft_history_rows');
      await cache.customStatement(
        'INSERT INTO workspace_cache VALUES(?,?,?,?,?,?)',
        [
          scope.origin,
          scope.principal,
          scope.server,
          'window',
          'legacy-only',
          jsonEncode(fixture.legacy('legacy-only')),
        ],
      );
      final migrated = await cache.readCommittedWindow(
        scope.origin,
        scope.principal,
        scope.server,
        'window',
        'legacy-only',
      );
      expect((migrated as Map)['messages'], hasLength(1));
      expect((migrated['messages'] as List).single['id'], 'legacy-only-1');
    },
  );
  test(
    'absence proof is transient and belongs to its receiver scope',
    () async {
      final saved = await committed() as CachedHistoryWindow;
      expect(saved.provesNoPosition(scope), isTrue);
      expect(jsonDecode(jsonEncode(saved)), isA<Map>());
      expect(saved.keys, isNot(contains('positionAbsent')));
      for (final other in [
        fixture.scope(principal: 'bob'),
        fixture.scope(server: 'two'),
        fixture.scope(channel: 'other'),
        fixture.scope(parent: 'other'),
        fixture.scope(authority: 'old-role'),
      ]) {
        expect(saved.provesNoPosition(other), isFalse);
      }
    },
  );

  test(
    'an existing reading position never takes the absence shortcut',
    () async {
      await cache.messageHistory.savePosition(
        scope,
        SavedReadingPosition('chat-42', BigInt.from(42), -12.25),
      );
      final saved = await committed() as CachedHistoryWindow;
      expect(saved.provesNoPosition(scope), isFalse);
      final position = await cache.messageHistory.readPosition(scope);
      expect(position!.messageId, 'chat-42');
      expect(position.top, -12.25);
    },
  );

  test(
    'a position queued behind a writer invalidates absence at read start',
    () async {
      gate.draft = true;
      final writing = cache.write(
        scope.origin,
        scope.principal,
        scope.server,
        'draft',
        'hold',
        {},
      );
      await gate.reached.future;
      final saving = cache.messageHistory.savePosition(
        scope,
        SavedReadingPosition('chat-42', BigInt.from(42), -12.25),
      );
      try {
        final saved = await committed().timeout(
          const Duration(seconds: 3),
        ) as CachedHistoryWindow;
        expect(saved.provesNoPosition(scope), isFalse);
        gate.release.complete();
        await Future.wait([writing, saving]);
        expect(saved.provesNoPosition(scope), isFalse);
        expect(
          (await cache.messageHistory.readPosition(scope))!.messageId,
          'chat-42',
        );
      } finally {
        if (!gate.release.isCompleted) gate.release.complete();
        await Future.wait([writing, saving]);
      }
    },
  );

  test(
    'save and clear invalidate a previously returned absence proof',
    () async {
      final saved = await committed() as CachedHistoryWindow;
      final saving = cache.messageHistory.savePosition(
        scope,
        SavedReadingPosition('chat-42', BigInt.from(42), -12.25),
      );
      expect(saved.provesNoPosition(scope), isFalse);
      await saving;
      expect(saved.provesNoPosition(scope), isFalse);
      await cache.messageHistory.savePosition(scope, null);
      expect(saved.provesNoPosition(scope), isFalse);
      final next = await committed() as CachedHistoryWindow;
      expect(next.provesNoPosition(scope), isTrue);
      final clearing = cache.messageHistory.savePosition(scope, null);
      expect(next.provesNoPosition(scope), isFalse);
      await clearing;
      expect(next.provesNoPosition(scope), isFalse);
    },
  );

  test(
    'a save after SQL capture prevents an obsolete absence decision',
    () async {
      gate.read = true;
      final reading = committed();
      await gate.reached.future;
      final saving = cache.messageHistory.savePosition(
        scope,
        SavedReadingPosition('chat-42', BigInt.from(42), -12.25),
      );
      gate.release.complete();
      final saved = await reading as CachedHistoryWindow;
      expect(saved.provesNoPosition(scope), isFalse);
      await saving;
      expect(saved.provesNoPosition(scope), isFalse);
    },
  );

  for (final kind in ['channel', 'server', 'account']) {
    test('$kind purge invalidates an already returned absence proof', () async {
      final saved = await committed() as CachedHistoryWindow;
      final purging = switch (kind) {
        'channel' => cache.revokeChannel(
          scope.origin,
          scope.principal,
          scope.server,
          scope.channel,
        ),
        'server' => cache.revokeServer(
          scope.origin,
          scope.principal,
          scope.server,
        ),
        _ => cache.clearAccount(scope.origin, scope.principal),
      };
      expect(saved.provesNoPosition(scope), isFalse);
      await purging;
      expect(saved.provesNoPosition(scope), isFalse);
    });
  }

  test('close invalidates an already returned absence proof', () async {
    final saved = await committed() as CachedHistoryWindow;
    final closing = cache.close();
    expect(saved.provesNoPosition(scope), isFalse);
    await closing;
  });
}
