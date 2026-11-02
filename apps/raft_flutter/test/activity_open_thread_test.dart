// Reproduction tests for the Activity open path of a *thread* row (mobile
// single pane): WorkspaceView.openCanonicalActivity -> closeThread,
// resolveConversationChannel, openThreadIdentity(focusedMessageId: latest).
// Contract: after any tap the thread shows the focused (newest) reply last,
// is not loading, has no error, and tapping again / switching between a thread
// row and a channel row any number of times keeps working.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/activity_destination.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> _message(String channel, int seq) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': '$channel message $seq',
  'senderType': 'user',
  'senderId': 'alice',
};

/// Channels: alpha (parent channel, message alpha-100 owns thread tA),
/// beta (plain channel). tA is long; ends grow when "new replies" arrive.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://activity-thread.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }

  final events$ = StreamController<RaftEvent>.broadcast(sync: true);
  final ends = {'alpha': 200, 'beta': 60, 'tA': 120};
  final calls = <String>[];
  int failContext = 0; // next N thread-context GETs fail with failStatus
  int failStatus = 500;
  Completer<void>? gate; // holds thread-context GETs
  Completer<void>? started;

  @override
  Stream<RaftEvent> get events => events$.stream;
  @override
  void joinChannel(String id) {}
  @override
  void leaveChannel(String id) {}
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('page:$id');
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
    if (path == '/channels/alpha/threads/alpha-100') {
      calls.add('lookup');
      return {'threadChannelId': 'tA'};
    }
    final context = RegExp(r'^/messages/context/(\w+)-(\d+)$').firstMatch(path);
    if (context == null) return {};
    final target = int.parse(context[2]!);
    final channel = query?['channelId'] as String? ?? context[1]!;
    final end = ends[channel]!;
    if (query?['before'] == 0) {
      calls.add('parent');
      return {
        'messages': [_message(context[1]!, target)],
        'targetMessageId': '${context[1]}-$target',
        'hasOlder': true,
        'hasNewer': true,
      };
    }
    calls.add('context:$channel:$target');
    if (started case final s? when !s.isCompleted) s.complete();
    await gate?.future;
    if (channel == 'tA' && failContext > 0) {
      failContext--;
      throw RaftApiException('Boom', status: failStatus);
    }
    final from = (target - 15).clamp(1, end), to = (target + 15).clamp(1, end);
    return {
      'messages': [for (var n = from; n <= to; n++) _message(channel, n)],
      'targetMessageId': '$channel-$target',
      'hasOlder': from > 1,
      'hasNewer': to < end,
    };
  }
}

class _Case {
  _Case({_Client? client, DriftWorkspaceCache? cache})
    : client = client ?? _Client(),
      cache = cache ?? DriftWorkspaceCache(NativeDatabase.memory()) {
    w.messageDomain.ledger.switchServer('server');
  }
  final _Client client;
  final DriftWorkspaceCache cache;
  late final WorkspaceController w = WorkspaceController(client, cache: cache)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channels = [
      RaftChannel({'id': 'alpha', 'type': 'private', 'joined': true}),
      RaftChannel({'id': 'beta', 'type': 'private', 'joined': true}),
    ];

  Map<String, dynamic> threadRow(int latest, {int unread = 0}) => {
    'kind': 'thread',
    'parentChannelId': 'alpha',
    'parentMessageId': 'alpha-100',
    'threadChannelId': 'tA',
    'unreadCount': unread,
    'latestActivityMessageId': 'tA-$latest',
    if (unread > 0) 'firstUnreadMessageId': 'tA-${latest - unread + 1}',
  };

  Map<String, dynamic> channelRow(String id) => {
    'kind': 'channel',
    'channelId': id,
    'unreadCount': 0,
    'lastMessageId': '$id-${client.ends[id]}',
  };

