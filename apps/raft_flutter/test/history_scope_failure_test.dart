import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/local_error_diagnostics.dart';
import 'package:raft_flutter/data/message_history_events.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;

class _ParentClient extends HistoryClient {
  RaftApiException? failure;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/unvisited-thread') {
      return {
        'id': 'unvisited-thread',
        'type': 'thread',
        'parentMessageId': 'chat-1000',
      };
    }
    if (path == '/messages/context/chat-1000') {
      if (failure case final error?) throw error;
      return {'channelId': 'chat'};
    }
    return super.get(path, query: query);
  }
}

void main() {
  for (final status in [null, 401, 403, 404, 429, 503]) {
    test(
      'replay parent lookup $status is not a device write failure',
      () async {
        final cache = DriftWorkspaceCache(NativeDatabase.memory());
        final client = _ParentClient()
          ..failure = RaftApiException(
            'private-message https://private.invalid?token=private-token',
            status: status,
          );
        final w = receiver(client, cache);
        try {
          await w.selectChannel(w.channels.single, autoRead: false);
          await MessageHistoryEvents.resumeResponse(w, {
            'messages': [row('unvisited-thread', 1001)],
            'currentSeq': '1002',
          }, refreshUnread: () {});
          expect(w.error, isNull);
          final log = LocalErrorDiagnostics.shared;
          final sample = log.samples.last.fields;
          expect(sample['code'], 'message-history.syncFailed');
          expect(sample['operation'], 'resumeReplay');
          expect(sample['httpStatus'], status);
          expect(sample.containsKey('sqliteResultCode'), isFalse);
          final exported = log.export(sample: log.samples.last);
          for (final private in [
            'private-message',
            'private.invalid',
            'private-token',
          ]) {
            expect(exported, isNot(contains(private)));
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

  test('empty replay cannot skip a parent lookup failure; authorized replay repairs it', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory());
    final client = _ParentClient()
      ..failure = const RaftApiException('Unavailable', status: 503);
    final w = receiver(client, cache);
    try {
      await w.selectChannel(w.channels.single, autoRead: false);
      final scope = MessageHistoryPages.scope(w, 'chat')!;
      final store = cache.messageHistory;
      expect(await store.resumeSequence(scope), BigInt.from(1000));
      await MessageHistoryEvents.resumeResponse(w, {
        'messages': [row('unvisited-thread', 1001)],
        'currentSeq': '1002',
      }, refreshUnread: () {});
      await MessageHistoryEvents.resumeResponse(w, {
        'messages': <dynamic>[],
        'currentSeq': '1002',
      }, refreshUnread: () {});
      expect(await store.resumeSequence(scope), BigInt.from(1000));
      expect(store.receiver.hasPending(scope), isTrue);
      client.failure = null;
      await MessageHistoryEvents.resumeResponse(w, {
        'messages': [row('unvisited-thread', 1001)],
        'currentSeq': '1002',
      }, refreshUnread: () {});
      final thread = await store.knownScope(
        client.origin,
        'alice',
        'server',
        'unvisited-thread',
      );
      expect(thread, isNotNull);
      final saved = await store.readContext(
        thread!,
        'unvisited-thread-1001',
        radius: 0,
      );
      expect(
        (saved!['messages'] as List).single['content'],
        'Saved message 1001 中文',
      );
      expect(await store.resumeSequence(scope), BigInt.from(1002));
      expect(store.receiver.hasPending(scope), isFalse);
      expect(w.error, isNull);
    } finally {
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await cache.close();
    }
  });

  test('a replay SQLite write failure keeps the storage notice and safe diagnostics', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory());
    final client = _ParentClient();
    final w = receiver(client, cache);
    try {
      await w.selectChannel(w.channels.single, autoRead: false);
      await cache.customStatement(
        "CREATE TEMP TRIGGER deny_replay BEFORE INSERT ON raft_history_rows BEGIN SELECT RAISE(ABORT,'private-sql'); END",
      );
      await MessageHistoryEvents.resumeResponse(w, {
        'messages': [row('chat', 1001)],
        'currentSeq': '1002',
      }, refreshUnread: () {});
      expect(w.error, LocalErrorNotice.saveFailed.message);
      final sample = LocalErrorDiagnostics.shared.samples.last.fields;
      expect(sample['code'], 'local-storage.saveFailed');
      expect(sample['sqliteResultCode'], isA<int>());
      expect(sample.containsKey('httpStatus'), isFalse);
      expect(jsonEncode(sample), isNot(contains('private-sql')));
      expect(
        await cache.messageHistory.resumeSequence(
          MessageHistoryPages.scope(w, 'chat')!,
        ),
        BigInt.from(1000),
      );
      await cache.customStatement('DROP TRIGGER deny_replay');
    } finally {
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await cache.close();
    }
  });
}
