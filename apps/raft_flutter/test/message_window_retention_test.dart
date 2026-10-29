import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_window_snapshot.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/workspace_composer.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> row(int seq, {String channel = 'b'}) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': 'Accepted $seq 中文',
  'senderType': 'user',
  'senderId': 'alice',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://window.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final eventsController = StreamController<RaftEvent>.broadcast(sync: true);
  Completer<Map<String, dynamic>>? pending;
  Object? failure;
  bool limited = false;
  final resumed = <BigInt>[];
  @override
  void resume(BigInt seq) => resumed.add(seq);
  @override
  Stream<RaftEvent> get events => eventsController.stream;
  @override
  void joinChannel(String id) {}
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return {
      'messages': [
        for (
          var i = before == null ? 51 : 1;
          i <= (before == null ? 100 : 50);
          i++
        )
          row(i, channel: id),
      ],
      'historyLimited': limited,
      'threadSummariesByParentMessageId': {},
    };
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
}

WorkspaceController _controller(_Client client, WorkspaceCache db) {
  final w = WorkspaceController(client, cache: db)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channels = [
      RaftChannel({'id': 'a', 'type': 'private', 'joined': true}),
      RaftChannel({'id': 'b', 'type': 'private', 'joined': true}),
    ];
  w.messageDomain.ledger.switchServer('server');
  return w;
}

class _DelayedCache implements WorkspaceCache {
  _DelayedCache(this.db);
  final DriftWorkspaceCache db;
  Completer<void>? gate;
  final entered = Completer<void>();
  @override
  Future<dynamic> read(
    String o,
    String p,
    String s,
    String kind,
    String id,
  ) async {
    if (kind == 'window' && id == 'b' && gate != null) {
      if (!entered.isCompleted) entered.complete();
      await gate!.future;
    }
    return db.read(o, p, s, kind, id);
  }

  @override
  Future<void> write(
    String o,
    String p,
    String s,
    String kind,
    String id,
    dynamic value,
  ) => db.write(o, p, s, kind, id, value);
  @override
  Future<void> revokeChannel(String o, String p, String s, String c) =>
      db.revokeChannel(o, p, s, c);
  @override
  Future<void> revokeServer(String o, String p, String s) =>
      db.revokeServer(o, p, s);
  @override
  Future<void> clearAccount(String o, String p) => db.clearAccount(o, p);
  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String o,
    String p,
    String s,
  ) => db.readTranslations(o, p, s);
  @override
  Future<void> writeTranslations(
    String o,
    String p,
    String s,
    List<Map<String, dynamic>> entries,
  ) => db.writeTranslations(o, p, s, entries);
  @override
  Future<void> close() => db.close();
}

class _ThreadClient extends _Client {
  Completer<void>? hold;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    await hold?.future;
    if (path == '/channels/b/threads/b-100') return {'threadChannelId': 't'};
    if (path == '/messages/context/b-100') {
      return {
        'messages': [row(100)],
      };
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (id != 't') {
      return super.messagePage(id, limit: limit, before: before, after: after);
    }
    await hold?.future;
    return {
      'messages': [row(1, channel: 't'), row(2, channel: 't')],
      'historyLimited': false,
    };
  }
}

