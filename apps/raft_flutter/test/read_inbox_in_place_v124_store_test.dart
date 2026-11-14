// Web v1.24.0 #244 on the Activity store: a live message patches its listed
// row at once, a served window behind it keeps the local unread, the realtime
// re-read is a leading+trailing 2.5 s throttle that waits while hidden, and
// `inbox_read_inplace_v1` lets a persisted read of a read row skip its re-read.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/inbox_in_place_unread.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/source_server_unread.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;

class _Client extends RaftClient {
  _Client(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  bool get connected => true;
  @override
  void connect() {}
  @override
  void resume(BigInt seq) {}
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

Map<String, dynamic> _row(
  String channel,
  int seq,
  int unread, {
  Map<String, dynamic>? readState,
}) => {
  'kind': 'channel',
  'channelId': channel,
  'lastMessageId': 'm$seq',
  'latestActivitySeq': '$seq',
  'unreadCount': unread,
  'hasMention': false,
  'readState': ?readState,
};

Map<String, dynamic> _window(List<Map<String, dynamic>> rows) => {
  'items': rows,
  'hasMore': false,
  'totalUnreadCount': rows.fold<int>(
    0,
    (sum, row) => sum + (row['unreadCount'] as int),
  ),
};

Map<String, dynamic> _message(
  int seq, {
  String channel = 'c1',
  String sender = 'bob',
  List<Map<String, String>> mentions = const [],
}) => {
  'id': 'm$seq',
  'channelId': channel,
  'seq': seq,
  'senderId': sender,
  'senderType': 'user',
  'content': 'hello $seq',
  'mentions': mentions,
};

List<RequestOptions> _inbox(MessageAdapter api) =>
    api.calls.where((r) => r.path == '/channels/inbox').toList();

Future<void> _drain(WidgetTester tester) async {
  for (var turn = 0; turn < 8; turn++) {
    await tester.pump(Duration.zero);
  }
}

Future<void> _elapse(WidgetTester tester, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
    await tester.pump(const Duration(milliseconds: 50));
    await _drain(tester);
  }
}

typedef _Fixture = ({
  WorkspaceController w,
  MessageAdapter api,
  _Client client,
  SourceActivityUnreadStore store,
  List<Map<String, dynamic>> served,
  VoidCallback surface,
});

/// A started store whose first window is accepted; the window it serves next
/// is `served` (the test edits it to play the server's lag).
Future<_Fixture> _started(
  WidgetTester tester, {
  List<Map<String, dynamic>>? rows,
}) async {
  SourceActivityUnreadStore.clock = tester.binding.clock.now;
  SourceServerUnreadStore.clock = tester.binding.clock.now;
  addTearDown(() {
    SourceActivityUnreadStore.clock = DateTime.now;
    SourceServerUnreadStore.clock = DateTime.now;
  });
  final (w, api, client) = (await tester.runAsync(() async {
    final api = MessageAdapter();
    api.routes['POST /auth/login'] = (_) => {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    };
    final client = _Client(api);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    final w = WorkspaceController(client);
    w.server = RaftRecord({'id': 's1', 'slug': 'fixture', 'role': 'owner'});
    w.channel = RaftChannel({'id': 'c1', 'name': 'chat', 'joined': true});
    w.channels = [w.channel!];
    w.loading = false;
    w.section = 'chat';
    api.routes['GET /channels/unread'] = (_) => {'channels': <String, int>{}};
    api.routes['GET /channels'] = (_) => [w.channel!.json];
    api.routes['GET /channels/dms'] = (_) => [];
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /servers/s1/machines'] = (_) => [];
    api.routes['GET /servers/s1/sidebar-order'] = (_) => {};
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    return (w, api, client);
  }))!;
  addTearDown(w.dispose);
  final served = rows ?? [_row('c1', 6, 2), _row('c2', 3, 0)];
  api.routes['GET /channels/inbox'] = (_) {
    // ignore: avoid_print
    print(
      'READ at ${tester.binding.clock.now().millisecondsSinceEpoch % 100000}',
    );
    return _window(served);
  };
  final store = w.activityUnread..start();
  // A mounted surface listens: only then are the throttle's timers armed.
  void surface() {}
  store.addListener(surface);
  client.ingress.add(const RaftEvent('rooms:joined', null));
  await _drain(tester);
  expect(store.hasAcceptedWindow, isTrue);
  return (
    w: w,
    api: api,
    client: client,
    store: store,
    served: served,
    surface: surface,
  );
}

Map<String, dynamic> _shown(_Fixture f, String channel) =>
    f.store.acceptedRows.firstWhere((row) => row['channelId'] == channel);

void main() {
  tearDown(
    () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );

  group('live message, in place', () {
    testWidgets('[BP-READ-042] patches the listed row and the badge before any '
        're-read', (tester) async {
      final f = await _started(tester);
      expect(f.store.totalUnreadCount, 2);
      final reads = _inbox(f.api).length;
      f.client.ingress.add(RaftEvent('message:new', _message(7)));
      // No pump, no read: the patch is synchronous.
      expect(f.store.totalUnreadCount, 3);
      expect(_shown(f, 'c1')['unreadCount'], 3);
      expect(_shown(f, 'c1')['latestActivitySeq'], '7');
      expect(
        _shown(f, 'c1')['firstUnreadMessageId'],
        isNull,
        reason: 'the row already had unread',
      );
      final seeded = f.store.windowSince(0)!['items'] as List;
      expect(seeded.first['channelId'], 'c1');
      expect(seeded.first['unreadCount'], 3);
      await _elapse(tester, const Duration(milliseconds: 200));
      expect(_inbox(f.api).length, reads, reason: 'inside the 2.5 s window');
      f.store.dispose();
    });

    testWidgets('[BP-READ-042] a message of a read row sets the first unread '
        'id; a mention sets hasMention', (tester) async {
      final f = await _started(tester, rows: [_row('c1', 6, 0)]);
      f.client.ingress.add(
        RaftEvent(
          'message:new',
          _message(
            7,
            mentions: [
              {'type': 'user', 'id': 'alice'},
            ],
          ),
        ),
      );
      final row = _shown(f, 'c1');
      expect(row['unreadCount'], 1);
      expect(row['firstUnreadMessageId'], 'm7');
      expect(row['hasMention'], isTrue);
      expect(row['firstMentionMessageId'], 'm7');
      f.store.dispose();
    });

    testWidgets('[BP-READ-042] the person\'s own message and a repeat do not '
        'count', (tester) async {
      final f = await _started(tester);
      f.client.ingress.add(
        RaftEvent('message:new', _message(7, sender: 'alice')),
      );
      expect(f.store.totalUnreadCount, 2);
      f.client.ingress.add(RaftEvent('message:new', _message(8)));
      f.client.ingress.add(RaftEvent('message:new', _message(8)));
      expect(f.store.totalUnreadCount, 3, reason: 'counted once');
      f.store.dispose();
    });

    testWidgets('[BP-READ-042] a message that comes late counts once', (
      tester,
    ) async {
      final f = await _started(tester);
      f.client.ingress.add(RaftEvent('message:new', _message(8)));
      f.client.ingress.add(RaftEvent('message:new', _message(7)));
      f.client.ingress.add(RaftEvent('message:new', _message(7)));
      expect(_shown(f, 'c1')['unreadCount'], 4);
      expect(_shown(f, 'c1')['latestActivitySeq'], '8');
      f.store.dispose();
    });

    testWidgets(
      '[BP-READ-042] a thread reply patches its followed thread row',
      (tester) async {
        final f = await _started(
          tester,
          rows: [
            {
              'kind': 'thread',
              'threadChannelId': 't1',
              'latestActivityMessageId': 'r4',
              'latestActivitySeq': '4',
              'unreadCount': 1,
              'hasMention': false,
              'replyCount': 4,
            },
          ],
        );
        f.client.ingress.add(
          RaftEvent('thread:updated', {
            'threadChannelId': 't1',
            'latestReply': _message(5, channel: 't1'),
          }),
        );
        final row = f.store.acceptedRows.single;
        expect(row['unreadCount'], 2);
        expect(row['replyCount'], 5);
        expect(f.store.totalUnreadCount, 2);
        f.store.dispose();
      },
    );

    testWidgets('[BP-READ-043] a window still behind the patched row keeps '
        'its unread, then the one that reaches it wins', (tester) async {
      final f = await _started(tester);
      f.client.ingress.add(RaftEvent('message:new', _message(7)));
      expect(f.store.totalUnreadCount, 3);
      // The server lists m7 only after 4 s; its retries read before that.
      await _elapse(tester, const Duration(seconds: 4));
      expect(_inbox(f.api).length, greaterThan(1), reason: 'it did read');
      expect(f.store.totalUnreadCount, 3, reason: 'no flicker back to 2');
      expect(_shown(f, 'c1')['unreadCount'], 3);
      f.served
        ..clear()
        ..addAll([_row('c1', 7, 3), _row('c2', 3, 0)]);
      unawaited(f.store.refresh());
      await _drain(tester);
      expect(f.store.totalUnreadCount, 3, reason: 'the served count agrees');
      expect(_shown(f, 'c1')['latestActivitySeq'], '7');
      // Behind no more: a later answer is the server's again.
      f.served
        ..clear()
        ..addAll([_row('c1', 7, 1), _row('c2', 3, 0)]);
      unawaited(f.store.refresh());
      await _drain(tester);
      expect(f.store.totalUnreadCount, 1);
      f.store.dispose();
    });
  });

  group('realtime re-read', () {
    testWidgets('[BP-READ-046] leading read at once after a quiet window, one '
        'trailing read at its end', (tester) async {
      final f = await _started(tester);
      await _elapse(tester, const Duration(seconds: 4));
      final before = _inbox(f.api).length;
      void event() => f.client.ingress.add(
        const RaftEvent('notification_prefs:updated', {}),
      );
      event();
      await _drain(tester);
      expect(_inbox(f.api).length, before + 1, reason: 'leading: at once');
      // Three more events inside the 2.5 s window share one trailing read.
      for (var i = 0; i < 3; i++) {
        event();
        await _elapse(tester, const Duration(milliseconds: 100));
      }
      expect(_inbox(f.api).length, before + 1, reason: 'throttled');
      await _elapse(tester, const Duration(milliseconds: 2100));
      expect(_inbox(f.api).length, before + 1, reason: 'not before 2.5 s');
      await _elapse(tester, const Duration(milliseconds: 300));
      expect(_inbox(f.api).length, before + 2, reason: 'trailing at 2.5 s');
      await _elapse(tester, const Duration(seconds: 6));
      expect(_inbox(f.api).length, before + 2, reason: 'nothing more owed');
      f.store.dispose();
    });

    testWidgets('[BP-READ-046] nothing is read while hidden; showing the app '
        'pays it with one read', (tester) async {
      final f = await _started(tester);
      await _elapse(tester, const Duration(seconds: 4));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      f.served
        ..clear()
        ..addAll([_row('c1', 7, 3), _row('c2', 3, 0)]);
      final before = _inbox(f.api).length;
      f.client.ingress.add(RaftEvent('message:new', _message(7)));
      await _elapse(tester, const Duration(seconds: 8));
      expect(_inbox(f.api).length, before, reason: 'hidden: owed, not read');
      expect(f.store.totalUnreadCount, 3, reason: 'still patched in place');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      unawaited(f.store.refreshOnResume());
      await _drain(tester);
      expect(_inbox(f.api).length, before + 1);
      f.store.dispose();
    });
  });

  group('timers follow the surfaces', () {
    testWidgets('[BP-READ-046] with no surface listening no timer is armed; '
        'the next surface pays the owed read', (tester) async {
      final f = await _started(tester);
      await _elapse(tester, const Duration(seconds: 4));
      // Last surface leaves: nothing may stay pending.
      f.store.removeListener(f.surface);
      final before = _inbox(f.api).length;
      f.client.ingress.add(const RaftEvent('notification_prefs:updated', {}));
      await _drain(tester); // quiet window: the leading read needs no timer
      expect(_inbox(f.api).length, before + 1);
      f.client.ingress.add(const RaftEvent('notification_prefs:updated', {}));
      f.client.ingress.add(RaftEvent('message:new', _message(7)));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump();
      // No pending timer: advancing time reads nothing.
      await _elapse(tester, const Duration(seconds: 10));
      expect(_inbox(f.api).length, before + 1, reason: 'owed, not scheduled');
      expect(f.store.totalUnreadCount, 3, reason: 'still patched in place');
      f.store.addListener(f.surface);
      await _drain(tester);
      expect(_inbox(f.api).length, before + 2, reason: 'a surface pays it');
      f.store.dispose();
    });
  });

  group('persisted read', () {
    Future<_Fixture> read(
      WidgetTester tester, {
      required bool flag,
      int unread = 0,
    }) async {
      SharedPreferences.setMockInitialValues({});
      DevicePreferences.adopt(await SharedPreferences.getInstance());
      addTearDown(DevicePreferences.reset);
      final f = await _started(
        tester,
        rows: [_row('c1', 6, unread), _row('c2', 3, 0)],
      );
      FeatureFlagMemory.write(
        [f.client.origin, 'alice', 's1', 'owner'],
        {inboxReadInplaceFlagKey: flag},
      );
      f.api.routes['POST /channels/c1/read'] = (_) => {
        'maxReadSeq': 6,
        'readStateVersion': 1,
      };
      await _elapse(tester, const Duration(seconds: 4));
      return f;
    }

    testWidgets('[BP-READ-041] flag on: a read of a row that shows 0 on a '
        'settled list skips its re-read', (tester) async {
      final f = await read(tester, flag: true);
      final before = _inbox(f.api).length;
      await f.client.post('/channels/c1/read', data: {'seq': 6});
      await _elapse(tester, const Duration(seconds: 6));
      expect(_inbox(f.api).length, before);
      f.store.dispose();
    });

    testWidgets('[BP-READ-041] flag off: the same read re-reads as before', (
      tester,
    ) async {
      final f = await read(tester, flag: false);
      final before = _inbox(f.api).length;
      await f.client.post('/channels/c1/read', data: {'seq': 6});
      await _elapse(tester, const Duration(seconds: 6));
      expect(_inbox(f.api).length, before + 1);
      f.store.dispose();
    });

    testWidgets('[BP-READ-041] flag on: a row that still shows unread '
        're-reads', (tester) async {
      final f = await read(tester, flag: true, unread: 2);
      final before = _inbox(f.api).length;
      await f.client.post('/channels/c1/read', data: {'seq': 3});
      await _elapse(tester, const Duration(seconds: 6));
      expect(_inbox(f.api).length, before + 1);
      f.store.dispose();
    });
  });

  group('read this client cannot project', () {
    Map<String, dynamic> frontier(int seq) => {
      'kind': 'present',
      'latestActivity': {'seq': '$seq'},
      'readStateVersion': 1,
      'maxReadSeq': '0',
    };

    Map<String, dynamic> update(int read, {int? unread}) => {
      'serverId': 's1',
      'scopeId': 'c1',
      'maxReadSeq': read,
      'readStateVersion': 2,
      'unreadCount': ?unread,
    };

    testWidgets(
      '[BP-READ-043] a read covering the row zeroes it and the badge',
      (tester) async {
        final f = await _started(
          tester,
          rows: [_row('c1', 6, 2, readState: frontier(6))],
        );
        f.w.readState.consumeUpdate(
          update(6),
          serverId: 's1',
          principalId: 'alice',
        );
        f.client.ingress.add(
          RaftEvent('read_state:updated', update(6, unread: 0)),
        );
        expect(_shown(f, 'c1')['unreadCount'], 0);
        expect(f.store.totalUnreadCount, 0);
        f.store.dispose();
      },
    );

    testWidgets('[BP-READ-043] a read below a live reply keeps the row\'s '
        'count', (tester) async {
      final f = await _started(
        tester,
        rows: [_row('c1', 6, 2, readState: frontier(6))],
      );
      f.client.ingress.add(RaftEvent('message:new', _message(7)));
      expect(_shown(f, 'c1')['unreadCount'], 3);
      f.w.readState.consumeUpdate(
        update(6),
        serverId: 's1',
        principalId: 'alice',
      );
      f.client.ingress.add(
        RaftEvent('read_state:updated', update(6, unread: 1)),
      );
      expect(_shown(f, 'c1')['unreadCount'], 3, reason: 'm7 is past the read');
      f.store.dispose();
    });
  });
}
