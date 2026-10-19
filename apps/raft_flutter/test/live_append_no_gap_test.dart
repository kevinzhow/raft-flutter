import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_gap_recovery.dart';
import 'package:raft_flutter/data/history_read_policy.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;
import 'support/history_automatic_fixture.dart';

/// Message n of the channel carries server sequence n * stride: the server
/// numbers every channel's messages from one counter, so [stride] > 1 models
/// other channels' traffic between this channel's messages.
class _WireClient extends HistoryAuditClient {
  _WireClient(this.stride);
  final int stride;
  final wire = <String>[];
  String? lastRandomId;
  Future<void> Function(String randomId)? echo;

  Map<String, dynamic> message(int n, {String by = 'alice'}) => {
    'id': 'm$n',
    'channelId': 'chat',
    'seq': '${n * stride}',
    'content': 'Body $n',
    'senderType': 'user',
    'senderId': by,
  };

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    wire.add('GET $path $query');
    if (path == '/messages/sync') {
      final since = BigInt.parse('${query!['since_seq']}');
      return [
        for (var n = 1; n <= total; n++)
          if (BigInt.from(n * stride) > since) message(n),
      ];
    }
    return super.get(path, query: query);
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async {
    wire.add('PAGE before=$before after=$after');
    calls.add('page:$before:$after:$limit');
    final all = [
      for (var n = 1; n <= total; n++)
        if (!deleted.contains(n) &&
            (before == null || BigInt.from(n * stride) < before) &&
            (after == null || BigInt.from(n * stride) > after))
          n,
    ];
    final picked = after == null
        ? all.skip((all.length - limit).clamp(0, all.length))
        : all.take(limit);
    return {
      'messages': [for (final n in picked) message(n)],
      'historyLimited': false,
      'threadSummariesByParentMessageId': <String, dynamic>{},
    };
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path != '/v2/messages') return super.post(path, data: data);
    await echo?.call(data['randomId']);
    lastRandomId = data['randomId'];
    return {
      'message': {
        ...message(total + 1, by: 'alice'),
        'id': 'sent-${data['randomId']}',
        'content': data['content'],
        'randomId': data['randomId'],
      },
    };
  }
}

class _Case extends HistoryAuditCase {
  _Case(int stride) : client = _WireClient(stride);
  @override
  // ignore: overridden_fields
  final _WireClient client;
  final owner = Object();
  HistoryGapRecovery? recovery;
  Map<HistoryReadReason, int> baseline = {};

  Future<void> start() async {
    await seed();
    client.wire.clear();
    baseline = _reads();
    w.connected = true;
    recovery = HistoryGapRecovery.of(w, false)..start(owner);
    await settle();
  }

  Map<HistoryReadReason, int> _reads() => {
    for (final e in cache.messageHistory.reads.counts.entries)
      if (e.key != HistoryReadReason.incremental) e.key: e.value,
  };

