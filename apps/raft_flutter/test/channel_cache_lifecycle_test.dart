import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;

/// A client whose socket events the test drives.
class _EventClient extends RaftClient {
  _EventClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void emit(String name, dynamic payload) =>
      stream.add(RaftEvent(name, payload));
}

final _c1 = RaftChannel({'id': 'c1', 'name': 'design', 'joined': true});
final _c2 = RaftChannel({
  'id': 'c2',
  'name': 'secret',
  'type': 'private',
  'joined': true,
});
final _c3 = RaftChannel({'id': 'c3', 'name': 'release', 'joined': true});
final _lobby = RaftChannel({'id': 'lobby', 'name': 'lobby', 'joined': false});

Map<String, dynamic> _row(
  String id,
  String channel,
  int seq, {
  String sender = 'bob',
}) => {
  'id': id,
  'channelId': channel,
  'seq': '$seq',
  'senderId': sender,
  'senderType': 'user',
  'senderName': sender,
  'content': 'Body $id',
  'createdAt': '2026-10-10T02:30:00Z',
};

Map<String, dynamic> _summary(String thread, int count) => {
  'threadChannelId': thread,
  'replyCount': count,
  'latestReplies': [
    {
      'messageId': '$thread-r',
      'senderType': 'user',
      'senderId': 'bob',
      'senderName': 'bob',
      'preview': 'Reply in $thread',
      'createdAt': '2026-10-10T02:31:00Z',
    },
  ],
};

/// One page per channel: a parent with an inline reply surface.
Map<String, dynamic> _page(String channel, int seq) => {
  'messages': [_row('p-$channel', channel, seq)],
  'threadSummariesByParentMessageId': {'p-$channel': _summary('t-$channel', 2)},
};

Future<(WorkspaceController, MessageAdapter, _EventClient)> _login() async {
  final a = MessageAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes['GET /agents'] = (_) => [];
  a.routes['GET /servers/s1/members'] = (_) => [];
  a.routes['GET /channels'] = (_) => [
    for (final c in [_c1, _c2, _c3, _lobby]) c.json,
  ];
  a.routes['GET /channels/dm'] = (_) => [];
  a.routes['GET /channels/unread'] = (_) => {'channels': {}};
  var seq = 10;
  for (final id in ['c1', 'c2', 'c3']) {
    final base = seq += 10;
    a.routes['GET /messages/channel/$id'] = (_) => _page(id, base);
    a.routes['POST /channels/$id/read'] = (_) => {};
  }
  final client = _EventClient(a);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'member'});
  w.channels = [_c1, _c2, _c3, _lobby];
  w.channel = _c1;
  w.ledger.switchServer('s1');
  return (w, a, client);
}

int _unreadReads(MessageAdapter a) =>
    a.calls.where((c) => c.path == '/channels/unread').length;

Future<void> _drain() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// Opens the thread under c1's parent and lets it settle.
Future<void> _openThread(WorkspaceController w, MessageAdapter a) async {
  a.routes['GET /messages/channel/t-c1'] = (_) => {
    'messages': [_row('t-c1-r', 't-c1', 100)],
  };
  a.routes['POST /channels/t-c1/read'] = (_) => {};
  await w.openThreadIdentity(
    parentChannelId: 'c1',
    parentMessageId: 'p-c1',
    initialThreadChannelId: 't-c1',
  );
  await _drain();
}

/// Starts a revisit of [channel] whose network page never arrives, and
/// reports what the first synchronous projection shows.
({List<String> rows, bool summary}) _revisitHeld(
  WorkspaceController w,
  MessageAdapter a,
  RaftChannel channel,
) {
  a.routes['GET /messages/channel/${channel.id}'] = (_) =>
      Completer<Map<String, dynamic>>().future;
  unawaited(w.selectChannel(channel, autoRead: false));
  return (
    rows: w.messages.map((m) => m.id).toList(),
    summary: w.threadSummaries['p-${channel.id}'] != null,
  );
}

