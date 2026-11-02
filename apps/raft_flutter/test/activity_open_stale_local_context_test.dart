// Reproduction for the Android single-pane Activity bug (candidate B): the
// jump to a long conversation's newest message is answered from the saved
// SQLite radius-15 page (MessageHistoryPages.load -> readContext) and the
// server is not asked because the saved range is younger than 24 hours. If the
// saved rows are not the server's current tail (a live event was missed, rows
// are not contiguous), the user gets a page without the newest messages, and
// every later locate returns the same page.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> _message(String channel, int seq) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': '$channel message $seq',
  'senderType': 'user',
  'senderId': 'alice',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://activity-local.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }

  final events$ = StreamController<RaftEvent>.broadcast(sync: true);
  final ends = {'alpha': 199, 'beta': 5};
  final contextCalls = <String>[];

  @override
  Stream<RaftEvent> get events => events$.stream;
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    final end = ends[id]!;
    final last = before != null ? before.toInt() - 1 : end;
    final first = after != null ? after.toInt() + 1 : (last - limit + 1);
    final from = first.clamp(1, end);
    final to = (after != null ? from + limit - 1 : last).clamp(0, end);
    return {
      'messages': [for (var n = from; n <= to; n++) _message(id, n)],
      'historyLimited': false,
    };
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final context = RegExp(r'^/messages/context/(\w+)-(\d+)$').firstMatch(path);
    if (context == null) return {};
    contextCalls.add(path);
    final channel = context[1]!, target = int.parse(context[2]!);
    final end = ends[channel]!;
    final from = (target - 15).clamp(1, end), to = (target + 15).clamp(1, end);
    return {
      'messages': [for (var n = from; n <= to; n++) _message(channel, n)],
      'targetMessageId': '$channel-$target',
      'hasOlder': from > 1,
      'hasNewer': to < end,
    };
  }
}

WorkspaceController _controller(_Client client, DriftWorkspaceCache cache) {
  final w = WorkspaceController(client, cache: cache)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channels = [
      RaftChannel({'id': 'alpha', 'type': 'private', 'joined': true}),
      RaftChannel({'id': 'beta', 'type': 'private', 'joined': true}),
    ];
  w.messageDomain.ledger.switchServer('server');
  return w;
}

void main() {
  // delivered: which of the two new messages (200, 201) reached this client as
  // live events before the Activity tap. 'newest-only' is a missed event.
  // readingUp: session 1 also paged older and saved a reading anchor, and
  // session 2 opens the conversation (retaining its window) before moving to
  // another item. Otherwise session 2 never opens it before the tap.
  for (final readingUp in [false, true]) {
    for (final delivered in ['both', 'newest-only', 'none']) {
      test(
        'jump to the newest message of a long conversation shows it with the preceding messages; readingUp=$readingUp, live events delivered: $delivered',
        () async {
          final client = _Client();
          final cache = DriftWorkspaceCache(NativeDatabase.memory());
          addTearDown(() async {
            await client.events$.close();
            await cache.close();
          });

          // Session 1: the user read the conversation's tail (saved to SQLite).
          final first = _controller(client, cache);
          await first.selectChannel(
            first.channels.first,
            navigate: false,
            autoRead: false,
          );
          if (readingUp) {
            await first.messageDomain.older();
            await first.messageDomain.older();
            first.messageDomain.saveReadingAnchor(
              'alpha',
              ReadingAnchor('alpha-120', -13),
            );
          }
          await first.flushCache();
          await cache.messageHistory.reads.settled;
          first.dispose();
          client.user = RaftRecord({'id': 'alice'}); // dispose signs out

          // The conversation gets two new messages on the server.
          client.ends['alpha'] = 201;
          client.contextCalls.clear();

          // Session 2 (fresh in-memory state, same database) sits on another
          // item when the live events arrive.
          final w = _controller(client, cache);
          addTearDown(() async {
            await w.flushCache();
            w.dispose();
          });
          if (readingUp) {
            await w.selectChannel(
              w.channels.first,
              navigate: false,
              autoRead: false,
            );
          }
          await w.selectChannel(
            w.channels.last,
            navigate: false,
            autoRead: false,
          );
          for (final n in switch (delivered) {
            'both' => [200, 201],
            'newest-only' => [201],
            _ => <int>[],
          }) {
            client.events$.add(RaftEvent('message:new', _message('alpha', n)));
          }
          await w.flushCache();
          await cache.messageHistory.reads.settled;

          // Activity row of the (read) conversation: target is lastMessageId.
          for (final attempt in [1, 2]) {
            await w.jumpToMessage('alpha', 'alpha-201', navigate: false);
            await cache.messageHistory.reads.settled;
            final ids = w.messageDomain.messages.map((m) => m.id).toList();
            final reason =
                'attempt $attempt window=${w.messageDomain.state.hasNewer ? 'has-newer' : 'tail'} visible=${ids.isEmpty ? ids : '${ids.first}..${ids.last} (${ids.length})'} '
                'contextGETs=${client.contextCalls.length}';
            expect(w.channel?.id, 'alpha', reason: reason);
            expect(
              w.messageDomain.state.channelLoading,
              isFalse,
              reason: reason,
            );
            expect(ids, contains('alpha-201'), reason: reason);
            expect(ids.last, 'alpha-201', reason: reason);
            expect(
              ids,
              contains('alpha-200'),
              reason: 'newest messages must be contiguous: $reason',
            );
            final seqs = [for (final id in ids) int.parse(id.split('-').last)];
            expect(
              [for (var i = 1; i < seqs.length; i++) seqs[i] - seqs[i - 1]],
              everyElement(1),
              reason: 'gap in the visible page: $reason',
            );
            expect(w.messageDomain.state.highlightedMessageId, 'alpha-201');
          }
        },
      );
    }
  }

  // Store-level contract behind MessageHistoryPages.load(focused: true): a
  // saved context page is either unavailable (null, so the wire is used) or a
  // contiguous run. Live-only rows must never be glued to older saved rows.
  for (final delivered in [
    [200, 201],
    [201],
  ]) {
    test('saved context page around live row $delivered has no hole', () async {
      final client = _Client();
      final cache = DriftWorkspaceCache(NativeDatabase.memory());
      addTearDown(() async {
        await client.events$.close();
        await cache.close();
      });
      final first = _controller(client, cache);
      await first.selectChannel(
        first.channels.first,
        navigate: false,
        autoRead: false,
      );
      await first.flushCache();
      await cache.messageHistory.reads.settled;
      first.dispose();
      client.user = RaftRecord({'id': 'alice'}); // dispose signs out
      client.ends['alpha'] = 201;
      final w = _controller(client, cache);
      addTearDown(() async {
        await w.flushCache();
        w.dispose();
      });
      await w.selectChannel(w.channels.last, navigate: false, autoRead: false);
      for (final n in delivered) {
        client.events$.add(RaftEvent('message:new', _message('alpha', n)));
      }
      await w.flushCache();
      await cache.messageHistory.reads.settled;
      final scope = MessageHistoryPages.scope(w, 'alpha')!;
      final page = await cache.messageHistory.readContext(scope, 'alpha-201');
      if (page == null) return; // wire fallback is the safe answer
      final seqs = [
        for (final row in page['messages'] as List)
          int.parse('${(row as Map)['seq']}'),
      ];
      expect(
        [for (var i = 1; i < seqs.length; i++) seqs[i] - seqs[i - 1]],
        everyElement(1),
        reason: 'saved context page has a hole: $seqs',
      );
      expect(seqs.last, 201);
    });
  }
}
