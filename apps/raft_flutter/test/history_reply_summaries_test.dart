import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/reading_positions.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_sync/raft_sync.dart' show threadRepliesProducer;
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_capacity_test.dart' as f;
import 'history_memory_viewport_test.dart' show drainIo;
import 'support/history_automatic_fixture.dart';

/// Inline reply previews ("N replies" under a parent) are part of the message
/// history: whatever the disk can show of a message, it shows with its
/// previews, in the same frame, and they leave the device with the message.
const _needle = 'REPLY-PREVIEW-NEEDLE';

Map<String, dynamic> _summary(String parent, int count, {int seq = 1}) => {
  'threadChannelId': 'thread-$parent',
  'replyCount': count,
  'latestReplies': [
    {
      'messageId': 'reply-$parent-$seq',
      'seq': seq,
      'senderType': 'user',
      'senderId': 'bob',
      'senderName': 'bob',
      'preview': '$_needle $parent #$seq',
      'createdAt': '2026-10-10T02:31:00Z',
    },
  ],
};

Map<String, dynamic> _frame(String parent, int count, int seq) => {
  'parentMessageId': parent,
  'threadChannelId': 'thread-$parent',
  'replyCount': count,
  'lastReplyAt': '2026-10-10T02:31:00Z',
  'participantIds': ['bob'],
  'latestReply': {
    'id': 'reply-$parent-$seq',
    'seq': seq,
    'content': '$_needle $parent #$seq',
    'senderType': 'user',
    'senderId': 'bob',
    'senderName': 'bob',
    'createdAt': '2026-10-10T02:31:00Z',
    'conversationContext': {
      'channelType': 'thread',
      'parentMessageId': parent,
      'parentChannelId': 'chat',
      'parentChannelType': 'private',
    },
  },
  'syncCoreReplyWindow': {
    'producer': threadRepliesProducer,
    'discussion': {
      'root': {'kind': 'message', 'serverId': 'server', 'id': parent},
      'relation': {'kind': 'replies'},
      'backing': 'sync-scope',
      'parentScopeKey': {
        'serverId': 'server',
        'scopeKind': 'private',
        'scopeId': 'chat',
      },
    },
    'window': {
      'kind': 'sync-scope-window',
      'scopeCursor': null,
      'epoch': 'one',
    },
  },
};

/// The server sends a parent's summary with the page that carries the parent.
class _Client extends HistoryAuditClient {
  final wire = <String, Map<String, dynamic>>{};
  final threadReads = <String>[];

  Map<String, dynamic> _only(Map<String, dynamic> page) {
    final ids = {for (final m in page['messages'] as List) m['id']};
    return {
      ...page,
      'threadSummariesByParentMessageId': {
        for (final e in wire.entries)
          if (ids.contains(e.key)) e.key: e.value,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async => _only(
    await super.messagePage(id, before: before, after: after, limit: limit),
  );

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.contains('/threads/') ||
        path.startsWith('/messages/channel/thread')) {
      threadReads.add(path);
    }
    final value = await super.get(path, query: query);
    return path.startsWith('/messages/context/') && value is Map
        ? _only(Map<String, dynamic>.from(value))
        : value;
  }
}

/// One app run against the device database file.
class _Run {
  _Run(this.file, this.wire)
    : client = _Client()..wire.addAll(wire),
      cache = DriftWorkspaceCache(
        NativeDatabase(file),
        automaticHistoryMaintenance: false,
      ) {
    w = WorkspaceController(client, cache: cache)
      ..messageDomain.ledger.switchServer('server')
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'chat', 'type': 'private', 'joined': true}),
      ];
  }
  final File file;
  final Map<String, Map<String, dynamic>> wire;
  final _Client client;
  final DriftWorkspaceCache cache;
  late final WorkspaceController w;

  Map<String, dynamic> get summaries =>
      w.messageDomain.threadSummariesFor('chat');

  /// Opens the channel; with [offline] the network never answers, so only
  /// what the device holds can be on screen.
  Future<void> open({bool offline = false}) async {
    if (offline) client.gate = Completer<void>();
    final opening = w.selectChannel(w.channels.single, autoRead: false);
    pending.add(opening);
    for (var i = 0; i < 400 && w.messageDomain.messages.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (!offline) await opening;
  }

  final pending = <Future<void>>[];

  Future<void> settle() async {
    await cache.messageHistory.receiver.settled;
    await cache.messageHistory.reads.settled;
    await w.flushCache();
  }

  Future<void> close() async {
    if (client.gate?.isCompleted == false) client.gate!.complete();
    for (final p in pending) {
      await p.catchError((Object _) {});
    }
    await settle();
    w.dispose();
    await client.incoming.close();
    await client.dispose();
    await cache.close();
  }
}

