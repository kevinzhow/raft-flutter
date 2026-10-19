import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_events.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

const _scope = MessageHistoryScope(
  origin: 'https://review.invalid',
  principal: 'alice',
  server: 'server',
  channel: 'chat',
  parentChannel: 'chat',
  authority: 'member',
);
Map<String, dynamic> _row(int seq) => {
  'id': 'm$seq',
  'channelId': 'chat',
  'seq': '$seq',
  'content': 'Body $seq',
};

class _Client extends RaftClient {
  _Client() : super(origin: _scope.origin, sessionStore: MemorySessionStore()) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final resumed = <BigInt>[];
  @override
  void resume(BigInt seq) => resumed.add(seq);
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
}

class _NavigationClient extends _Client {
  final contextStarted = Completer<void>();
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async => {
    'messages': [
      for (
        var i = before == null ? 51 : 1;
        i <= (before == null ? 100 : 50);
        i++
      )
        _row(i),
    ],
    'historyLimited': false,
  };
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/context/m25') {
      if (!contextStarted.isCompleted) contextStarted.complete();
      return {
        'messages': [
          for (var i = 10; i <= 40; i++)
            if (i != 20) {..._row(i), if (i == 25) 'content': 'Edited offline'},
        ],
        'channelId': 'chat',
        'targetMessageId': 'm25',
        'hasOlder': true,
        'hasNewer': true,
        'historyLimited': false,
      };
    }
    return {};
  }
}

Future<void> _tail(MessageHistoryStorage db) async {
  await db.acceptPage(
    MessageHistoryPage(
      {
        'messages': [for (var i = 1; i <= 50; i++) _row(i)],
        'historyLimited': false,
      },
      scope: _scope,
      revision: await db.revision(_scope),
      before: null,
      after: null,
      local: false,
    ),
  );
}

void main() {
  test(
    'a live event after a context island does not turn that island into a tail',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory()),
          db = cache.messageHistory;
      try {
        await db.acceptPage(
          MessageHistoryPage(
            {
              'messages': [for (var i = 10; i <= 40; i++) _row(i)],
              'historyLimited': false,
              'hasOlder': true,
              'hasNewer': true,
            },
            scope: _scope,
            revision: await db.revision(_scope),
            before: null,
            after: null,
            local: false,
            focused: true,
          ),
        );
        await db.acceptEvents(_scope, [_row(100)]);
        expect((await db.readPage(_scope))!.rows.map((m) => m['id']), ['m100']);
      } finally {
        await cache.close();
      }
    },
  );

  test(
    'an empty replay records server progress while no channel is selected',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory()),
          client = _Client();
      final w = WorkspaceController(client, cache: cache)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'});
      w.messageDomain.ledger.switchServer('server');
      try {
        await _tail(cache.messageHistory);
        await cache.messageHistory.checkpoint(_scope, BigInt.from(50));
        await MessageHistoryEvents.resumeResponse(w, {
          'messages': [],
          'currentSeq': '75',
          'hasMore': false,
        }, refreshUnread: () {});
        expect(
          await cache.messageHistory.resumeSequence(_scope),
          BigInt.from(75),
        );
        await MessageHistoryEvents.resume(w);
        expect(client.resumed, [BigInt.from(75)]);
      } finally {
        await w.flushCache();
        w.dispose();
        await client.dispose();
        await cache.close();
      }
    },
  );

  test(
    'a saved row without neighbour coverage cannot answer a context jump',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory());
      try {
        await cache.messageHistory.acceptEvents(_scope, [_row(25)]);
        expect(await cache.messageHistory.readContext(_scope, 'm25'), isNull);
        expect(
          await cache.messageHistory.readContext(_scope, 'm25', radius: 0),
          isNotNull,
        );
      } finally {
        await cache.close();
      }
    },
  );

  test('a held expired context is checked again after navigation', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory()),
        client = _NavigationClient();
    final w = WorkspaceController(client, cache: cache)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'chat', 'type': 'private', 'joined': true}),
      ];
    w.messageDomain.ledger.switchServer('server');
    try {
      await w.selectChannel(w.channels.single, autoRead: false);
      await w.messageDomain.older();
      await w.flushCache();
      await cache.customStatement('UPDATE raft_history_ranges SET verified=0');
      await w.jumpToMessage('chat', 'm25', navigate: false);
      await client.contextStarted.future.timeout(const Duration(seconds: 2));
      final watch = Stopwatch()..start();
      while (w.messageDomain.ledger.message('chat', 'm25')?['content'] !=
              'Edited offline' &&
          watch.elapsed < const Duration(seconds: 2)) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(
        w.messageDomain.ledger.message('chat', 'm25')!['content'],
        'Edited offline',
      );
      expect(w.messageDomain.ledger.contains('chat', 'm20'), isFalse);
    } finally {
      await w.flushCache();
      w.dispose();
      await client.dispose();
      await cache.close();
    }
  });

  test(
    'a sparse live event does not replace the saved tail with one row',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory()),
          db = cache.messageHistory;
      try {
        await _tail(db);
        await db.acceptEvents(_scope, [_row(60)]);
        final all = await db.readPage(_scope, limit: 100);
        expect(all!.rows.map((m) => m['id']), [
          for (var i = 1; i <= 50; i++) 'm$i',
          'm60',
        ]);
        expect(
          all.hasMore,
          isTrue,
          reason: 'An event does not prove the gap after 50.',
        );
        expect(await db.readPage(_scope, before: BigInt.from(60)), isNull);
        final reopened = await db.readWindow(
          _scope.origin,
          'alice',
          'server',
          'window',
          'chat',
        );
        expect((reopened!['messages'] as List).length, 50);
        expect((reopened['messages'] as List).first['id'], 'm2');
        expect((reopened['messages'] as List).last['id'], 'm60');
      } finally {
        await cache.close();
      }
    },
  );

  test('an unvisited channel retains all accepted sparse live rows', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory()),
        db = cache.messageHistory;
    try {
      for (final seq in [60, 75, 100]) {
        await db.acceptEvents(_scope, [_row(seq)]);
      }
      expect((await db.readPage(_scope))!.rows.map((m) => m['id']), [
        'm60',
        'm75',
        'm100',
      ]);
      expect(await db.readPage(_scope, before: BigInt.from(100)), isNull);
    } finally {
      await cache.close();
    }
  });

  for (final saved in [false, true]) {
    test(
      'reconnect on channel list resumes ${saved ? 'committed' : 'legacy in-memory'} progress',
      () async {
        final cache = DriftWorkspaceCache(NativeDatabase.memory()),
            client = _Client();
        final w = WorkspaceController(client, cache: cache)
          ..server = RaftRecord({'id': 'server', 'role': 'owner'});
        w.messageDomain.ledger.switchServer('server');
        try {
          if (saved) {
            await _tail(cache.messageHistory);
            await cache.messageHistory.checkpoint(_scope, BigInt.from(50));
          }
          w.messageDomain.ledger.ingest([
            _row(100),
          ], expectedGeneration: w.messageDomain.ledger.generation);
          expect(w.channel, isNull);
          await MessageHistoryEvents.resume(w);
          expect(client.resumed, [BigInt.from(saved ? 50 : 100)]);
        } finally {
          await w.flushCache();
          w.dispose();
          await client.dispose();
          await cache.close();
        }
      },
    );
  }
}