  /// WorkspaceView.openCanonicalActivity(row, single: true), verbatim order.
  Future<void> tap(Map<String, dynamic> row) async {
    final target = ActivityDestination.fromRow(
      row,
      canonical: false,
      mobile: true,
    )!;
    w.navigation.navigate(target.canonicalLocation(w.location.serverSlug));
    w.closeThread(navigate: false);
    if (target.thread) {
      unawaited(
        w.resolveConversationChannel(target.channelId, preserveThread: true),
      );
      await w.openThreadIdentity(
        parentChannelId: target.channelId,
        parentMessageId: target.parentMessageId!,
        focusedMessageId: target.messageId,
        initialThreadChannelId: target.threadChannelId,
        navigate: false,
      );
      return;
    }
    await w.jumpToMessage(target.channelId, target.messageId, navigate: false);
  }

  void expectThreadShows(int newest, {int? focus, String? why}) {
    final m = w.messageDomain;
    final ids = w.replies.map((r) => r.id).toList();
    final reason =
        '${why ?? ''} threadChannel=${m.state.threadChannelId} '
        'loading=${m.state.threadLoading} err=${m.state.threadResolutionError} '
        'parent=${m.state.threadParent?.id} '
        'replies=${ids.isEmpty ? ids : '${ids.first}..${ids.last} (${ids.length})'}';
    expect(m.state.threadChannelId, 'tA', reason: reason);
    expect(m.state.threadLoading, isFalse, reason: reason);
    expect(m.state.threadResolutionError, isNull, reason: reason);
    expect(m.state.threadParent?.id, 'alpha-100', reason: reason);
    expect(ids, contains('tA-$newest'), reason: reason);
    expect(ids.last, 'tA-$newest', reason: reason);
    expect(
      m.state.highlightedMessageId,
      'tA-${focus ?? newest}',
      reason: reason,
    );
  }

  void expectChannelShows(String id) {
    final m = w.messageDomain;
    final ids = m.messages.map((r) => r.id).toList();
    final reason =
        'channel=${w.channel?.id} loading=${m.state.channelLoading} '
        'thread=${m.state.threadChannelId} '
        'visible=${ids.isEmpty ? ids : '${ids.first}..${ids.last} (${ids.length})'}';
    expect(w.channel?.id, id, reason: reason);
    expect(m.state.channelLoading, isFalse, reason: reason);
    expect(ids, isNotEmpty, reason: reason);
    expect(ids.every((x) => x.startsWith('$id-')), isTrue, reason: reason);
    expect(ids.last, '$id-${client.ends[id]}', reason: reason);
    expect(m.state.threadChannelId, isNull, reason: reason);
  }

  Future<void> close() async {
    if (client.gate?.isCompleted == false) client.gate!.complete();
    await w.flushCache();
    w.dispose();
    await client.events$.close();
    await cache.close();
  }
}

