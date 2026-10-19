import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/workspace_message_windows.dart';
import 'package:raft_flutter/platform/history_evictions.dart';
import 'package:raft_flutter/platform/message_history.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as capacity;
import 'history_memory_test.dart' show HistoryClient, receiver, row;

void main() {
  test(
    'bad marker records do not block valid account receipt cleanup',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      await cache.messageHistory.revision(capacity.scope('valid'));
      for (final (id, payload) in [
        ('bad-json', '{bad json'),
        ('bad-shape', jsonEncode({'parentChannelId': 42, 'authority': []})),
      ]) {
        await cache.customStatement(
          "INSERT INTO workspace_cache VALUES(?,?,?,'message-history',?,?)",
          [capacity.account.origin, 'alice', 'one', id, payload],
        );
      }
      await capacity.store(
        cache,
        capacity.scope('valid'),
        capacity.rows('valid', 1, 1000, bytes: 1),
      );
      await cache.customStatement(
        "UPDATE raft_history_rows SET tombstone=2,payload='{}',byte_size=0",
      );
      await cache.messageHistory.capacity.maintain(capacity.account);
      expect(
        await capacity.count(cache, 'SELECT count(*) FROM raft_history_rows'),
        256,
      );
      final progress = await cache.read(
        capacity.account.origin,
        'alice',
        '',
        'history-receipt-cleanup',
        '',
      );
      expect(progress['complete'], isTrue);
      expect(progress['skippedMarkers'], 2);
    },
  );

  test(
    'completed receipt cleanup does not rescan old markers after reopening',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      for (final id in ['one', 'two', 'three']) {
        await cache.messageHistory.revision(capacity.scope(id));
      }
      var orderedJobs = 0;
      Future<T> order<T>(Future<T> Function() action) {
        orderedJobs++;
        return action();
      }

      await HistoryEvictions(cache)
          .cleanAccount(capacity.account, order, () => true);
      expect(orderedJobs, greaterThan(1));
      orderedJobs = 0;
      await HistoryEvictions(cache)
          .cleanAccount(capacity.account, order, () => true);
      expect(orderedJobs, 1);
      await cache.clearAccount(capacity.account.origin, 'alice');
      expect(
        await cache.read(
          capacity.account.origin,
          'alice',
          '',
          'history-receipt-cleanup',
          '',
        ),
        isNull,
      );
    },
  );

  test(
    'rollback refresh updates 500 bodies without reading their blob into Dart',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final scope = capacity.scope('chat');
      final rows = capacity.rows('chat', 1, 500, bytes: 100);
      await cache.write(
        scope.origin,
        scope.principal,
        scope.server,
        'window',
        'chat',
        {
          'version': 1,
          'windowKind': 'tail',
          'authority': scope.authority,
          'parentChannelId': 'chat',
          'messages': rows,
        },
      );
      await cache.messageHistory.acceptEvents(scope, [
        {...rows.last, 'content': 'newest canonical body'},
      ]);
      // Restore a stale copy without invoking the cache/import wrapper.
      await cache.customStatement(
        "UPDATE workspace_cache SET payload=json_set(payload,'\$.messages[499].content','stale') WHERE kind='window' AND id='chat'",
      );
      var blobReads = 0;
      final observed = SqliteMessageHistory(
        cache,
        <T>(Future<T> Function() action) => action(),
        readLegacy: (o, p, s, kind, id) async {
          if (kind == 'window' || kind == 'thread-window') blobReads++;
          return cache.read(o, p, s, kind, id);
        },
        writeLegacy: cache.write,
        automaticMaintenance: false,
      );
      addTearDown(observed.stop);
      await observed.acceptEvents(scope, [
        {...rows.last, 'content': 'newest canonical body'},
      ]);
      final saved = await cache.read(
        scope.origin,
        scope.principal,
        scope.server,
        'window',
        'chat',
      );
      expect(saved['messages'], hasLength(500));
      expect(saved['messages'].last['content'], 'newest canonical body');
      expect(blobReads, 0);
    },
  );

  test(
    'a failed rollback-copy update also rolls back the canonical edit',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final scope = capacity.scope('chat');
      await cache.write(
        scope.origin,
        scope.principal,
        scope.server,
        'window',
        'chat',
        {
          'version': 1,
          'windowKind': 'tail',
          'authority': scope.authority,
          'parentChannelId': 'chat',
          'messages': [row('chat', 1)],
        },
      );
      await cache.customStatement(
        "CREATE TEMP TRIGGER deny_shadow BEFORE UPDATE OF payload ON workspace_cache WHEN NEW.kind='window' BEGIN SELECT RAISE(ABORT,'injected shadow failure'); END",
      );
      await expectLater(
        cache.messageHistory.acceptEvents(scope, [
          {...row('chat', 1), 'content': 'must roll back'},
        ]),
        throwsA(isA<Exception>()),
      );
      final saved = await cache.messageHistory.readContext(
        scope,
        'chat-1',
        radius: 0,
      );
      expect(
        (saved!['messages'] as List).single['content'],
        'Saved message 1 中文',
      );
      expect(
        await capacity.count(
          cache,
          'SELECT count(*) FROM raft_history_compat_write',
        ),
        0,
      );
    },
  );

  test(
    'a thread rollback copy preserves uint64 keys and drops tombstones',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      const scope = MessageHistoryScope(
        origin: 'https://history.invalid',
        principal: 'alice',
        server: 'one',
        channel: 'thread',
        parentChannel: 'chat',
        parentMessage: 'chat-1',
        authority: 'member',
      );
      final rows = [
        for (final seq in ['9007199254740993', '18446744073709551615'])
          {
            'id': 'thread-$seq',
            'channelId': 'thread',
            'seq': seq,
            'content': 'old',
          },
      ];
      await cache.write(
        scope.origin,
        scope.principal,
        scope.server,
        'thread-window',
        'chat-1',
        {
          'version': 1,
          'windowKind': 'tail',
          'authority': scope.authority,
          'parentChannelId': 'chat',
          'threadChannelId': 'thread',
          'messages': rows,
        },
      );
      await cache.messageHistory.acceptPage(
        MessageHistoryPage(
          {
            'messages': [
              {...rows.last, 'content': 'maximum uint64'},
            ],
          },
          scope: scope,
          revision: await cache.messageHistory.revision(scope),
          before: null,
          after: null,
          local: false,
        ),
      );
      final saved = await cache.read(
        scope.origin,
        scope.principal,
        scope.server,
        'thread-window',
        'chat-1',
      );
      expect(saved['messages'], [
        {...rows.last, 'content': 'maximum uint64'},
      ]);
    },
  );

  for (final laterLiveEdit in [false, true]) {
    test(
      'a retired context page preserves held rows and later live edits: $laterLiveEdit',
      () async {
        final cache = DriftWorkspaceCache(
          NativeDatabase.memory(),
          automaticHistoryMaintenance: false,
        );
        final client = HistoryClient(), w = receiver(client, cache);
        try {
          cache.messageHistory.memory.unregister(w);
          await w.selectChannel(w.channels.single, autoRead: false);
          await w.flushCache();
          final scope = MessageHistoryPages.scope(w, 'chat')!;
          final held = w.messageDomain.ledger.message('chat', 'chat-1000');
          final page = await MessageHistoryPages.load(
            cache: cache,
            scope: scope,
            current: () => true,
            held: () => w.messageDomain.ledger.messages('chat'),
            localFirst: false,
            focused: true,
            target: 'chat-1000',
            remote: () async => {
              'messages': [
                for (var n = 980; n <= 1020; n++)
                  {...row('chat', n), 'content': 'unproven response $n'},
              ],
            },
          );
          // Production context callers publish the page before recording it.
          w.messageWindows.acceptRows(
            liveWindowWrite,
            'chat',
            (page['messages'] as List).cast<Map<String, dynamic>>(),
            replace: true,
          );
          expect(
            w.messageDomain.ledger.message('chat', 'chat-1000')!['content'],
            'unproven response 1000',
          );
          await cache.customStatement(
            "UPDATE workspace_cache SET payload=json_set(payload,'\$.evictionRevision',99999) WHERE kind='message-history' AND id='chat'",
          );
          final recording = MessageHistoryPages.record(
            w,
            liveWindowWrite,
            page,
          );
          if (laterLiveEdit) {
            w.messageWindows.acceptRows(liveWindowWrite, 'chat', [
              {...row('chat', 1020), 'content': 'later live edit'},
            ]);
          }
          expect(await recording, isFalse);
          expect(w.messageDomain.ledger.message('chat', 'chat-1000'), held);
          expect(w.messageDomain.visibleIds['chat'], contains('chat-1000'));
          if (laterLiveEdit) {
            expect(
              w.messageDomain.ledger.message('chat', 'chat-1020')!['content'],
              'later live edit',
            );
            expect(w.messageDomain.visibleIds['chat'], contains('chat-1020'));
          } else {
            expect(w.messageDomain.ledger.message('chat', 'chat-1020'), isNull);
            expect(
              w.messageDomain.visibleIds['chat'],
              isNot(contains('chat-1020')),
            );
          }
        } finally {
          await w.flushCache();
          w.dispose();
          await client.arrivals.close();
          await cache.close();
        }
      },
    );
  }
}