class _HistoryThreadClient extends _ThreadClient {
  final beforeReads = <BigInt?>[];
  Set<int> removed = {};
  int tailEnd = 100;
  bool historyRestricted = false;
  Completer<void>? repliesGate;
  Object? repliesFailure;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/context/t-25') {
      return {
        'messages': [for (var i = 21; i <= 30; i++) row(i, channel: 't')],
        'hasOlder': true,
        'hasNewer': true,
      };
    }
    return super.get(path, query: query);
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (id != 't') {
      return super.messagePage(id, limit: limit, before: before, after: after);
    }
    beforeReads.add(before);
    await repliesGate?.future;
    if (repliesFailure != null) throw repliesFailure!;
    final end = before == null ? tailEnd : before.toInt() - 1;
    final start = (end - 49).clamp(1, end < 1 ? 1 : end);
    return {
      'messages': [
        for (var i = start; i <= end; i++)
          if (!removed.contains(i)) row(i, channel: 't'),
      ],
      'historyLimited': historyRestricted,
    };
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test(
    'realtime edits reach stored rows that have left the memory ledger',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory());
      final client = _Client();
      final receiver = _controller(client, db);
      try {
        await receiver.selectChannel(receiver.channels.last, autoRead: false);
        await receiver.messageDomain.older();
        receiver.messageDomain.ledger.remove('b', 'b-25');
        client.eventsController.add(
          RaftEvent('message:updated', {
            'id': 'b-25',
            'channelId': 'b',
            'content': 'edited while evicted',
          }),
        );
        client.eventsController.add(
          RaftEvent('message:updated', {
            'id': 'unknown',
            'channelId': 'b',
            'content': 'cannot invent a row',
          }),
        );
        await db.messageHistory.receiver.settled;
        final local = await db.messageHistory.readPage(
          MessageHistoryPages.scope(receiver, 'b')!,
          before: BigInt.from(26),
          limit: 25,
        );
        expect(local!.rows.last['content'], 'edited while evicted');
        expect(local.rows.any((m) => m['id'] == 'unknown'), isFalse);
        expect(receiver.messageDomain.ledger.contains('b', 'b-25'), isFalse);
      } finally {
        await receiver.flushCache();
        receiver.dispose();
        await client.eventsController.close();
        await db.close();
      }
    },
  );

  test(
    'a saved edit between local selection and admission wins over that page',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory()),
          client = _Client();
      final w = _controller(client, db);
      try {
        await w.selectChannel(w.channels.last, autoRead: false);
        await w.messageDomain.older();
        w.messageDomain.ledger.remove('b', 'b-25');
        final request = w.messageWindows.request(allowed: () => true);
        final page = await MessageHistoryPages.load(
          cache: db,
          scope: MessageHistoryPages.scope(w, 'b'),
          current: () => request.current,
          held: () => w.messageDomain.ledger.messages('b'),
          before: BigInt.from(26),
          limit: 25,
          remote: () async =>
              throw StateError('Local page must not use the network'),
        );
        client.eventsController.add(
          RaftEvent('message:updated', {
            'id': 'b-25',
            'channelId': 'b',
            'content': 'newer saved edit',
          }),
        );
        await db.messageHistory.receiver.settled;
        w.messageWindows.acceptRows(
          request,
          'b',
          (page['messages'] as List).cast<Map<String, dynamic>>(),
        );
        expect(w.messageDomain.ledger.message('b', 'b-25')!['content'], 'Accepted 25 中文');
        expect(await MessageHistoryPages.record(w, request, page), isTrue);
        expect(w.messageDomain.ledger.message('b', 'b-25')!['content'], 'newer saved edit');
      } finally {
        await w.flushCache();
        w.dispose();
        await client.eventsController.close();
        await db.close();
      }
    },
  );

  test(
    'an older queued stored edit cannot publish over a newer live edit',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory()),
          client = _Client();
      final w = _controller(client, db), gate = Completer<void>();
      try {
        await w.selectChannel(w.channels.last, autoRead: false);
        await w.messageDomain.older();
        final projection = Map<String, dynamic>.from(
          w.messageDomain.ledger.message('b', 'b-25')!,
        );
        w.messageDomain.ledger.remove('b', 'b-25');
        unawaited(db.messageHistory.receiver.run(() => gate.future));
        client.eventsController.add(
          RaftEvent('message:updated', {
            'id': 'b-25',
            'channelId': 'b',
            'content': 'older queued edit',
          }),
        );
        final request = w.messageWindows.request(allowed: () => true);
        w.messageWindows.acceptRows(request, 'b', [projection]);
        client.eventsController.add(
          RaftEvent('message:updated', {
            'id': 'b-25',
            'channelId': 'b',
            'content': 'newest live edit',
          }),
        );
        final seen = <String>[];
        void listen() =>
            seen.add('${w.messageDomain.ledger.message('b', 'b-25')?['content']}');
        w.addListener(listen);
        gate.complete();
        await db.messageHistory.receiver.settled;
        w.removeListener(listen);
        expect(seen, isNot(contains('older queued edit')));
        expect(w.messageDomain.ledger.message('b', 'b-25')!['content'], 'newest live edit');
        expect(
          (await db.messageHistory.readContext(
            MessageHistoryPages.scope(w, 'b')!,
            'b-25',
            radius: 0,
          ))!['messages'].single['content'],
          'newest live edit',
        );
      } finally {
        if (!gate.isCompleted) gate.complete();
        await w.flushCache();
        w.dispose();
        await client.eventsController.close();
        await db.close();
      }
    },
  );

  test('an accepted edit waiting for disk is not replaced by a later HTTP snapshot', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory()), client = _Client();
    final w = _controller(client, db), gate = Completer<void>();
    try {
      await w.selectChannel(w.channels.last, autoRead: false);
      await w.messageDomain.older();
      await w.flushCache();
      unawaited(db.messageHistory.receiver.run(() => gate.future));
      client.eventsController.add(
        RaftEvent('message:updated', {
          'id': 'b-25',
          'channelId': 'b',
          'content': 'accepted live edit awaiting disk',
        }),
      );
      for (final (localFirst, focused) in [
        (false, false),
        (true, false),
        (true, true),
      ]) {
        final request = w.messageWindows.request(allowed: () => true);
        final page = await MessageHistoryPages.load(
          cache: db,
          scope: MessageHistoryPages.scope(w, 'b'),
          current: () => request.current,
          held: () => w.messageDomain.ledger.messages('b'),
          before: focused ? null : BigInt.from(26),
          limit: 25,
          localFirst: localFirst,
          focused: focused,
          target: focused ? 'b-25' : null,
          remote: () async => {
            'messages': [for (var i = 1; i <= 25; i++) row(i)],
            'historyLimited': false,
          },
        );
        expect(
          (page['messages'] as List)
              .where((m) => m['id'] == 'b-25')
              .single['content'],
          'accepted live edit awaiting disk',
          reason: 'local=$localFirst context=$focused',
        );
        w.messageWindows.acceptRows(
          request,
          'b',
          (page['messages'] as List).cast<Map<String, dynamic>>(),
        );
        await MessageHistoryPages.record(w, request, page);
        expect(
          w.messageDomain.ledger.message('b', 'b-25')!['content'],
          'accepted live edit awaiting disk',
        );
      }
    } finally {
      if (!gate.isCompleted) gate.complete();
      await w.flushCache();
      w.dispose();
      await client.eventsController.close();
      await db.close();
    }
  });

  test('authorized live rows persist without opening their channel', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory()), client = _Client();
    final w = _controller(client, db);
    try {
      await w.selectChannel(w.channels.last, autoRead: false);
      client.eventsController.add(
        RaftEvent('message:new', row(101, channel: 'a')),
      );
      await db.messageHistory.receiver.settled;
      final scope = MessageHistoryPages.scope(w, 'a')!;
      expect(
        (await db.messageHistory.readPage(scope))!.rows.single['id'],
        'a-101',
      );
      expect(await db.messageHistory.resumeSequence(scope), BigInt.from(101));
      expect(w.channel!.id, 'b');
    } finally {
      await w.flushCache();
      w.dispose();
      await client.eventsController.close();
      await db.close();
    }
  });

  test('a queued live row retires across a role ABA cycle', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory()), client = _Client();
    final w = _controller(client, db), gate = Completer<void>();
    try {
      await w.selectChannel(w.channels.last, autoRead: false);
      unawaited(db.messageHistory.receiver.run(() => gate.future));
      client.eventsController.add(
        RaftEvent('message:new', row(101, channel: 'a')),
      );
      for (final role in ['guest', 'owner']) {
        w.applyMembershipRole({
          'userId': 'alice',
          'serverId': 'server',
          'role': role,
        });
      }
      gate.complete();
      await db.messageHistory.receiver.settled;
      final scope = MessageHistoryPages.scope(w, 'a')!;
      expect(
        await db.messageHistory.readContext(scope, 'a-101'),
        isNull,
        reason: 'The queued row belongs to the previous permission grant.',
      );
      client.eventsController.add(
        RaftEvent('message:new', row(102, channel: 'a')),
      );
      await db.messageHistory.receiver.settled;
      expect(
        (await db.messageHistory.readContext(
          scope,
          'a-102', radius: 0,
        ))!['targetMessageId'],
        'a-102',
      );
    } finally {
      if (!gate.isCompleted) gate.complete();
      await w.flushCache();
      w.dispose();
      await client.eventsController.close();
      await db.close();
    }
  });

  test(
    'an unvisited joint thread uses the authorized event parent anchor',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory()),
          client = _Client();
      final w = _controller(client, db);
      try {
        w.channels = [
          RaftChannel({'id': 'a', 'type': 'joint', 'joined': true}),
          w.channels.last,
        ];
        await w.selectChannel(w.channels.last, autoRead: false);
        client.eventsController.add(
          RaftEvent('message:new', {
            ...row(101, channel: 'unvisited-thread'),
            'conversationContext': {
              'channelType': 'thread',
              'parentChannelId': 'a',
              'parentMessageId': 'canonical-parent',
              'parentChannelType': 'joint',
            },
          }),
        );
        await db.messageHistory.receiver.settled;
        final scope = await db.messageHistory.knownScope(
          client.origin,
          'alice',
          'server',
          'unvisited-thread',
        );
        expect(scope, isNotNull);
        expect(scope!.parentChannel, 'a');
        expect(scope.parentMessage, 'canonical-parent');
        expect(
          (await db.messageHistory.readContext(
            scope,
            'unvisited-thread-101', radius: 0,
          ))!['targetMessageId'],
          'unvisited-thread-101',
        );
        expect(w.channel!.id, 'b');
      } finally {
        await w.flushCache();
        w.dispose();
        await client.eventsController.close();
        await db.close();
      }
    },
  );

  test('resume continuation waits for queued rows to commit', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory()), client = _Client();
    final w = _controller(client, db), gate = Completer<void>();
    try {
      await w.selectChannel(w.channels.last, autoRead: false);
      final scope = MessageHistoryPages.scope(w, 'b')!;
      final checkpoint = await db.messageHistory.resumeSequence(scope);
      unawaited(db.messageHistory.receiver.run(() => gate.future));
      client.eventsController.add(
        RaftEvent('sync:resume:response', {
          'messages': [row(101)],
          'currentSeq': '101',
          'hasMore': true,
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(client.resumed, isEmpty);
      expect(await db.messageHistory.resumeSequence(scope), checkpoint);
      gate.complete();
      await db.messageHistory.receiver.settled;
      expect(client.resumed, [BigInt.from(101)]);
      expect(await db.messageHistory.resumeSequence(scope), BigInt.from(101));
      expect(
        (await db.messageHistory.readPage(scope))!.rows.last['id'],
        'b-101',
      );
    } finally {
      if (!gate.isCompleted) gate.complete();
      await db.messageHistory.receiver.settled;
      await w.flushCache();
      w.dispose();
      await client.eventsController.close();
      await db.close();
    }
  });

  test(
    'a failed device write retains the resume cursor and replay repairs it',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory()),
          client = _Client();
      final w = _controller(client, db);
      try {
        await w.selectChannel(w.channels.last, autoRead: false);
        await w.flushCache();
        final scope = MessageHistoryPages.scope(w, 'b')!;
        final before = await db.messageHistory.resumeSequence(scope);
        await db.customStatement(
          "CREATE TRIGGER history_test_full BEFORE INSERT ON raft_history_rows BEGIN SELECT RAISE(ABORT,'synthetic device full'); END",
        );
        void replay() => client.eventsController.add(
          RaftEvent('sync:resume:response', {
            'messages': [row(101)],
            'currentSeq': '101',
            'hasMore': true,
          }),
        );
        replay();
        await db.messageHistory.receiver.settled;
        expect(await db.messageHistory.resumeSequence(scope), before);
        expect(client.resumed, isEmpty);
        expect(w.error, contains('could not be saved'));
        expect(
          (await db.messageHistory.readPage(scope))!.rows.last['id'],
          'b-100',
        );
        await db.customStatement('DROP TRIGGER history_test_full');
        client.eventsController.add(RaftEvent('message:new', row(102)));
        await db.messageHistory.receiver.settled;
        expect(
          await db.messageHistory.resumeSequence(scope),
          before,
          reason: 'A later successful write must not skip the failed row.',
        );
        replay();
        await db.messageHistory.receiver.settled;
        expect(client.resumed, [BigInt.from(101)]);
        expect(await db.messageHistory.resumeSequence(scope), BigInt.from(101));
      } finally {
        await w.flushCache();
        w.dispose();
        await client.eventsController.close();
        await db.close();
      }
    },
  );

  Future<void> historyCase(
    Future<void> Function(
      WorkspaceController,
      _HistoryThreadClient,
      DriftWorkspaceCache,
    )
    body,
  ) async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final client = _HistoryThreadClient();
    final w = _controller(client, db);
    try {
      await w.selectChannel(w.channels.last, autoRead: false);
      await w.openThreadIdentity(
        parentChannelId: 'b',
        parentMessageId: 'b-100',
        initialThreadChannelId: 't',
        navigate: false,
      );
      await w.messageDomain.older(thread: true);
      expect(w.replies.length, 100);
      await body(w, client, db);
    } finally {
      await w.flushCache();
      w.dispose();
      await client.eventsController.close();
      await db.close();
    }
  }

  Future<void> reopen(WorkspaceController w, {String? focus}) async {
    w.closeThread(navigate: false);
    await w.openThreadIdentity(
      parentChannelId: 'b',
      parentMessageId: 'b-100',
      initialThreadChannelId: 't',
      focusedMessageId: focus,
      navigate: false,
    );
  }

  for (final status in [403, 404]) {
    test(
      'a $status thread read revokes memory and disk while keeping authored text',
      () => historyCase((w, client, db) async {
        w.drafts['thread:b-100'] = 'keep my draft';
        final scope = MessageHistoryPages.scope(
          w,
          't',
          parent: 'b',
          parentMessage: 'b-100',
        )!;
        client.repliesFailure = RaftApiException(
          'synthetic denied',
          status: status,
        );
        await reopen(w);
        await w.flushCache();
        expect(w.replies, isEmpty);
        expect(await db.messageHistory.readPage(scope), isNull);
        expect(
          await db.read(
            client.origin,
            'alice',
            'server',
            'thread-window',
            'b-100',
          ),
          isNull,
        );
        expect(w.drafts['thread:b-100'], 'keep my draft');
        expect(w.channel!.id, 'b');
        expect(w.messageDomain.messages, isNotEmpty);
      }),
    );
  }

  test(
    'thread tail refresh retains accepted older history and its disk window',
    () => historyCase((w, client, db) async {
      await w.messageDomain.older(
        thread: true,
      ); // Empty page proves the beginning was reached.
      expect(w.threadHasMore, isFalse);
      await reopen(w);
      expect(w.replies.length, 100);
      expect(w.replies.first.id, 't-1');
      expect(w.threadHasMore, isFalse);
      await w.flushCache();
      final disk = await db.read(
        client.origin,
        'alice',
        'server',
        'thread-window',
        'b-100',
      ) as Map;
      expect((disk['messages'] as List).length, 100);
      await w.messageDomain.older(thread: true);
      expect(
        client.beforeReads.where((seq) => seq == BigInt.from(51)).length,
        1,
      );
    }),
  );

  test(
    'thread refresh removes deleted tail rows without dropping older history',
    () => historyCase((w, client, db) async {
      client.tailEnd = 110;
      client.removed = {95};
      await reopen(w);
      expect(w.replies.length, 109);
      expect(w.replies.first.id, 't-1');
      expect(w.replies.last.id, 't-110');
      expect(w.replies.any((m) => m.id == 't-95'), isFalse);
    }),
  );

  test(
    'thread history restriction replaces retained older rows',
    () => historyCase((w, client, db) async {
      client.historyRestricted = true;
      await reopen(w);
      expect(w.replies.length, 50);
      expect(w.replies.first.id, 't-51');
      expect(w.messageDomain.state.threadHistoryLimited, isTrue);
      expect(w.threadHasMore, isFalse);
    }),
  );

  test(
    'focused thread context is never merged into a later latest window',
    () => historyCase((w, client, db) async {
      client.tailEnd = 1000;
      await reopen(w, focus: 't-25');
      // The local context follows the mounted API's default 15 neighbours.
      expect(w.replies.map((m) => m.id), [
        for (var i = 10; i <= 40; i++) 't-$i',
      ]);
      await reopen(w);
      expect(w.replies.length, 50);
      expect(w.replies.first.id, 't-951');
    }),
  );

  test('restart keeps all saved thread history when the network answers immediately', () async {
    final dir = await Directory.systemTemp.createTemp('raft-thread-history-');
    final file = File('${dir.path}/workspace.sqlite');
    var db = DriftWorkspaceCache(NativeDatabase(file));
    var client = _HistoryThreadClient();
    var w = _controller(client, db);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.openThreadIdentity(
      parentChannelId: 'b',
      parentMessageId: 'b-100',
      initialThreadChannelId: 't',
      navigate: false,
    );
    await w.messageDomain.older(thread: true);
    await w.flushCache();
    expect(w.replies.length, 100);
    w.dispose();
    await client.eventsController.close();
    await db.close();
    db = DriftWorkspaceCache(NativeDatabase(file));
    client = _HistoryThreadClient();
    w = _controller(client, db);
    await w.openThreadIdentity(
      parentChannelId: 'b',
      parentMessageId: 'b-100',
      initialThreadChannelId: 't',
      navigate: false,
    );
    expect(w.replies.length, 100);
    expect(w.replies.first.id, 't-1');
    w.dispose();
    await client.eventsController.close();
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'offline thread refresh preserves its accepted history',
    () => historyCase((w, client, db) async {
      client.repliesFailure = const SocketException('synthetic offline');
      await reopen(w);
      expect(w.replies.length, 100);
      expect(w.replies.first.id, 't-1');
    }),
  );
  test(
    '1000 viewed replies remain locally pageable after an offline restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('raft-long-history-');
      final file = File('${dir.path}/workspace.sqlite');
      var db = DriftWorkspaceCache(NativeDatabase(file));
      var client = _HistoryThreadClient()..tailEnd = 1000;
      var w = _controller(client, db);
      try {
        await w.selectChannel(w.channels.last, autoRead: false);
        await w.openThreadIdentity(
          parentChannelId: 'b',
          parentMessageId: 'b-100',
          initialThreadChannelId: 't',
          navigate: false,
        );
        final viewed = <String>{};
        for (var i = 0; i <= 20; i++) {
          viewed.addAll(w.replies.map((m) => m.id));
          if (!w.threadHasMore) break;
          await w.messageDomain.older(thread: true);
        }
        expect(viewed.length, 1000);
        await w.flushCache();
        w.dispose();
        await client.eventsController.close();
        await db.close();
        db = DriftWorkspaceCache(NativeDatabase(file));
        client = _HistoryThreadClient()
          ..tailEnd = 1000
          ..repliesFailure = const SocketException('synthetic offline');
        w = _controller(client, db);
        await w.openThreadIdentity(
          parentChannelId: 'b',
          parentMessageId: 'b-100',
          initialThreadChannelId: 't',
          navigate: false,
        );
        final restored = <String>{};
        for (var i = 0; i <= 20; i++) {
          restored.addAll(w.replies.map((m) => m.id));
          if (!w.threadHasMore) break;
          await w.messageDomain.older(thread: true);
        }
        expect(restored.length, 1000);
        expect(restored, viewed);
        expect(
          client.beforeReads.where((cursor) => cursor != null),
          isEmpty,
          reason: 'Covered old pages must not wait for the network.',
        );
      } finally {
        await w.flushCache();
        w.dispose();
        await client.eventsController.close();
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('restart paints a visited thread from disk before its lookup', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    var client = _ThreadClient();
    var w = _controller(client, db);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.openThreadIdentity(
      parentChannelId: 'b',
      parentMessageId: 'b-100',
      navigate: false,
    );
    expect(w.replies.map((m) => m.id), ['t-1', 't-2']);
    await w.flushCache();
    expect(
      await db.read(client.origin, 'alice', 'server', 'thread-window', 'b-100'),
      isA<Map>(),
    );
    w.dispose();
    await client.eventsController.close();

    // Same account/server/role: the window and its parent paint at once.
    client = _ThreadClient()..hold = Completer<void>();
    w = _controller(client, db);
    final opening = w.openThreadIdentity(
      parentChannelId: 'b',
      parentMessageId: 'b-100',
      navigate: false,
    );
    await _until(() => w.replies.isNotEmpty);
    expect(w.replies.map((m) => m.id), ['t-1', 't-2']);
    expect(w.messageDomain.state.threadLoading, isFalse);
    expect(w.messageDomain.state.threadParent?.id, 'b-100');
    client.hold!.complete();
    await opening;
    expect(w.replies.map((m) => m.id), ['t-1', 't-2']);
    w.dispose();
    await client.eventsController.close();

    // A different role never adopts the stored thread window.
    client = _ThreadClient()..hold = Completer<void>();
    w = _controller(client, db)
      ..server = RaftRecord({'id': 'server', 'role': 'member'});
    final denied = w.openThreadIdentity(
      parentChannelId: 'b',
      parentMessageId: 'b-100',
      navigate: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(w.replies, isEmpty);
    expect(w.messageDomain.state.threadLoading, isTrue);
    client.hold!.complete();
    await denied;
    w.dispose();
    await client.eventsController.close();

    // Revoking the thread channel purges the stored window.
    await db.revokeChannel(client.origin, 'alice', 'server', 't');
    expect(
      await db.read(client.origin, 'alice', 'server', 'thread-window', 'b-100'),
      isNull,
    );
    await db.close();
  });
  test('restart hydrates a noninitial channel before pending HTTP and preserves older history', () async {
    final dir = await Directory.systemTemp.createTemp('raft-window-retention-');
    final file = File('${dir.path}/workspace.sqlite');
    var db = DriftWorkspaceCache(NativeDatabase(file));
    var client = _Client();
    var w = _controller(client, db);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.messageDomain.older();
    await w.flushCache();
    expect(w.messageDomain.messages.length, 100);
    w.dispose();
    await client.eventsController.close();
    await db.close();
    db = DriftWorkspaceCache(NativeDatabase(file));
    client = _Client()..pending = Completer<Map<String, dynamic>>();
    w = _controller(client, db);
    final hydrated = Completer<void>();
    w.addListener(() {
      if (w.messageDomain.messages.length == 100 && !hydrated.isCompleted) {
        hydrated.complete();
      }
    });
    final loading = w.selectChannel(w.channels.last, autoRead: false);
    await hydrated.future.timeout(const Duration(seconds: 3));
    expect(
      w.messageDomain.state.channelLoading,
      false,
      reason: 'Accepted cached rows are ready while HTTP validates in the background.',
    );
    expect(w.messageDomain.messages.first.id, 'b-1');
    client.pending!.complete({
      'messages': [for (var i = 51; i <= 100; i++) row(i)],
      'threadSummariesByParentMessageId': {},
    });
    await loading;
    expect(w.messageDomain.messages.length, 100);
    expect(w.messageDomain.messages.first.id, 'b-1');
    await w.flushCache();
    w.dispose();
    await client.eventsController.close();
    await db.close();
    await dir.delete(recursive: true);
  });
  for (final status in [403, 404]) {
    test('denial $status retains authored text and purges private state', () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory());
      final client = _Client();
      final w = _controller(client, db);
      addTearDown(() async {
        await w.flushCache();
        w.dispose();
        await client.eventsController.close();
        await client.dispose();
        await db.close();
      });
      final channel = w.channels.last;
      await w.selectChannel(channel, autoRead: false);
      w.saveDraft('My unsent words 草稿');
      w.composer.attempts[channel.id] = ComposerSendAttempt('old', 'retry-id');
      await db.write(client.origin, 'alice', 'server', 'attempt', channel.id, {
        'fingerprint': 'old',
        'randomId': 'retry-id',
        'channelId': channel.id,
      });
      final editor = w;
      await w.flushCache();
      expect(identical(editor.composer, w.composer), isTrue);
      expect(editor.messageDomain.messages, isNotEmpty);

      client.failure = RaftApiException('No channel access', status: status);
      await editor.selectChannel(channel, autoRead: false);
      await editor.flushCache();
      await w.flushCache();
      expect(editor.channel, isNull);
      expect(editor.messageDomain.messages, isEmpty);
      expect(editor.messageDomain.ledger.messages(channel.id), isEmpty);
      expect(w.composer.attempts.containsKey(channel.id), isFalse);
      expect(w.drafts[channel.id], 'My unsent words 草稿');
      expect(
        await db.read(client.origin, 'alice', 'server', 'window', channel.id),
        isNull,
      );
      expect(
        await db.read(client.origin, 'alice', 'server', 'attempt', channel.id),
        isNull,
      );
      final stored = await db.read(
        client.origin,
        'alice',
        'server',
        'draft',
        channel.id,
      ) as Map;
      expect(stored['text'], 'My unsent words 草稿');
      expect(stored['files'], isEmpty);
      expect(stored['shareTokens'], isNull);

      // A fresh controller restores only the user's words after access returns.
      client.failure = null;
      final restored = WorkspaceController(client, cache: db, ownsClient: false)
        ..server = w.server
        ..channels = w.channels;
      restored.messageDomain.ledger.switchServer('server');
      try {
        await restored.selectChannel(channel, autoRead: false);
        expect(restored.drafts[channel.id], 'My unsent words 草稿');
        expect(restored.composer.attempts, isEmpty);
      } finally {
        await restored.flushCache();
        restored.dispose();
      }
    });
  }

  test('accepted history survives transient refresh but denial revokes persisted and visible rows', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final client = _Client();
    final w = _controller(client, db);
    // Use the actual controller client; this helper keeps no authentication data.
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.messageDomain.older();
    client.failure = const RaftApiException('Unavailable', status: 503);
    await w.selectChannel(w.channels.last, autoRead: false);
    expect(w.messageDomain.messages.length, 100);
    client.failure = const RaftApiException('Denied', status: 403);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.flushCache();
    expect(w.messageDomain.messages, isEmpty);
    expect(
      await db.read(client.origin, 'alice', 'server', 'window', 'b'),
      isNull,
    );
    w.dispose();
    await client.eventsController.close();
    await db.close();
  });
  test('late HTTP cannot apply after role change and owner window is rejected under new role', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final current = _Client();
    final w = _controller(current, db);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.flushCache();
    current.pending = Completer<Map<String, dynamic>>();
    final first = w.selectChannel(w.channels.last, autoRead: false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    w.server = RaftRecord({'id': 'server', 'role': 'member'});
    w.notifyListeners();
    current.pending!.complete({
      'messages': [row(999)],
      'threadSummariesByParentMessageId': {},
    });
    await first;
    expect(w.messageDomain.messages.any((m) => m.id == 'b-999'), false);
    current.pending = null;
    current.failure = const RaftApiException('Unavailable', status: 503);
    await w.selectChannel(w.channels.last, autoRead: false);
    expect(
      w.messageDomain.messages,
      isEmpty,
      reason: 'Owner cache is not adopted with a new role',
    );
    w.dispose();
    await current.eventsController.close();
    await db.close();
  });
  test(
    'late disk-window read cannot reapply to a newer selected channel',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory());
      final cache = _DelayedCache(db), c = _Client();
      final w = _controller(c, cache);
      await w.selectChannel(w.channels.last, autoRead: false);
      await w.flushCache();
      cache.gate = Completer<void>();
      final old = w.selectChannel(w.channels.last, autoRead: false);
      await cache.entered.future.timeout(const Duration(seconds: 3));
      await w.selectChannel(w.channels.first, autoRead: false);
      expect(w.channel!.id, 'a');
      expect(w.messageDomain.messages.every((m) => m.channelId == 'a'), true);
      cache.gate!.complete();
      await old;
      expect(w.channel!.id, 'a');
      expect(w.messageDomain.messages.every((m) => m.channelId == 'a'), true);
      expect(w.messageDomain.state.channelLoading, false);
      w.dispose();
      await c.eventsController.close();
      await db.close();
    },
  );
  test('history-limited authoritative response hides previously accepted older range', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final c = _Client();
    final w = _controller(c, db);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.messageDomain.older();
    c.limited = true;
    await w.selectChannel(w.channels.last, autoRead: false);
    expect(w.messageDomain.messages.length, 50);
    expect(w.messageDomain.messages.first.id, 'b-51');
    expect(w.messageDomain.state.hasMore, false);
    w.dispose();
    await c.eventsController.close();
    await db.close();
  });
  test('fresh range removes deleted rows while preserving strictly older accepted history', () {
    expect(
      reconcileTailWindow(
        [row(1), row(51), row(52), row(200)],
        [row(51), row(53)],
      ),
      {'b-1', 'b-51', 'b-53'},
    );
    expect(reconcileTailWindow([row(1)], []), isEmpty);
    expect(acceptedWindowRows([row(1, channel: 'other')], 'b'), isEmpty);
    expect(acceptedWindowRows([row(1), row(1)], 'b'), isEmpty);
  });
}
