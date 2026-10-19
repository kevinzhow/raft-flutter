import 'dart:convert';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fake_async/fake_async.dart';
import 'package:raft_flutter/data/history_snapshot_writes.dart';
import 'package:raft_flutter/data/message_history.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history_events.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/message_history_verification.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;
import 'message_history_store_test.dart' as fixture;

class FullPageClient extends HistoryClient {
  bool withAttachment = true;
  Completer<void>? pageStarted, releasePage;
  Map<String, dynamic>? serverTask;
  @override
  Future<dynamic> post(String path, {dynamic data}) async =>
      path == '/feature-flags/evaluate'
      ? {
          'evaluations': [
            {'key': 'sync_core_messages_v0', 'enabled': true},
          ],
        }
      : super.post(path, data: data);
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    final page = await super.messagePage(
      id,
      limit: limit,
      before: before,
      after: after,
    );
    final response = {
      ...page,
      'messages': [
        for (final row in page['messages'] as List)
          {
            ...row as Map,
            if (serverTask != null && row['id'] == 'chat-1000')
              'task': serverTask,
            if (withAttachment)
              'attachments': [
                {'id': 'removed'},
              ],
          },
      ],
    };
    if (pageStarted?.isCompleted == false) pageStarted!.complete();
    await releasePage?.future;
    return response;
  }
}

