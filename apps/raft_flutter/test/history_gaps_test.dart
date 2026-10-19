import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_read_policy.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;

class GapClient extends HistoryClient {
  final beforeReads = <BigInt>[];
  final beforeArrived = Completer<void>();
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (before != null) {
      beforeReads.add(before);
      if (!beforeArrived.isCompleted) beforeArrived.complete();
      await gate?.future;
    }
    final end = before == null ? 950 : before.toInt() - 1;
    return {
      'messages': [for (var n = end - 49; n <= end; n++) row(id, n)],
      'historyLimited': false,
    };
  }
}

Future<void> seedGap(
  DriftWorkspaceCache cache,
  MessageHistoryScope scope,
) async {
  final store = cache.messageHistory;
  // A short older page proves exhaustion below this old saved island.
  await store.acceptPage(
    MessageHistoryPage(
      {
        'messages': [for (var n = 1; n <= 100; n++) row(scope.channel, n)],
      },
      scope: scope,
      revision: await store.revision(scope),
      before: BigInt.from(101),
      after: null,
      limit: 101,
      local: false,
    ),
  );
}

void main() {
  test('a retired gap response cannot publish rows or its coverage', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory());
    final client = GapClient(), w = receiver(client, cache);
    final scope = MessageHistoryPages.scope(w, 'chat')!;
    try {
      await seedGap(cache, scope);
      await w.selectChannel(w.channels.single, autoRead: false);
      await w.messageDomain.older();
      final gate = client.gate = Completer<void>();
      final pending = w.messageDomain.loadHistoryGap(BigInt.from(901));
      await client.beforeArrived.future;
      final other = RaftChannel({
        'id': 'other',
        'type': 'private',
        'joined': true,
      });
      w.channels = [...w.channels, other];
      await w.selectChannel(other, autoRead: false);
      gate.complete();
      await pending;
      expect(w.channel!.id, 'other');
      expect(
        w.messageDomain.messages.every((row) => row.channelId == 'other'),
        isTrue,
      );
      expect(
        await cache.messageHistory.readContext(scope, 'chat-851', radius: 0),
        isNull,
      );
      final gaps = await cache.messageHistory.gaps.read(scope, [
        ('chat-100', BigInt.from(100)),
        ('chat-901', BigInt.from(901)),
      ]);
      expect(gaps.single.before, BigInt.from(901));
    } finally {
      if (client.gate case final gate? when !gate.isCompleted) gate.complete();
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await cache.close();
    }
  });

  test(
    'sparse sequence values inside one proved page are not a cache gap',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory());
      addTearDown(cache.close);
      final client = GapClient(), w = receiver(client, cache);
      addTearDown(() async {
        await w.flushCache();
        w.dispose();
        await client.arrivals.close();
      });
      final scope = MessageHistoryPages.scope(w, 'chat')!;
      final store = cache.messageHistory;
      await store.acceptPage(
        MessageHistoryPage(
          {
            'messages': [
              for (final n in [10, 20, 30]) row('chat', n),
            ],
          },
          scope: scope,
          revision: await store.revision(scope),
          before: null,
          after: null,
          local: false,
        ),
      );
      expect(
        await store.gaps.read(scope, [
          for (final n in [10, 20, 30]) ('chat-$n', BigInt.from(n)),
        ]),
        isEmpty,
      );
      final version = store.gaps.revision(scope);
      await store.acceptEvents(scope, [
        {...row('chat', 20), 'content': 'edited'},
      ]);
      expect(store.gaps.revision(scope), version);
      expect(client.beforeReads, isEmpty);
    },
  );

  test('an exhausted oldest boundary does not block an interior gap, and duplicate loads coalesce', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory());
    final client = GapClient(), w = receiver(client, cache);
    try {
      cache.messageHistory.memory.unregister(w);
      final scope = MessageHistoryPages.scope(w, 'chat')!;
      await seedGap(cache, scope);
      await w.selectChannel(w.channels.single, autoRead: false);
      await w.messageDomain.older();
      expect(w.messageDomain.messages.first.seq, BigInt.one);
      expect(w.messageDomain.messages.last.seq, BigInt.from(950));
      expect(w.messageDomain.state.hasMore, isFalse);
      final gaps = await cache.messageHistory.gaps.read(scope, [
        for (final row in w.messageDomain.messages) (row.id, row.seq),
      ]);
      expect(gaps, hasLength(1));
      expect(gaps.single.before, BigInt.from(901));
      expect(client.beforeReads, isEmpty);
      final gate = client.gate = Completer<void>();
      final pending = w.messageDomain.loadHistoryGap(gaps.single.before);
      await client.beforeArrived.future;
      expect(w.messageDomain.state.loadingOlder, isTrue);
      await w.messageDomain.loadHistoryGap(gaps.single.before);
      expect(client.beforeReads, [BigInt.from(901)]);
      gate.complete();
      await pending;
      expect(w.messageDomain.state.hasMore, isFalse);
      expect(w.messageDomain.messages.first.seq, BigInt.one);
      expect(
        w.messageDomain.messages.map((row) => row.seq),
        contains(BigInt.from(851)),
      );
      final remaining = await cache.messageHistory.gaps.read(scope, [
        for (final row in w.messageDomain.messages) (row.id, row.seq),
      ]);
      expect(remaining, hasLength(1));
      expect(remaining.single.before, BigInt.from(851));
      expect(cache.messageHistory.reads.counts[HistoryReadReason.gap], 1);
    } finally {
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await cache.close();
    }
  });
}