void main() {
  group('per-channel authority invalidation', () {
    test('an unrelated channel membership/authority change keeps every other cache', () async {
      final (w, a, client) = await _login();
      addTearDown(w.dispose);
      await w.selectChannel(_c3, autoRead: false);
      await w.selectChannel(_c1, autoRead: false);
      await _openThread(w, a);
      expect(w.threadIdentity?.parentMessageId, 'p-c1');
      expect(w.replies.map((m) => m.id), ['t-c1-r']);

      // Private c2's member list, c3's own authority and c1's public
      // member list: none of them changes who may read c1.
      client.emit('channel:members-updated', {'channelId': 'c2'});
      client.emit('channel:authority-updated', {
        'channelId': 'c3',
        'channelRole': 'member',
      });
      client.emit('channel:members-updated', {'channelId': 'c1'});
      await _drain();
      expect(w.threadIdentity?.parentMessageId, 'p-c1');
      expect(w.threadSummaries['p-c1'], isNotNull);

      // The open thread's cached window survives a close and reopen.
      w.closeThread();
      a.routes['GET /messages/channel/t-c1'] = (_) =>
          Completer<Map<String, dynamic>>().future;
      unawaited(
        w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'p-c1',
          initialThreadChannelId: 't-c1',
        ),
      );
      expect(w.threadLoading, isFalse, reason: 'cached thread window');
      expect(w.replies.map((m) => m.id), ['t-c1-r']);
      w.closeThread();

      // c1 keeps its window and reply rows across a switch away and back.
      await w.selectChannel(_c2, autoRead: false);
      final back = _revisitHeld(w, a, _c1);
      expect(back.rows, ['p-c1']);
      expect(back.summary, isTrue);
    });

    test('a channel whose authority changed drops its own data at once; others keep theirs', () async {
      final (w, a, client) = await _login();
      addTearDown(w.dispose);
      await w.selectChannel(_c3, autoRead: false);
      await w.selectChannel(_c2, autoRead: false);
      await w.selectChannel(_c1, autoRead: false);
      await _openThread(w, a);
      expect(w.threadIdentity, isNotNull);

      // Targeted authority change for c1: its thread identity and in-flight
      // loads are retired immediately, before the directory refresh.
      client.emit('channel:authority-updated', {
        'channelId': 'c1',
        'channelRole': 'viewer',
      });
      expect(w.threadIdentity, isNull);

      // Private c2's member list changed: it may have been this principal.
      client.emit('channel:members-updated', {'channelId': 'c2'});
      await _drain();

      final c2 = _revisitHeld(w, a, _c2);
      expect(c2.rows, isEmpty, reason: 'membership-scoped window dropped');
      expect(c2.summary, isFalse);
      final c3 = _revisitHeld(w, a, _c3);
      expect(c3.rows, ['p-c3'], reason: 'unrelated window kept');
      expect(c3.summary, isTrue);
      final c1 = _revisitHeld(w, a, _c1);
      expect(c1.rows, isEmpty, reason: 'authority-changed window dropped');
      expect(c1.summary, isFalse);
    });

    test(
      'an authority event without a channel id fails closed for every channel',
      () async {
        final (w, a, client) = await _login();
        addTearDown(w.dispose);
        await w.selectChannel(_c3, autoRead: false);
        await w.selectChannel(_c1, autoRead: false);
        client.emit('channel:members-updated', {});
        await _drain();
        expect(_revisitHeld(w, a, _c3).rows, isEmpty);
      },
    );

    test('a removed channel drops its window and summaries', () async {
      final (w, a, client) = await _login();
      addTearDown(w.dispose);
      await w.selectChannel(_c2, autoRead: false);
      await w.selectChannel(_c1, autoRead: false);
      client.emit('channel:removed', {'channelId': 'c2'});
      await _drain();
      expect(w.threadSummariesFor('c2'), isEmpty);
      expect(w.visibleIds['c2'], isNull);
      expect(w.threadSummaries['p-c1'], isNotNull);
    });
  });

  group('thread summaries per channel', () {
    test('prefetch fills summaries; first open and revisit project them before the network', () async {
      final (w, a, client) = await _login();
      addTearDown(w.dispose);
      await w.selectChannel(_c1, autoRead: false);
      w.unread = {'c3': 2};
      await w.prefetchLikelyChannels();
      expect(w.threadSummariesFor('c3')['p-c3'], isNotNull);

      final first = _revisitHeld(w, a, _c3);
      expect(first.rows, ['p-c3']);
      expect(first.summary, isTrue);

      // A live thread:updated for the non-selected c1 patches c1's bucket.
      client.emit('thread:updated', {
        'parentMessageId': 'p-c1',
        'threadChannelId': 't-c1',
        'replyCount': 5,
        'latestReply': {
          ..._row('t-c1-r5', 't-c1', 200),
          'conversationContext': {
            'channelType': 'thread',
            'parentMessageId': 'p-c1',
            'parentChannelId': 'c1',
            'parentChannelType': 'channel',
          },
        },
      });
      expect(w.threadSummaries['p-c1'], isNull);
      expect(w.threadSummariesFor('c1')['p-c1']['replyCount'], 5);

      a.routes['GET /messages/channel/c1'] = (_) =>
          Completer<Map<String, dynamic>>().future;
      unawaited(w.selectChannel(_c1, autoRead: false));
      expect(w.threadSummaries['p-c1']['replyCount'], 5);
    });

    test(
      'jumping to a cached message keeps the destination summaries',
      () async {
        final (w, a, _) = await _login();
        addTearDown(w.dispose);
        await w.selectChannel(_c3, autoRead: false);
        await w.selectChannel(_c1, autoRead: false);
        await w.jumpToMessage('c3', 'p-c3', navigate: false);
        expect(w.channel?.id, 'c3');
        expect(w.threadSummaries['p-c3'], isNotNull);
      },
    );
  });

  group('unread counts move per event', () {
    test(
      'message:new counts locally; own, duplicate, edits and unjoined do not',
      () async {
        final (w, a, client) = await _login();
        addTearDown(w.dispose);
        await w.selectChannel(_c1, autoRead: false);
        w.unread = {'c2': 1};
        final reads = _unreadReads(a);

        client.emit('message:new', _row('n1', 'c2', 500));
        expect(w.unread['c2'], 2);
        client.emit('message:new', _row('n1', 'c2', 500));
        expect(w.unread['c2'], 2, reason: 'redelivery counts once');
        client.emit('message:updated', {..._row('n1', 'c2', 500), 'x': 1});
        expect(w.unread['c2'], 2, reason: 'an edit is not a new message');
        client.emit('message:new', _row('mine', 'c2', 501, sender: 'alice'));
        expect(w.unread['c2'], 2, reason: 'own message');
        client.emit('message:new', _row('n2', 'c3', 502));
        expect(w.unread['c3'], 1);
        client.emit('message:new', _row('n3', 'lobby', 503));
        expect(w.unread['lobby'], isNull, reason: 'not joined');
        client.emit('message:new', _row('n4', 'stranger-thread', 504));
        expect(w.unread['stranger-thread'], isNull, reason: 'untracked');
        await _drain();
        expect(_unreadReads(a), reads, reason: 'no snapshot GET per event');
      },
    );

    test(
      'read_state:updated clears a count at the latest activity without a GET',
      () async {
        final (w, a, client) = await _login();
        addTearDown(w.dispose);
        await w.selectChannel(_c1, autoRead: false);
        w.unread = {'c2': 0};
        client.emit('message:new', _row('n1', 'c2', 600));
        client.emit('message:new', _row('n2', 'c2', 610));
        client.emit('message:new', _row('n3', 'c2', 620));
        expect(w.unread['c2'], 3);
        final reads = _unreadReads(a);
        client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': 'c2',
          'maxReadSeq': 610,
          'readStateVersion': 1,
        });
        expect(w.unread['c2'], 1, reason: 'held messages cover the frontier');
        client.emit('read_state:updated_bulk', {
          'serverId': 's1',
          'scopes': [
            {'scopeId': 'c2', 'maxReadSeq': 620, 'readStateVersion': 2},
          ],
        });
        expect(w.unread['c2'], 0);
        await _drain();
        expect(_unreadReads(a), reads);
      },
    );

    test('connect reconciles with the unread snapshot', () async {
      final (w, a, client) = await _login();
      addTearDown(w.dispose);
      a.routes['GET /servers'] = (_) => [
        {'id': 's1', 'role': 'member'},
      ];
      a.routes['GET /servers/s1/sidebar-order'] = (_) => {};
      a.routes['GET /channels/unread'] = (_) => {
        'channels': {'c3': 4},
      };
      final reads = _unreadReads(a);
      client.emit('connected', null);
      await _drain();
      expect(_unreadReads(a), reads + 1);
      expect(w.unread['c3'], 4);
    });
  });

  testWidgets(
    'channel switch: reply rows are on screen at the first frame and stay put',
    (t) async {
      final (w, a, client) = (await t.runAsync(_login))!;
      addTearDown(w.dispose);
      Future<void> settle() async {
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 10));
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        await t.pump();
      }

      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      // Visit c1 and c3 so both hold accepted windows, then prefetch c2.
      for (final c in [_c1, _c3]) {
        unawaited(w.selectChannel(c, autoRead: false));
        await settle();
      }
      w.unread = {'c2': 1};
      await t.runAsync(w.prefetchLikelyChannels);
      await settle();

      for (final target in [_c1, _c2]) {
        final row = find.byKey(ValueKey('message-p-${target.id}'));
        final replies = find.byKey(ValueKey('inline-thread-p-${target.id}'));
        final page = Completer<Map<String, dynamic>>();
        a.routes['GET /messages/channel/${target.id}'] = (_) => page.future;
        unawaited(w.selectChannel(target, autoRead: false));
        for (var i = 0; i < 10 && row.evaluate().isEmpty; i++) {
          await t.pump();
        }
        expect(row, findsOneWidget, reason: '${target.id} cached rows');
        expect(replies, findsOneWidget, reason: '${target.id} first frame');
        final rects = (t.getRect(row), t.getRect(replies));
        for (var frame = 0; frame < 6; frame++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(
            (t.getRect(row), t.getRect(replies)),
            rects,
            reason: '${target.id} frame $frame',
          );
        }
        // The background refresh lands with the same data: nothing moves.
        page.complete(_page(target.id, target.id == 'c1' ? 20 : 30));
        await settle();
        expect((t.getRect(row), t.getRect(replies)), rects);
        expect(find.textContaining('Reply in t-${target.id}'), findsOneWidget);
      }

      await t.pumpWidget(const SizedBox());
      await t.runAsync(client.stream.close);
      expect(t.takeException(), isNull);
    },
  );
}