void main() {
  test(
    'legacy migration rolls back its cursor on a database failure',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory());
      addTearDown(cache.close);
      final scope = fixture.scope(), store = cache.messageHistory;
      await store.revision(scope);
      await cache.customStatement(
        'INSERT INTO workspace_cache(origin,principal,server,kind,id,payload) VALUES(?,?,?,?,?,?)',
        [
          scope.origin,
          scope.principal,
          scope.server,
          'window',
          'valid',
          jsonEncode(fixture.legacy('valid')),
        ],
      );
      await cache.customStatement(
        "CREATE TEMP TRIGGER deny_import BEFORE INSERT ON raft_history_rows BEGIN SELECT RAISE(ABORT,'injected database failure'); END",
      );
      await expectLater(
        store.migrateLegacy(scope, limit: 1),
        throwsA(isA<Exception>()),
      );
      expect(
        await cache.read(
          scope.origin,
          scope.principal,
          '',
          'message-history-migration',
          '',
        ),
        isNull,
      );
      await cache.customStatement('DROP TRIGGER deny_import');
      expect(await store.migrateLegacy(scope, limit: 1), 1);
      expect(
        (await store.readContext(
          fixture.scope(channel: 'valid'),
          'valid-1',
          radius: 0,
        ))!['messages'],
        hasLength(1),
      );
    },
  );

  test('unknown-scope checkpoint holds require matching resolution or explicit revocation', () {
    final queue = HistoryReceiverQueue(), scope = fixture.scope();
    final rows = [row('one', 1001), row('two', 1002)];
    queue.begin(scope, rows)!.finish(false, unresolved: true);
    queue.confirmReplay(scope, BigInt.from(1005));
    expect(queue.checkpointLimit(scope, BigInt.from(1005)), BigInt.from(1000));
    queue.begin(scope, [rows.first])!.finish(true, resolved: true);
    expect(queue.hasPending(scope), isTrue);
    queue.revokeScopes(scope.origin, scope.principal, scope.server, {'two'});
    expect(queue.hasPending(scope), isFalse);
    queue.begin(scope, rows)!.finish(false, unresolved: true);
    queue.clearServer(scope.origin, scope.principal, scope.server);
    expect(queue.hasPending(scope), isFalse);
    queue.begin(scope, rows)!.finish(false, unresolved: true);
    queue.clearAccount(scope.origin, scope.principal);
    expect(queue.hasPending(scope), isFalse);
    queue.close();
  });

  test('continuous edits cannot postpone the first batch deadline', () {
    fakeAsync((clock) {
      final queue = HistoryReceiverQueue(),
          scope = fixture.scope(),
          owner = Object();
      final written = <int>[];
      for (var n = 0; n < 3; n++) {
        queue.coalesceUpdate(
          owner,
          scope,
          'same',
          {'n': n},
          () async => 1,
          (row, _) async => written.add(row['n'] as int),
        );
        clock.elapse(const Duration(milliseconds: 20));
      }
      clock.flushMicrotasks();
      expect(written, [2]);
      expect(clock.pendingTimers, isEmpty);
      queue.close();
    });
  });

  test('a full refresh during a queued partial edit clears removed fields and keeps the edit', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory()),
        client = FullPageClient();
    final w = receiver(client, cache);
    try {
      await w.selectChannel(w.channels.single, autoRead: false);
      await w.flushCache();
      client.withAttachment = false;
      client.pageStarted = Completer<void>();
      client.releasePage = Completer<void>();
      final refreshing = MessageHistoryVerification.refresh(w);
      await client.pageStarted!.future;
      client.arrivals.add(
        RaftEvent('message:updated', {
          'id': 'chat-1000',
          'channelId': 'chat',
          'task': {'status': 'done'},
        }),
      );
      client.serverTask = {'status': 'done'};
      client.releasePage!.complete();
      expect(await refreshing, isTrue);
      await w.flushCache();
      expect(
        w.messageDomain.ledger
            .message('chat', 'chat-1000')!
            .containsKey('attachments'),
        isFalse,
      );
      expect(w.messageDomain.ledger.message('chat', 'chat-1000')!['task'], {
        'status': 'done',
      });
      final rows = (await rawShadow(cache))['messages'] as List;
      expect((rows.last as Map).containsKey('attachments'), isFalse);
      expect(rows.last['task'], {'status': 'done'});
    } finally {
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await cache.close();
    }
  });

  test('full refresh removes old fields from the visible ledger and legacy sync body', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory()),
        client = FullPageClient();
    final w = receiver(client, cache);
    try {
      await w.selectChannel(w.channels.single, autoRead: false);
      final incoming = {
        ...row('chat', 1000),
        'attachments': [
          {'id': 'removed'},
        ],
      };
      // Retained legacy bodies still need authoritative cleanup, but current
      // socket admission no longer populates or consults the retired core.
      w.messageSync.consumeNew(incoming);
      client.arrivals.add(RaftEvent('message:new', incoming));
      await cache.messageHistory.receiver.settled;
      expect(
        w.messageDomain.ledger.message('chat', 'chat-1000')!['attachments'],
        isNotEmpty,
      );
      expect(w.messageSync.messages('chat'), hasLength(1));
      client.withAttachment = false;
      expect(await MessageHistoryVerification.refresh(w), isTrue);
      expect(
        w.messageDomain.ledger
            .message('chat', 'chat-1000')!
            .containsKey('attachments'),
        isFalse,
      );
      expect(
        w.messageSync.messages('chat').single.containsKey('attachments'),
        isFalse,
      );
    } finally {
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await cache.close();
    }
  });

  test('an authoritative page removes omitted fields from stored bodies and rollback shadows', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory());
    addTearDown(cache.close);
    final scope = fixture.scope(), store = cache.messageHistory;
    final old = {
      ...fixture.row(1),
      'attachments': [
        {'id': 'gone'},
      ],
      'toolCalls': [
        {'id': 'gone-tool'},
      ],
    };
    await cache.write(
      scope.origin,
      scope.principal,
      scope.server,
      'window',
      scope.channel,
      {
        ...fixture.legacy(scope.channel),
        'messages': [old],
      },
    );
    await store.acceptPage(
      await fixture.page(store, scope, [fixture.row(1, content: 'fresh')]),
    );
    final fresh =
        (await store.readContext(scope, 'chat-1', radius: 0))!['messages']
            as List;
    expect((fresh.single as Map).containsKey('attachments'), isFalse);
    expect((fresh.single as Map).containsKey('toolCalls'), isFalse);
    final shadow = jsonDecode(
      (await cache
              .customSelect(
                "SELECT payload FROM workspace_cache WHERE kind='window' AND id='chat'",
              )
              .getSingle())
          .read<String>('payload'),
    );
    expect(
      (shadow['messages'].single as Map).containsKey('attachments'),
      isFalse,
    );
    await store.acceptEvents(scope, [
      {
        'id': 'chat-1',
        'channelId': 'chat',
        'task': {'status': 'done'},
      },
    ], updateOnly: true);
    final updated =
        (await store.readContext(scope, 'chat-1', radius: 0))!['messages']
            as List;
    expect(updated.single['content'], 'fresh');
    expect(updated.single['task'], {'status': 'done'});
  });

  test('a corrupt legacy record does not pin the migration cursor before valid windows', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory());
    addTearDown(cache.close);
    final scope = fixture.scope();
    // Raw legacy input is intentional: an older app or a damaged file can leave it.
    for (final (id, payload) in [
      ('broken', '{bad json'),
      ('valid', jsonEncode(fixture.legacy('valid'))),
    ]) {
      await cache.customStatement(
        'INSERT INTO workspace_cache(origin,principal,server,kind,id,payload) VALUES(?,?,?,?,?,?)',
        [scope.origin, scope.principal, scope.server, 'window', id, payload],
      );
    }
    final store = cache.messageHistory;
    expect(await store.migrateLegacy(scope, limit: 1), 1);
    expect(await store.migrateLegacy(scope, limit: 1), 1);
    expect(await store.migrateLegacy(scope, limit: 1), 0);
    final valid = await store.readContext(
      fixture.scope(channel: 'valid'),
      'valid-1',
      radius: 0,
    );
    expect(valid!['messages'], hasLength(1));
    await expectLater(
      cache.read(
        scope.origin,
        scope.principal,
        scope.server,
        'window',
        'broken',
      ),
      throwsFormatException,
    );
  });

  test('an empty replay cannot skip an unresolved thread event', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory()),
        client = HistoryClient();
    final w = receiver(client, cache);
    try {
      await w.selectChannel(w.channels.single, autoRead: false);
      final scope = MessageHistoryPages.scope(w, 'chat')!,
          store = cache.messageHistory;
      expect(await store.resumeSequence(scope), BigInt.from(1000));
      final unresolved = row('unknown-thread', 1001);
      MessageHistoryEvents.store(w, unresolved);
      await store.receiver.settled;
      await MessageHistoryEvents.resumeResponse(w, {
        'messages': <dynamic>[],
        'currentSeq': '1002',
      }, refreshUnread: () {});
      expect(await store.resumeSequence(scope), BigInt.from(1000));
      await MessageHistoryEvents.resumeResponse(w, {
        'messages': [
          {
            ...unresolved,
            'conversationContext': {
              'channelType': 'thread',
              'parentChannelId': 'chat',
              'parentMessageId': 'chat-1000',
            },
          },
        ],
        'currentSeq': '1002',
      }, refreshUnread: () {});
      expect(await store.resumeSequence(scope), BigInt.from(1002));
      final savedScope = await store.knownScope(
        client.origin,
        'alice',
        'server',
        'unknown-thread',
      );
      expect(
        (await store.readContext(
          savedScope!,
          'unknown-thread-1001',
          radius: 0,
        ))!['messages'],
        hasLength(1),
      );
    } finally {
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await cache.close();
    }
  });

  test(
    'a burst of partial edits persists the final fields in one bounded batch',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory()),
          client = HistoryClient();
      final w = receiver(client, cache);
      try {
        await w.selectChannel(w.channels.single, autoRead: false);
        final scope = MessageHistoryPages.scope(w, 'chat')!,
            store = cache.messageHistory;
        await w.flushCache();
        await cache.customStatement(
          'CREATE TEMP TABLE shadow_writes(n INTEGER)',
        );
        await cache.customStatement('INSERT INTO shadow_writes VALUES(0)');
        await cache.customStatement(
          "CREATE TEMP TRIGGER shadow_write_probe AFTER INSERT ON workspace_cache WHEN NEW.kind='window' AND NEW.id='chat' BEGIN UPDATE shadow_writes SET n=n+1; END",
        );
        await cache.customStatement(
          "CREATE TEMP TRIGGER shadow_update_probe AFTER UPDATE OF payload ON workspace_cache WHEN NEW.kind='window' AND NEW.id='chat' BEGIN UPDATE shadow_writes SET n=n+1; END",
        );
        await cache.customStatement('CREATE TEMP TABLE body_writes(n INTEGER)');
        await cache.customStatement('INSERT INTO body_writes VALUES(0)');
        await cache.customStatement(
          'CREATE TEMP TRIGGER body_write_probe AFTER UPDATE ON raft_history_rows BEGIN UPDATE body_writes SET n=n+1; END',
        );
        for (var n = 0; n < 100; n++) {
          client.arrivals.add(
            RaftEvent('message:updated', {
              'id': 'chat-1000',
              'channelId': 'chat',
              'content': 'stream $n',
              if (n == 5) 'task': {'status': 'done'},
            }),
          );
        }
        await store.receiver.settled;
        await w.flushCache();
        final shadow = await rawShadow(cache);
        expect((shadow['messages'] as List).last['content'], 'stream 99');
        expect(
          (await cache.customSelect('SELECT n FROM shadow_writes').getSingle())
              .read<int>('n'),
          lessThanOrEqualTo(2),
        );
        final saved =
            (await store.readContext(
                  scope,
                  'chat-1000',
                  radius: 0,
                ))!['messages']
                as List;
        expect(saved.single['content'], 'stream 99');
        expect(saved.single['task'], {'status': 'done'});
        expect(
          w.messageDomain.ledger.message('chat', 'chat-1000')!['content'],
          'stream 99',
        );
        expect(
          (await cache.customSelect('SELECT n FROM body_writes').getSingle())
              .read<int>('n'),
          1,
        );
      } finally {
        await w.flushCache();
        w.dispose();
        await client.arrivals.close();
        await cache.close();
      }
    },
  );

  test(
    'a new message separates edit batches and cannot be lost from the shadow',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory()),
          client = HistoryClient();
      final w = receiver(client, cache);
      try {
        await w.selectChannel(w.channels.single, autoRead: false);
        await w.flushCache();
        await cache.customStatement('CREATE TEMP TABLE edits(n INTEGER)');
        await cache.customStatement('INSERT INTO edits VALUES(0)');
        await cache.customStatement(
          "CREATE TEMP TRIGGER edits_probe AFTER UPDATE ON raft_history_rows WHEN NEW.message_id='chat-1000' BEGIN UPDATE edits SET n=n+1; END",
        );
        client.arrivals.add(
          RaftEvent('message:updated', {
            'id': 'chat-1000',
            'channelId': 'chat',
            'content': 'prefix',
            'task': {'status': 'done'},
          }),
        );
        client.arrivals.add(RaftEvent('message:new', row('chat', 1001)));
        client.arrivals.add(
          RaftEvent('message:updated', {
            'id': 'chat-1000',
            'channelId': 'chat',
            'content': 'suffix',
          }),
        );
        await w.flushCache();
        final store = cache.messageHistory,
            scope = MessageHistoryPages.scope(w, 'chat')!;
        final saved =
            (await store.readContext(
                  scope,
                  'chat-1000',
                  radius: 0,
                ))!['messages']
                as List;
        expect(saved.single['content'], 'suffix');
        expect(saved.single['task'], {'status': 'done'});
        expect(
          (await store.readContext(scope, 'chat-1001', radius: 0))!['messages'],
          hasLength(1),
        );
        expect(
          (await cache.customSelect('SELECT n FROM edits').getSingle())
              .read<int>('n'),
          2,
        );
        final shadow = await rawShadow(cache),
            rows = shadow['messages'] as List;
        expect(rows.last['id'], 'chat-1001');
        expect(
          rows.where((r) => r['id'] == 'chat-1000').single['content'],
          'suffix',
        );
      } finally {
        await w.flushCache();
        w.dispose();
        await client.arrivals.close();
        await cache.close();
      }
    },
  );

  for (final boundary in ['role', 'channel', 'server', 'logout']) {
    test(
      'a queued edit and snapshot cannot survive the $boundary boundary',
      () async {
        final cache = DriftWorkspaceCache(NativeDatabase.memory()),
            client = HistoryClient();
        final w = receiver(client, cache);
        try {
          await w.selectChannel(w.channels.single, autoRead: false);
          await w.flushCache();
          final scope = MessageHistoryPages.scope(w, 'chat')!;
          client.arrivals.add(
            RaftEvent('message:updated', {
              'id': 'chat-1000',
              'channelId': 'chat',
              'content': 'must retire',
            }),
          );
          if (boundary == 'role') {
            for (final role in ['guest', 'owner']) {
              w.applyMembershipRole({
                'userId': 'alice',
                'serverId': 'server',
                'role': role,
              });
            }
          } else if (boundary == 'channel') {
            w.messageDomain.rejectHistoryRead('chat');
          } else if (boundary == 'server') {
            w.revokeServer('server');
          } else {
            await w.retireCache();
            await cache.clearAccount(client.origin, 'alice');
          }
          await w.flushCache();
          final stored = await cache.messageHistory.readContext(
            scope,
            'chat-1000',
            radius: 0,
          );
          if (boundary == 'role') {
            if (stored != null) {
              expect(
                (stored['messages'] as List).single['content'],
                isNot('must retire'),
              );
            }
          } else {
            expect(stored, isNull);
          }
          final values = await cache
              .customSelect('SELECT payload FROM workspace_cache')
              .get();
          expect(
            values.any(
              (v) => v.read<String>('payload').contains('must retire'),
            ),
            isFalse,
          );
        } finally {
          await w.flushCache();
          w.dispose();
          await client.arrivals.close();
          await cache.close();
        }
      },
    );
  }

  test(
    'retiring delayed jobs cancels both timers without advancing the clock',
    () {
      fakeAsync((clock) {
        final queue = HistoryReceiverQueue(),
            owner = Object(),
            scope = fixture.scope();
        var writes = 0;
        queue.coalesceUpdate(
          owner,
          scope,
          'row',
          {'id': 'chat-1'},
          () async => 1,
          (_, _) async => writes++,
        );
        HistorySnapshotWrites.attach(owner);
        HistorySnapshotWrites.schedule(owner, 'snapshot', () async => writes++);
        expect(clock.pendingTimers, hasLength(2));
        queue.cancelUpdates(owner);
        HistorySnapshotWrites.cancel(owner);
        clock.flushMicrotasks();
        expect(clock.pendingTimers, isEmpty);
        expect(writes, 0);
        queue.close();
      });
    },
  );

  testWidgets(
    'disposing the receiver cancels pending edit and snapshot timers',
    (tester) async {
      await tester.runAsync(() async {
        final cache = DriftWorkspaceCache(NativeDatabase.memory()),
            client = HistoryClient();
        final w = receiver(client, cache);
        await w.selectChannel(w.channels.single, autoRead: false);
        await w.flushCache();
        client.arrivals.add(
          RaftEvent('message:updated', {
            'id': 'chat-1000',
            'channelId': 'chat',
            'content': 'disposed edit',
          }),
        );
        w.dispose();
        await cache.messageHistory.receiver.settled;
        await client.arrivals.close();
        await cache.close();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}

Future<Map<String, dynamic>> rawShadow(DriftWorkspaceCache cache) async {
  final row = await cache
      .customSelect(
        "SELECT payload FROM workspace_cache WHERE kind='window' AND id='chat'",
      )
      .getSingle();
  return Map<String, dynamic>.from(
    jsonDecode(row.read<String>('payload')) as Map,
  );
}