void main() {
  // New replies arrive while the user is elsewhere (live events delivered, or
  // missed because the socket was down), then the thread row is tapped.
  for (final delivered in ['both', 'newest-only', 'none']) {
    test(
      'thread row tapped after 2 new replies arrived while away; delivered=$delivered',
      () async {
        final c = _Case();
        addTearDown(c.close);
        await c.tap(c.threadRow(120));
        c.expectThreadShows(120, why: 'first open');
        await c.tap(c.channelRow('beta'));
        c.expectChannelShows('beta');

        c.client.ends['tA'] = 122;
        for (final n in switch (delivered) {
          'both' => [121, 122],
          'newest-only' => [122],
          _ => <int>[],
        }) {
          c.client.events$.add(RaftEvent('message:new', _message('tA', n)));
        }
        await c.w.flushCache();

        for (final attempt in [1, 2]) {
          await c.tap(c.threadRow(122, unread: 2));
          c.expectThreadShows(122, focus: 121, why: 'attempt $attempt');
          expect(c.w.replies.map((r) => r.id), contains('tA-121'));
        }
      },
    );
  }

  test('switching between a thread row and channel rows many times keeps showing the tapped item', () async {
    final c = _Case();
    addTearDown(c.close);
    for (var round = 0; round < 3; round++) {
      c.client.ends['tA'] = 120 + round;
      await c.tap(c.threadRow(120 + round));
      c.expectThreadShows(120 + round, why: 'round $round thread');
      await c.tap(c.channelRow('beta'));
      c.expectChannelShows('beta');
      await c.tap(c.threadRow(120 + round));
      c.expectThreadShows(120 + round, why: 'round $round thread again');
      await c.tap(c.channelRow('alpha'));
      c.expectChannelShows('alpha');
    }
  });

  test('locate twice in a thread (same reply, then the newest)', () async {
    final c = _Case();
    addTearDown(c.close);
    await c.tap(c.threadRow(120));
    for (final target in [40, 40, 120, 120, 40, 120]) {
      await c.w.openThreadIdentity(
        parentChannelId: 'alpha',
        parentMessageId: 'alpha-100',
        focusedMessageId: 'tA-$target',
        initialThreadChannelId: 'tA',
        navigate: false,
      );
      final ids = c.w.replies.map((r) => r.id).toList();
      final reason =
          'target $target loading=${c.w.messageDomain.state.threadLoading} '
          'err=${c.w.messageDomain.state.threadResolutionError} '
          'visible=${ids.isEmpty ? ids : '${ids.first}..${ids.last}'}';
      expect(c.w.messageDomain.state.threadLoading, isFalse, reason: reason);
      expect(c.w.messageDomain.state.threadResolutionError, isNull);
      expect(ids, contains('tA-$target'), reason: reason);
    }
  });

  test(
    'a failed thread context GET leaves nothing behind: the next tap recovers',
    () async {
      final c = _Case();
      addTearDown(c.close);
      c.client.failContext = 1;
      await c.tap(c.threadRow(120));
      expect(c.w.messageDomain.state.threadResolutionError, isNotNull);
      await c.tap(c.threadRow(120));
      c.expectThreadShows(120, why: 'retry after failure');
      await c.tap(c.channelRow('beta'));
      c.expectChannelShows('beta');
      await c.tap(c.threadRow(120));
      c.expectThreadShows(120, why: 'after channel');
    },
  );

  for (final bump in ['back', 'replace']) {
    test(
      'a navigation bump while the thread context GET waits cannot leave the thread loading; bump=$bump',
      skip: 'Controller-only: on phones Back closes the thread first (see activity_open_mobile_flow_test.dart).',
      () async {
        final c = _Case();
        addTearDown(c.close);
        final gate = c.client.gate = Completer<void>();
        c.client.started = Completer<void>();
        final first = c.tap(c.threadRow(120));
        await c.client.started!.future;
        expect(c.w.messageDomain.state.threadLoading, isTrue);
        if (bump == 'back') {
          c.w.navigation.back();
        } else {
          c.w.navigation.navigate(
            c.w.location,
            kind: RaftNavigationKind.replace,
          );
        }
        c.client.gate = null;
        gate.complete();
        await first;
        expect(
          c.w.messageDomain.state.threadLoading,
          isFalse,
          reason: 'retired thread visit skipped its finally block',
        );
        await c.tap(c.threadRow(120));
        c.expectThreadShows(120, why: 'second tap');
      },
    );
  }

  // Same as above across an app restart: session 1 read the thread (saved to
  // SQLite), session 2 starts with an empty memory and a thread that gained
  // replies; the live events reach session 2 in full, only the newest, or not
  // at all. The tapped row targets the newest reply.
  for (final delivered in ['both', 'newest-only', 'none']) {
    test(
      'after a restart, thread row tapped with 2 new replies; delivered=$delivered',
      () async {
        final client = _Client();
        final cache = DriftWorkspaceCache(NativeDatabase.memory());
        final first = _Case(client: client, cache: cache);
        await first.tap(first.threadRow(120));
        first.expectThreadShows(120, why: 'session 1');
        await first.w.flushCache();
        await cache.messageHistory.reads.settled;
        first.w.dispose();
        client.user = RaftRecord({'id': 'alice'}); // dispose signs out
        client.ends['tA'] = 122;
        final c = _Case(client: client, cache: cache);
        addTearDown(() async {
          await c.w.flushCache();
          c.w.dispose();
          await client.events$.close();
          await cache.close();
        });
        await c.w.selectChannel(
          c.w.channels.last,
          navigate: false,
          autoRead: false,
        );
        for (final n in switch (delivered) {
          'both' => [121, 122],
          'newest-only' => [122],
          _ => <int>[],
        }) {
          client.events$.add(RaftEvent('message:new', _message('tA', n)));
        }
        await c.w.flushCache();
        await cache.messageHistory.reads.settled;
        for (final attempt in [1, 2]) {
          await c.tap(c.threadRow(122));
          await cache.messageHistory.reads.settled;
          c.expectThreadShows(122, why: 'attempt $attempt');
          final seqs = [
            for (final r in c.w.replies) int.parse(r.id.split('-').last),
          ];
          expect(
            [for (var i = 1; i < seqs.length; i++) seqs[i] - seqs[i - 1]],
            everyElement(1),
            reason: 'hole in thread page: $seqs',
          );
        }
      },
    );
  }

  // The thread window the user is looking at receives the new replies live.
  test('live replies reach a thread window opened from Activity', () async {
    final c = _Case();
    addTearDown(c.close);
    await c.tap(c.threadRow(120));
    c.client.ends['tA'] = 122;
    for (final n in [121, 122]) {
      c.client.events$.add(RaftEvent('message:new', _message('tA', n)));
    }
    await c.w.flushCache();
    expect(c.w.replies.map((r) => r.id), containsAll(['tA-121', 'tA-122']));
  });

  // Leave the thread for a channel row while it is a held window; replies that
  // arrive in the meantime must be in the window the next tap shows, also when
  // the next tap targets an OLD reply (first unread) that the held window has.
  test(
    're-tap with an older focus on a held thread window shows the new replies',
    () async {
      final c = _Case();
      addTearDown(c.close);
      await c.tap(c.threadRow(120));
      await c.tap(c.channelRow('beta'));
      c.client.ends['tA'] = 122;
      for (final n in [121, 122]) {
        c.client.events$.add(RaftEvent('message:new', _message('tA', n)));
      }
      await c.w.flushCache();
      // Unread row whose first unread reply (110) is inside the held window.
      await c.tap(c.threadRow(122, unread: 13));
      await c.cache.messageHistory.reads.settled;
      final ids = c.w.replies.map((r) => r.id).toList();
      expect(c.w.messageDomain.state.threadLoading, isFalse);
      expect(ids, contains('tA-110'));
      expect(ids, contains('tA-122'), reason: 'visible: $ids');
    },
  );

  // A transient refusal of the thread's context GET (the newest reply is not
  // readable yet, a replica lags, a proxy answers 403) must not poison the
  // thread for the rest of the process: openThreadLocal revokes the thread
  // channel on 403/404 and refuses every later open until restart.
  // 403 (no access to the thread) still revokes, as on the channel path.
  for (final status in [404]) {
    test(
      'one transient $status on the thread context GET does not lock the thread until restart',
      () async {
        final c = _Case();
        addTearDown(c.close);
        c.client.failContext = 1;
        c.client.failStatus = status;
        await c.tap(c.threadRow(120));
        final revoked = c.w.sessionScope.revokedChannels.toList();
        await c.tap(c.channelRow('beta'));
        c.client.ends['tA'] = 121;
        for (final attempt in [1, 2]) {
          await c.tap(c.threadRow(121));
          c.expectThreadShows(
            121,
            why:
                'attempt $attempt after one $status (revoked after first: $revoked)',
          );
        }
      },
    );
  }

  // The Activity row can point at a reply that is gone (deleted since). The
  // context GET of that one message answers 404; the thread itself is fine and
  // must still open normally afterwards (by any other route).
  test(
    'a 404 for one missing target reply does not revoke the whole thread',
    () async {
      final c = _Case();
      addTearDown(c.close);
      c.client.failContext = 1;
      c.client.failStatus = 404;
      await c.tap(c.threadRow(120)); // target missing
      await c.w.openThreadIdentity(
        parentChannelId: 'alpha',
        parentMessageId: 'alpha-100',
        initialThreadChannelId: 'tA',
        navigate: false,
      );
      final ids = c.w.replies.map((r) => r.id).toList();
      expect(
        c.w.sessionScope.revokedChannels,
        isNot(contains('tA')),
        reason: 'thread channel was revoked by one 404 on a reply context',
      );
      expect(c.w.messageDomain.state.threadChannelId, 'tA');
      expect(ids, isNotEmpty);
    },
  );
}