  Future<void> settle() async {
    for (var n = 0; n < 3; n++) {
      await cache.messageHistory.receiver.settled;
      await cache.messageHistory.reads.settled;
      await w.flushCache();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  /// The next message of the channel arrives on the socket.
  void live(int n, {String by = 'bob', String name = 'message:new'}) =>
      client.incoming.add(RaftEvent(name, client.message(n, by: by)));

  /// A live append after the newest message needs no gap, check, or read.
  Future<void> expectQuiet() async {
    await settle();
    final scope = MessageHistoryPages.scope(w, 'chat')!;
    expect(client.wire, isEmpty, reason: 'no history/sync request');
    expect(_reads(), baseline, reason: 'no gap/verification read counted');
    expect(await cache.messageHistory.gaps.readSaved(scope), isEmpty);
    for (final message in w.messageDomain.messages) {
      expect(recovery!.contains(message.id), isFalse, reason: message.id);
    }
    expect(w.error, isNull);
  }

  @override
  Future<void> close() async {
    recovery?.stop(owner);
    await super.close();
  }
}

void main() {
  for (final stride in [1, 3]) {
    final label = stride == 1 ? 'one channel' : 'busy server';
    group('live append, $label', () {
      test('another member message causes no gap work', () async {
        final c = _Case(stride);
        addTearDown(c.close);
        await c.start();
        c.live(101);
        await c.expectQuiet();
        expect(c.w.messageDomain.messages.last.id, 'm101');
        expect(c.w.messageDomain.messages, hasLength(101));
      });

      test('several live messages in a row cause no gap work', () async {
        final c = _Case(stride);
        addTearDown(c.close);
        await c.start();
        for (var n = 101; n <= 106; n++) {
          c.live(n);
        }
        await c.expectQuiet();
        expect(c.w.messageDomain.messages.last.id, 'm106');
      });

      test('the person sending (echo first) causes no gap work', () async {
        final c = _Case(stride);
        addTearDown(c.close);
        await c.start();
        c.client.echo = (randomId) async => c.client.incoming.add(
          RaftEvent('message:new', {
            ...c.client.message(101, by: 'alice'),
            'id': 'sent-$randomId',
            'randomId': randomId,
            'content': 'Hello',
          }),
        );
        expect(await c.w.send('Hello'), isTrue);
        await c.expectQuiet();
        expect(
          c.w.messageDomain.messages.where((m) => m.json['content'] == 'Hello'),
          hasLength(1),
        );
      });

      test(
        'the person sending (HTTP answer first) causes no gap work',
        () async {
          final c = _Case(stride);
          addTearDown(c.close);
          await c.start();
          expect(await c.w.send('Hello'), isTrue);
          c.client.incoming.add(
            RaftEvent('message:new', {
              ...c.client.message(101, by: 'alice'),
              'id': 'sent-${c.client.lastRandomId}',
              'randomId': c.client.lastRandomId,
              'content': 'Hello',
            }),
          );
          await c.expectQuiet();
          expect(
            c.w.messageDomain.messages.where(
              (m) => m.json['content'] == 'Hello',
            ),
            hasLength(1),
          );
        },
      );

      test('a send then replies from others cause no gap work', () async {
        final c = _Case(stride);
        addTearDown(c.close);
        await c.start();
        c.client.echo = (randomId) async => c.client.incoming.add(
          RaftEvent('message:new', {
            ...c.client.message(101, by: 'alice'),
            'id': 'sent-$randomId',
            'randomId': randomId,
          }),
        );
        expect(await c.w.send('Question'), isTrue);
        c.live(102);
        c.live(103);
        await c.expectQuiet();
      });

      test(
        'live messages and a send while scrolled up cause no gap work',
        () async {
          final c = _Case(stride);
          addTearDown(c.close);
          await c.start();
          c.w.setTimelineAtBottom('chat', false);
          c.live(101);
          c.live(102);
          c.client.echo = (randomId) async => c.client.incoming.add(
            RaftEvent('message:new', {
              ...c.client.message(103, by: 'alice'),
              'id': 'sent-$randomId',
              'randomId': randomId,
            }),
          );
          expect(await c.w.send('Still here'), isTrue);
          await c.expectQuiet();
        },
      );

      test(
        'an agent streamed then edited message causes no gap work',
        () async {
          final c = _Case(stride);
          addTearDown(c.close);
          await c.start();
          c.live(101, by: 'agent');
          for (final part in ['a', 'ab', 'abc']) {
            c.client.incoming.add(
              RaftEvent('message:updated', {
                'id': 'm101',
                'channelId': 'chat',
                'content': part,
              }),
            );
          }
          await c.expectQuiet();
          expect(c.w.messageDomain.messages.last.json['content'], 'abc');
        },
      );
    });
  }

  group('missed messages are still recovered', () {
    test('a jump seen while the socket is not live re-syncs', () async {
      // Without a live socket nothing proves the stretch before this message.
      final c = _Case(1);
      addTearDown(c.close);
      await c.start();
      c.client.total = 104;
      c.w.connected = false;
      c.live(104);
      await c.settle();
      expect(c.client.wire, isNotEmpty, reason: 'the jump asks the server');
      expect(
        c.w.messageDomain.messages.map((m) => m.id),
        containsAll(['m101', 'm102', 'm103', 'm104']),
      );
    });

    for (final stride in [1, 3]) {
      test(
        'a reconnect finds messages missed while offline, stride $stride',
        () async {
          final c = _Case(stride);
          addTearDown(c.close);
          await c.start();
          c.client.incoming.add(const RaftEvent('disconnected', null));
          c.client.total = 103;
          c.client.incoming.add(const RaftEvent('connected', null));
          await c.reconnect();
          c.client.total = 104;
          c.live(104);
          await c.settle();
          expect(
            c.client.wire,
            isNotEmpty,
            reason: 'reconnect reads the server',
          );
          expect(
            c.w.messageDomain.messages.map((m) => m.id),
            containsAll(['m101', 'm102', 'm103', 'm104']),
          );
        },
      );
    }
  });

  group('saved tail proof', () {
    Future<(DriftWorkspaceCache, MessageHistoryScope)> cached(
      List<int> proved,
    ) async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory());
      addTearDown(cache.close);
      final w = receiver(HistoryClient(), cache);
      addTearDown(() async {
        await w.flushCache();
        w.dispose();
      });
      final scope = MessageHistoryPages.scope(w, 'chat')!;
      final store = cache.messageHistory;
      // The latest page: a full page proves everything from its first row up.
      await store.acceptPage(
        MessageHistoryPage(
          {
            'messages': [for (final n in proved) row('chat', n)],
          },
          scope: scope,
          revision: await store.revision(scope),
          before: null,
          after: null,
          limit: proved.length,
          local: false,
        ),
      );
      return (cache, scope);
    }

    Future<int> gapsAfter(
      DriftWorkspaceCache cache,
      MessageHistoryScope scope,
      List<int> seqs,
    ) async => (await cache.messageHistory.gaps.read(scope, [
      for (final n in seqs) ('chat-$n', BigInt.from(n)),
    ])).length;

    test('a live row extends the proof; an unmarked one does not', () async {
      final (cache, scope) = await cached([
        for (var n = 51; n <= 100; n++) n * 3,
      ]);
      final store = cache.messageHistory;
      await store.acceptEvents(scope, [row('chat', 301)], live: true);
      expect(await gapsAfter(cache, scope, [300, 301]), 0);
      await store.acceptEvents(scope, [row('chat', 450)], live: true);
      expect(await gapsAfter(cache, scope, [301, 450]), 0);
      await store.acceptEvents(scope, [row('chat', 600)]);
      expect(await gapsAfter(cache, scope, [450, 600]), 1);
    });

    test('a live row after an unproved row leaves the older gap', () async {
      final (cache, scope) = await cached([
        for (var n = 51; n <= 100; n++) n * 3,
      ]);
      final store = cache.messageHistory;
      await store.acceptEvents(scope, [row('chat', 450)]);
      await store.acceptEvents(scope, [row('chat', 460)], live: true);
      expect(await gapsAfter(cache, scope, [450, 460]), 0);
      expect(await gapsAfter(cache, scope, [300, 450]), 1);
    });
  });
}