/// Counts text cells holding [needle]. With [historyOnly] the old-release
/// rollback copy (workspace_cache window rows, bounded by its own rules) is
/// ignored: only the additive history store is looked at.
Future<int> _leaks(
  DriftWorkspaceCache cache, [
  String needle = _needle,
  bool historyOnly = false,
]) async {
  var found = 0;
  final tables = await cache
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  for (final table in tables) {
    final name = table.read<String>('name');
    final columns = await cache
        .customSelect('PRAGMA table_info("$name")')
        .get();
    for (final column in columns) {
      final c = column.read<String>('name');
      if (historyOnly &&
          !name.startsWith('raft_history_') &&
          name != 'workspace_cache') {
        continue;
      }
      final hits = await cache
          .customSelect(
            'SELECT count(*) AS n FROM "$name" WHERE CAST("$c" AS TEXT) LIKE ?'
            '${historyOnly && name == 'workspace_cache' ? " AND kind='message-history'" : ''}',
            variables: [Variable('%$needle%')],
          )
          .getSingle();
      found += hits.read<int>('n');
    }
  }
  return found;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('raft-reply-summaries-');
    file = File('${dir.path}/workspace.sqlite');
  });
  tearDown(() => dir.delete(recursive: true));

  /// Last session: the member scrolled back through both pages of a channel
  /// whose parents m25 (older page) and m100 (latest page) have replies.
  Future<Map<String, Map<String, dynamic>>> lastSession({
    Future<void> Function(_Run)? before,
  }) async {
    final wire = {'m25': _summary('m25', 3), 'm100': _summary('m100', 5)};
    final run = _Run(file, wire);
    await run.open();
    await run.w.messageDomain.older();
    await run.settle();
    expect(run.w.messageDomain.messages.length, 100);
    expect(run.summaries.keys, containsAll(['m25', 'm100']));
    await before?.call(run);
    await run.close();
    return wire;
  }

  test(
    'cold open from disk has the previews before the network answers',
    () async {
      // Initial: previous run saw the channel and its previews; app restarted.
      // Event: channel opens, the server has not answered.
      // Expected: the latest page is on screen with its previews.
      final wire = await lastSession();
      final run = _Run(file, wire);
      addTearDown(run.close);
      await run.open(offline: true);
      expect(run.w.messageDomain.messages, isNotEmpty);
      expect(run.client.gate?.isCompleted, isFalse, reason: 'no answer yet');
      expect(run.summaries['m100']?['replyCount'], 5);
      expect(
        run.w.messageDomain.threadSummaries['m100']?['latestReplies'],
        hasLength(1),
      );
    },
  );

  test('an older page served from disk brings its previews', () async {
    // Initial: restarted; the latest page was revalidated by the network,
    // which only describes its own rows. Event: the member scrolls back and
    // the older page comes from the device, offline.
    // Expected: its parent shows the same previews it had before.
    final wire = await lastSession(
      before: (run) async {
        // The device keeps all 100 rows but this run held only the latest 50
        // when it left (memory release), as on a long-lived session.
        for (var i = 1; i <= 50; i++) {
          run.w.messageDomain.ledger.remove('chat', 'm$i');
          run.w.messageDomain.visibleIds['chat']?.remove('m$i');
        }
        run.w.messageDomain.state.hasMore = true;
        await run.w.messageDomain.saveHistoryWindow('chat');
      },
    );
    final run = _Run(file, wire);
    addTearDown(run.close);
    await run.open();
    expect(run.w.messageDomain.messages.length, lessThanOrEqualTo(100));
    for (var i = 1; i <= 50; i++) {
      run.w.messageDomain.ledger.remove('chat', 'm$i');
      run.w.messageDomain.visibleIds['chat']?.remove('m$i');
    }
    run.w.messageDomain.state.hasMore = true;
    run.client.gate = Completer<void>();
    await run.w.messageDomain.older();
    expect(run.w.messageDomain.messages.any((m) => m.id == 'm25'), isTrue);
    expect(
      run.client.calls.where((c) => c.startsWith('page:')).length,
      lessThan(2),
    );
    expect(run.summaries['m25']?['replyCount'], 3);
  });

  test(
    'restoring the saved reading position shows the previews of its rows',
    () async {
      // Initial: last run left the member reading around m25.
      // Event: restart; the channel opens at the saved position, offline.
      // Expected: m25 shows its previews in the first frame.
      final wire = await lastSession(
        before: (run) async {
          final scope = MessageHistoryPages.scope(run.w, 'chat')!;
          await run.cache.messageHistory.savePosition(
            scope,
            SavedReadingPosition('m25', BigInt.from(25), 0),
          );
        },
      );
      final run = _Run(file, wire);
      addTearDown(run.close);
      await run.open(offline: true);
      expect(run.w.messageDomain.messages.any((m) => m.id == 'm25'), isTrue);
      expect(run.w.messageDomain.messages.any((m) => m.id == 'm100'), isFalse);
      expect(run.summaries['m25']?['replyCount'], 3);
    },
  );

  test(
    'a reply that arrives live updates the parent without a refetch',
    () async {
      // Initial: opened from disk, offline. Event: a thread:updated frame.
      // Expected: count and latest reply change at once; nothing is fetched.
      final wire = await lastSession();
      final run = _Run(file, wire);
      addTearDown(run.close);
      await run.open(offline: true);
      run.client.incoming.add(
        RaftEvent('thread:updated', _frame('m100', 6, 2)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(run.summaries['m100']?['replyCount'], 6);
      expect(
        (run.summaries['m100']?['latestReplies'] as List).last['preview'],
        '$_needle m100 #2',
      );
      expect(run.client.threadReads, isEmpty);
    },
  );

  test('a live reply is still there after a restart', () async {
    // Initial: a reply arrived while the channel was open.
    // Event: restart, offline. Expected: the new count, not the old one.
    final wire = await lastSession(
      before: (run) async {
        run.client.incoming.add(
          RaftEvent('thread:updated', _frame('m100', 6, 2)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(run.summaries['m100']?['replyCount'], 6);
      },
    );
    final run = _Run(file, wire);
    addTearDown(run.close);
    await run.open(offline: true);
    expect(run.summaries['m100']?['replyCount'], 6);
  });

  test('the server answer replaces what the device had', () async {
    // Initial: device has m100 with 5 replies. Event: server now says 9.
    // Expected: screen and, after a restart, the device follow the server.
    await lastSession();
    final run = _Run(file, {'m100': _summary('m100', 9, seq: 3)});
    await run.open();
    await run.settle();
    expect(run.summaries['m100']?['replyCount'], 9);
    await run.close();
    final again = _Run(file, {});
    addTearDown(again.close);
    await again.open(offline: true);
    expect(again.summaries['m100']?['replyCount'], 9);
  });

  group('previews leave the device with their messages', () {
    for (final (name, revoke) in <(String, Future<void> Function(_Run))>[
      (
        'channel removed',
        (run) async {
          run.client.incoming.add(
            const RaftEvent('channel:removed', {'channelId': 'chat'}),
          );
          await run.w.flushCache();
        },
      ),
      (
        'channel revoked on the device',
        (run) => run.cache.revokeChannel(
          run.client.origin,
          'alice',
          'server',
          'chat',
        ),
      ),
      (
        'server revoked',
        (run) => run.cache.revokeServer(run.client.origin, 'alice', 'server'),
      ),
      ('sign-out', (run) => run.cache.clearAccount(run.client.origin, 'alice')),
    ]) {
      test(name, () async {
        // Initial: the device holds rows and previews. Event: access ends.
        // Expected: no trace of a preview remains in any table.
        final wire = await lastSession();
        final run = _Run(file, wire);
        addTearDown(run.close);
        await run.open(offline: true);
        await revoke(run);
        await run.settle();
        expect(await _leaks(run.cache), 0);
      });
    }

    test('parent message evicted from the device', () async {
      // Initial: m25 has previews on the device. Event: its row is evicted.
      // Expected: its previews go with it; other parents keep theirs.
      await lastSession();
      final cache = DriftWorkspaceCache(
        NativeDatabase(file),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      await cache.messageHistory.receiverRevision(
        MessageHistoryScope(
          origin: 'https://verify.invalid',
          principal: 'alice',
          server: 'server',
          channel: 'chat',
          parentChannel: 'chat',
          authority: 'owner',
        ),
      );
      await cache.customStatement(
        "UPDATE raft_history_rows SET tombstone=2, payload='{}' WHERE message_id='m25'",
      );
      expect(await _leaks(cache, 'm25 #1', true), 0);
      expect(await _leaks(cache, 'm100 #1', true), greaterThan(0));
    });
  });

  group('upgrade', () {
    test('last release window keeps its previews and rows', () async {
      // Initial: the previous release saved a window with a preview in its
      // JSON snapshot. Event: this release opens that database.
      // Expected: rows and preview readable at once and, once migrated,
      // from the history store; nothing is lost or invented.
      var cache = DriftWorkspaceCache(
        NativeDatabase(file),
        automaticHistoryMaintenance: false,
      );
      final window = jsonEncode({
        'version': 1,
        'windowKind': 'tail',
        'authority': 'member',
        'parentChannelId': 'chat',
        'messages': f.rows('chat', 1, 3, bytes: 8),
        'hasMore': false,
        'historyLimited': false,
        'threadSummaries': {'chat-2': _summary('chat-2', 4)},
      });
      // Straight into the v2 table: no history store has seen this window.
      await cache.customStatement(
        'INSERT INTO workspace_cache VALUES(?,?,?,?,?,?)',
        [f.account.origin, 'alice', 'one', 'window', 'chat', window],
      );
      final opened = await cache.read(
        f.account.origin,
        'alice',
        'one',
        'window',
        'chat',
      );
      expect((opened['messages'] as List), hasLength(3));
      expect(opened['threadSummaries']['chat-2']['replyCount'], 4);
      await cache.messageHistory.receiver.settled;
      await cache.close();
      cache = DriftWorkspaceCache(
        NativeDatabase(file),
        automaticHistoryMaintenance: false,
      );
      addTearDown(() => cache.close());
      final page = await cache.messageHistory.readPage(f.scope('chat'));
      expect(page?.rows, hasLength(3));
      expect(page?.summaries['chat-2']?['replyCount'], 4);
    });

    test(
      'a history store from before the previews table gains it without loss',
      () async {
        // Initial: a history database created by the build before this one.
        // Event: this build opens it. Expected: rows intact, previews work.
        var cache = DriftWorkspaceCache(
          NativeDatabase(file),
          automaticHistoryMaintenance: false,
        );
        await f.store(cache, f.scope('chat'), f.rows('chat', 1, 3, bytes: 8));
        await cache.customStatement('DROP TABLE raft_history_summaries');
        for (final trigger in [
          'raft_history_summaries_row_gone',
          'raft_history_summaries_row_retired',
          'raft_history_summaries_purge',
        ]) {
          await cache.customStatement('DROP TRIGGER $trigger');
        }
        await cache.close();
        cache = DriftWorkspaceCache(
          NativeDatabase(file),
          automaticHistoryMaintenance: false,
        );
        addTearDown(() => cache.close());
        expect(
          (await cache.messageHistory.readPage(f.scope('chat')))?.rows,
          hasLength(3),
        );
        await cache.messageHistory.saveSummaries(f.scope('chat'), {
          'chat-2': _summary('chat-2', 2),
          'not-here': _summary('not-here', 2),
        });
        final page = await cache.messageHistory.readPage(f.scope('chat'));
        expect(page?.summaries.keys, ['chat-2']);
      },
    );
  });

  testWidgets(
    'the first frame of a restarted channel has the inline previews',
    (tester) async {
      // Initial: restarted app, server silent. Event: first frame of the chat.
      // Expected: the preview block of the newest parent is already drawn.
      SharedPreferences.setMockInitialValues({});
      late _Run run;
      await tester.runAsync(() async {
        final wire = await lastSession();
        run = _Run(file, wire);
        await run.open(offline: true);
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(body: RaftChatView(controller: run.w)),
          ),
        );
        // One layout pass, no time elapsed: the list builds its rows.
        await tester.pump();
        expect(
          find.byKey(const ValueKey('inline-thread-m100')),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await drainIo(tester, run.close());
      }
    },
  );
}
