import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_read_policy.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/message_history_verification.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> _row(int seq, {String? content}) => {
  'id': 'm$seq',
  'channelId': 'chat',
  'seq': '$seq',
  'content': content ?? 'Body $seq',
  'senderType': 'user',
  'senderId': 'alice',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://verify.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final incoming = StreamController<RaftEvent>.broadcast(sync: true);
  final edits = <int, String>{}, deleted = <int>{};
  final calls = <String>[];
  Completer<void>? gate, started;
  Object? failure;
  @override
  Stream<RaftEvent> get events => incoming.stream;
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
  Future<Map<String, dynamic>> _read(String key, int first, int last) async {
    calls.add(key);
    final problem = failure;
    final response = {
      'messages': [
        for (var i = first; i <= last; i++)
          if (!deleted.contains(i)) _row(i, content: edits[i]),
      ],
      'historyLimited': false,
      'threadSummariesByParentMessageId': <String, dynamic>{},
    };
    if (started?.isCompleted == false) started!.complete();
    await gate?.future;
    if (problem != null) throw problem;
    return response;
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async {
    final candidates = [
      for (var i = 1; i <= 100; i++)
        if (!deleted.contains(i) &&
            (before == null || BigInt.from(i) < before) &&
            (after == null || BigInt.from(i) > after))
          i,
    ];
    final selected = after == null
        ? candidates
              .skip((candidates.length - limit).clamp(0, candidates.length))
              .toList()
        : candidates.take(limit).toList();
    return _read(
      'page:$before:$after:$limit',
      selected.firstOrNull ?? 1,
      selected.lastOrNull ?? 0,
    );
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/sync') return <dynamic>[];
    if (path.startsWith('/messages/context/m')) {
      final target = int.parse(path.split('/m').last);
      if (deleted.contains(target)) {
        calls.add('context:$target');
        throw const RaftApiException('Message unavailable', status: 404);
      }
      final response = await _read(
        'context:$target',
        (target - 15).clamp(1, 100),
        (target + 15).clamp(1, 100),
      );
      return {
        ...response,
        'channelId': 'chat',
        'targetMessageId': 'm$target',
        'hasOlder': target > 16,
        'hasNewer': target < 85,
      };
    }
    return {};
  }
}

class _Case {
  DateTime now = DateTime.utc(2026, 10, 15);
  final client = _Client();
  late final DriftWorkspaceCache cache = DriftWorkspaceCache(
    NativeDatabase.memory(),
    historyClock: () => now,
  );
  late final WorkspaceController w = WorkspaceController(client, cache: cache)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channels = [
      RaftChannel({'id': 'chat', 'type': 'private', 'joined': true}),
    ];
  Future<void> seed() async {
    w.messageDomain.ledger.switchServer('server');
    await w.selectChannel(w.channels.single, autoRead: false);
    await w.messageDomain.older();
    await w.flushCache();
    await cache.messageHistory.reads.settled;
    expect(w.messageDomain.messages.length, 100);
    client.calls.clear();
  }

  void forgetOlder() {
    for (var i = 1; i <= 50; i++) {
      w.messageDomain.ledger.remove('chat', 'm$i');
      w.messageDomain.visibleIds['chat']?.remove('m$i');
    }
    w.messageDomain.state.hasMore = true;
  }

  Future<void> close() async {
    if (client.gate?.isCompleted == false) client.gate!.complete();
    await cache.messageHistory.reads.settled;
    await w.flushCache();
    w.dispose();
    await client.incoming.close();
    await client.dispose();
    await cache.close();
  }
}

void main() {
  test('expired older rows display before the wire read, then edits and deletion converge', () async {
    final c = _Case();
    addTearDown(c.close);
    await c.seed();
    c.forgetOlder();
    c.now = c.now.add(const Duration(hours: 25));
    c.client.edits[25] = 'Changed while closed';
    c.client.deleted.add(20);
    c.client.gate = Completer<void>();
    c.client.started = Completer<void>();
    await c.w.messageDomain.older().timeout(const Duration(seconds: 2));
    expect(
      c.w.messageDomain.ledger.message('chat', 'm25')!['content'],
      'Body 25',
    );
    expect(c.w.messageDomain.ledger.contains('chat', 'm20'), isTrue);
    expect(c.w.messageDomain.state.loadingOlder, isFalse);
    await c.client.started!.future.timeout(const Duration(seconds: 2));
    c.client.gate!.complete();
    await c.cache.messageHistory.reads.settled;
    expect(
      c.w.messageDomain.ledger.message('chat', 'm25')!['content'],
      'Changed while closed',
    );
    expect(c.w.messageDomain.ledger.contains('chat', 'm20'), isFalse);
    expect(c.w.messageDomain.state.hasMore, isFalse);
    final scope = MessageHistoryPages.scope(c.w, 'chat')!;
    expect(
      await c.cache.messageHistory.readContext(scope, 'm20', radius: 0),
      isNull,
    );
    expect(c.cache.messageHistory.reads.counts[HistoryReadReason.aged], 1);
  });

  test('fresh local older pages do not request the wire', () async {
    final c = _Case();
    addTearDown(c.close);
    await c.seed();
    c.forgetOlder();
    c.now = c.now.add(const Duration(hours: 23));
    await c.w.messageDomain.older();
    await c.cache.messageHistory.reads.settled;
    expect(c.w.messageDomain.messages.length, 100);
    expect(c.client.calls, isEmpty);
  });

  test('an offline verification keeps saved rows and retries only on the next foreground visit', () async {
    final c = _Case();
    addTearDown(c.close);
    await c.seed();
    c.forgetOlder();
    c.now = c.now.add(const Duration(hours: 25));
    c.client.failure = const RaftApiException('Offline', status: 503);
    await c.w.messageDomain.older();
    await c.cache.messageHistory.reads.settled;
    expect(c.w.messageDomain.messages.length, 100);
    expect(c.w.error, isNull);
    expect(c.client.calls.length, 1);
    c.forgetOlder();
    await c.w.messageDomain.older();
    await c.cache.messageHistory.reads.settled;
    expect(c.client.calls.length, 1);
    c.client.failure = null;
    c.client.edits[25] = 'Reconnected';
    c.w.resumes.value++;
    c.forgetOlder();
    await c.w.messageDomain.older();
    await c.cache.messageHistory.reads.settled;
    expect(c.client.calls.length, 2);
    expect(
      c.w.messageDomain.ledger.message('chat', 'm25')!['content'],
      'Reconnected',
    );
  });

  test(
    'jumping to an already held expired target rechecks its context',
    () async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.now = c.now.add(const Duration(hours: 25));
      c.client.edits[25] = 'New target';
      c.client.deleted.add(20);
      await c.w.jumpToMessage('chat', 'm25', navigate: false);
      await c.cache.messageHistory.reads.settled;
      expect(c.client.calls, contains('context:25'));
      expect(
        c.w.messageDomain.ledger.message('chat', 'm25')!['content'],
        'New target',
      );
      expect(c.w.messageDomain.ledger.contains('chat', 'm20'), isFalse);
      expect(c.w.messageDomain.ledger.contains('chat', 'm100'), isTrue);
    },
  );

  test(
    'reopening a retained window checks expired rows older than its fresh tail',
    () async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.now = c.now.add(const Duration(hours: 25));
      c.client.edits[25] = 'Changed before reopening';
      c.client.deleted.add(20);
      await c.w.selectChannel(c.w.channels.single, autoRead: false);
      await c.cache.messageHistory.reads.settled;
      expect(
        c.w.messageDomain.ledger.message('chat', 'm25')!['content'],
        'Changed before reopening',
      );
      expect(c.w.messageDomain.messages.any((m) => m.id == 'm20'), isFalse);
      expect(
        c.client.calls.where((key) => key.startsWith('page:51:')).length,
        1,
      );
    },
  );

  test(
    'a deleted cached jump target is removed without revoking its channel',
    () async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.now = c.now.add(const Duration(hours: 25));
      c.client.deleted.add(25);
      await c.w.jumpToMessage('chat', 'm25', navigate: false);
      await c.cache.messageHistory.reads.settled;
      expect(c.w.messageDomain.ledger.contains('chat', 'm25'), isFalse);
      expect(c.w.channel!.id, 'chat');
      expect(c.w.messageWindows.notRevoked('chat'), isTrue);
      expect(c.w.messageDomain.ledger.contains('chat', 'm100'), isTrue);
    },
  );

  test('manual refresh bypasses age while keeping the held timeline', () async {
    final c = _Case();
    addTearDown(c.close);
    await c.seed();
    c.client.edits[25] = 'Manual edit';
    c.client.deleted.add(20);
    expect(await MessageHistoryVerification.refresh(c.w), isTrue);
    expect(
      c.w.messageDomain.ledger.message('chat', 'm25')!['content'],
      'Manual edit',
    );
    expect(c.w.messageDomain.ledger.contains('chat', 'm20'), isFalse);
    expect(c.w.messageDomain.ledger.contains('chat', 'm100'), isTrue);
    expect(
      c.cache.messageHistory.reads.counts[HistoryReadReason.manual],
      greaterThan(0),
    );
  });

  test('a live edit arriving while verification waits wins over that HTTP snapshot', () async {
    final c = _Case();
    addTearDown(c.close);
    await c.seed();
    c.forgetOlder();
    c.now = c.now.add(const Duration(hours: 25));
    c.client.gate = Completer<void>();
    c.client.started = Completer<void>();
    await c.w.messageDomain.older();
    await c.client.started!.future;
    c.client.incoming.add(
      RaftEvent('message:updated', {
        'id': 'm25',
        'channelId': 'chat',
        'content': 'Live wins',
      }),
    );
    await c.cache.messageHistory.receiver.settled;
    c.client.gate!.complete();
    await c.cache.messageHistory.reads.settled;
    expect(
      c.w.messageDomain.ledger.message('chat', 'm25')!['content'],
      'Live wins',
    );
    final scope = MessageHistoryPages.scope(c.w, 'chat')!;
    expect(
      ((await c.cache.messageHistory.readContext(
                scope,
                'm25',
                radius: 0,
              ))!['messages']
              as List)
          .single['content'],
      'Live wins',
    );
  });

  test('an explicit channel denial during verification clears its saved projection', () async {
    final c = _Case();
    addTearDown(c.close);
    await c.seed();
    c.forgetOlder();
    c.now = c.now.add(const Duration(hours: 25));
    final scope = MessageHistoryPages.scope(c.w, 'chat')!;
    c.client.failure = const RaftApiException('Denied', status: 403);
    await c.w.messageDomain.older();
    await c.cache.messageHistory.reads.settled;
    expect(c.w.messageDomain.messages, isEmpty);
    expect(await c.cache.messageHistory.readPage(scope), isNull);
  });
}
