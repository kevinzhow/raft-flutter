import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> row(String channel, int seq) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': 'Saved message $seq 中文',
  'senderType': 'user',
  'senderId': 'alice',
};

class HistoryClient extends RaftClient {
  HistoryClient()
    : super(
        origin: 'https://memory.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final arrivals = StreamController<RaftEvent>.broadcast(sync: true);
  bool offline = false;
  int oldReads = 0;
  @override
  Stream<RaftEvent> get events => arrivals.stream;
  @override
  void resume(BigInt seq) {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (offline) {
      if (before != null || after != null) oldReads++;
      throw StateError('Synthetic offline');
    }
    final end = before != null
        ? before.toInt() - 1
        : after != null
        ? (after.toInt() + limit).clamp(0, 1000)
        : 1000;
    final first = after != null
        ? after.toInt() + 1
        : (end - limit + 1).clamp(1, 1001);
    return {
      'messages': [for (var n = first; n <= end; n++) row(id, n)],
      'historyLimited': false,
    };
  }
}

WorkspaceController receiver(HistoryClient client, DriftWorkspaceCache db) {
  final w = WorkspaceController(client, cache: db)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channels = [
      RaftChannel({'id': 'chat', 'type': 'private', 'joined': true}),
    ];
  w.messageDomain.ledger.switchServer('server');
  return w;
}

void main() {
  test('1000 visited rows stay on disk while the live receiver releases old bodies', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory()),
        client = HistoryClient();
    final w = receiver(client, db);
    try {
      await w.selectChannel(w.channels.single, autoRead: false);
      for (var n = 0; n < 19; n++) {
        await w.messageDomain.older();
      }
      await w.flushCache();
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      expect(
        w.messageDomain.ledger.messages('chat').length,
        lessThanOrEqualTo(500),
      );
      expect(w.messageDomain.messages.length, lessThanOrEqualTo(500));
      final saved = await db.messageHistory.readContext(
        MessageHistoryPages.scope(w, 'chat')!,
        'chat-1',
        radius: 0,
      );
      expect(saved!['messages'], hasLength(1));
      expect(
        (saved['messages'] as List).single['content'],
        'Saved message 1 中文',
      );
      client.offline = true;
      expect(w.messageDomain.state.hasNewer, isTrue);
      final last = w.messageDomain.messages.last.seq;
      await w.messageDomain.newer();
      expect(w.messageDomain.messages.last.seq, greaterThan(last));
      await db.messageHistory.memory.maintain();
      expect(w.messageDomain.messages, hasLength(500));
      final first = w.messageDomain.messages.first.seq;
      await w.messageDomain.older();
      expect(w.messageDomain.messages.first.seq, lessThan(first));
      expect(client.oldReads, 0);
    } finally {
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await db.close();
    }
  });
  test(
    'thread history pages both ways offline and returns to its own latest end',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory()),
          client = HistoryClient();
      final w = receiver(client, db);
      try {
        await w.selectChannel(w.channels.single, autoRead: false);
        await w.openThreadIdentity(
          parentChannelId: 'chat',
          parentMessageId: 'chat-1000',
          initialThreadChannelId: 'thread',
          navigate: false,
        );
        for (var n = 0; n < 19; n++) {
          await w.messageDomain.older(thread: true);
        }
        await w.flushCache();
        await db.messageHistory.memory.maintain();
        expect(w.replies.length, lessThanOrEqualTo(500));
        expect(w.messageDomain.threadWindow!.hasNewer, isTrue);
        client.offline = true;
        final last = w.replies.last.seq;
        await w.messageDomain.newer(thread: true);
        expect(w.replies.last.seq, greaterThan(last));
        await db.messageHistory.memory.maintain();
        expect(w.replies.length, lessThanOrEqualTo(500));
        final first = w.replies.first.seq;
        await w.messageDomain.older(thread: true);
        expect(w.replies.first.seq, lessThan(first));
        expect(client.oldReads, 0);
        await w.messageDomain.returnToLatest(thread: true, navigate: false);
        expect(w.messageDomain.threadWindow!.hasNewer, isFalse);
        expect(w.replies.last.seq, BigInt.from(1000));
        expect(w.channel!.id, 'chat');
      } finally {
        await w.flushCache();
        w.dispose();
        await client.arrivals.close();
        await db.close();
      }
    },
  );
}
