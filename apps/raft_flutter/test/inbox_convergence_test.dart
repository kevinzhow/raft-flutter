// The server lists a new message in /channels/inbox about a second after the
// socket announces it. Activity must still converge: retries until the window
// shows the message, an OS alert that waits for it (up to a cap), and a read
// on return to the foreground that does not wait for the resume handshake.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/inbox_convergence.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/source_server_unread.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'support/app_services_fixture.dart';

class _Client extends RaftClient {
  _Client(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  final resumes = <BigInt>[];
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  bool get connected => true;
  @override
  void connect() {}
  @override
  void resume(BigInt seq) => resumes.add(seq);
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

/// A conversation row as the inbox lists it.
Map<String, dynamic> _row(String channel, String last, int seq, int unread) => {
  'kind': 'channel',
  'channelId': channel,
  'lastMessageId': last,
  'latestActivitySeq': '$seq',
  'unreadCount': unread,
};

Map<String, dynamic> _window(List<Map<String, dynamic>> rows) => {
  'items': rows,
  'hasMore': false,
  'totalUnreadCount': rows.fold<int>(
    0,
    (sum, row) => sum + (row['unreadCount'] as int),
  ),
};

Future<(WorkspaceController, MessageAdapter, _Client)> _fixture() async {
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
  w.channel = RaftChannel({'id': 'c1', 'name': 'actual chat', 'joined': true});
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
}

List<RequestOptions> _inbox(MessageAdapter api) =>
    api.calls.where((r) => r.path == '/channels/inbox').toList();

Future<void> _drain(WidgetTester tester) async {
  for (var turn = 0; turn < 8; turn++) {
    await tester.pump(Duration.zero);
  }
}

class _Notifications extends NativeNotificationService {
  _Notifications() {
    enabled = true;
    permitted = true;
    available = true;
  }
  final sent = <DateTime>[];
  @override
  bool get receivesMessages => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
    int? unread,
    bool quiet = false,
    String? conversation,
  }) async {
    sent.add(DateTime.now());
  }
}

/// The freshness guards and retry budgets read the widget binding's fake clock.
void _fakeTime(WidgetTester tester) {
  SourceActivityUnreadStore.clock = tester.binding.clock.now;
  SourceServerUnreadStore.clock = tester.binding.clock.now;
  addTearDown(() {
    SourceActivityUnreadStore.clock = DateTime.now;
    SourceServerUnreadStore.clock = DateTime.now;
  });
}

void main() {
  group('InboxConvergence', () {
    // Fake time: `elapse` pumps in 50 ms steps and counts them.
    Future<void> Function(Duration) clockOf(WidgetTester tester, List<int> at) {
      return (d) async {
        for (var ms = 0; ms < d.inMilliseconds; ms += 50) {
          at[0] += 50;
          await tester.pump(const Duration(milliseconds: 50));
        }
      };
    }

    testWidgets('retries at 0.7 s, 1.5 s and 3 s after the event, then stops', (
      tester,
    ) async {
      _fakeTime(tester);
      final now = [0];
      final elapse = clockOf(tester, now);
      final retries = <int>[];
      final c = InboxConvergence(retry: () => retries.add(now[0]));
      c.expect('c1', messageId: 'm7', seq: 7);
      await elapse(const Duration(seconds: 10));
      // Each at its offset from the event (+ the 20 ms that shares a read).
      expect(retries, hasLength(3));
      for (final (i, at) in [700, 1500, 3000].indexed) {
        expect(retries[i], inInclusiveRange(at, at + 100));
      }
      c.dispose();
    });

    testWidgets('a window that shows the message ends the retries', (
      tester,
    ) async {
      _fakeTime(tester);
      final now = [0];
      final elapse = clockOf(tester, now);
      var retries = 0;
      final c = InboxConvergence(
        retry: () => retries++,
        now: tester.binding.clock.now,
      );
      c.expect('c1', messageId: 'm7', seq: 7);
      await elapse(const Duration(milliseconds: 750));
      expect(retries, 1);
      c.observe([_row('c1', 'm6', 6, 0)]);
      expect(c.hasPending, isTrue, reason: 'a window before the message');
      c.observe([_row('c1', 'm7', 7, 1)]);
      expect(c.hasPending, isFalse);
      await elapse(const Duration(seconds: 10));
      expect(retries, 1);
      c.dispose();
    });

    testWidgets('a burst in one conversation shares one series of retries', (
      tester,
    ) async {
      _fakeTime(tester);
      final now = [0];
      final elapse = clockOf(tester, now);
      var retries = 0;
      final c = InboxConvergence(
        retry: () => retries++,
        now: tester.binding.clock.now,
      );
      for (var seq = 7; seq < 17; seq++) {
        c.expect('c1', messageId: 'm$seq', seq: seq);
        await elapse(const Duration(milliseconds: 100));
      }
      await elapse(const Duration(seconds: 10));
      expect(retries, lessThanOrEqualTo(3));
      c.dispose();
    });

    testWidgets('conversations that fall due together share one read', (
      tester,
    ) async {
      _fakeTime(tester);
      final now = [0];
      final elapse = clockOf(tester, now);
      var retries = 0;
      final c = InboxConvergence(
        retry: () => retries++,
        now: tester.binding.clock.now,
      );
      for (final id in ['a', 'b', 'c', 'd']) {
        c.expect(id, messageId: 'm-$id', seq: 5);
      }
      await elapse(const Duration(seconds: 10));
      expect(retries, 3);
      c.dispose();
    });

    testWidgets('a conversation the window never lists cannot keep reading', (
      tester,
    ) async {
      _fakeTime(tester);
      final now = [0];
      final elapse = clockOf(tester, now);
      var retries = 0;
      final c = InboxConvergence(
        retry: () => retries++,
        now: tester.binding.clock.now,
      );
      // One message a second for two minutes into a conversation the inbox
      // does not list.
      for (var second = 0; second < 120; second++) {
        c.expect('ghost', messageId: 'm$second', seq: second);
        await elapse(const Duration(seconds: 1));
      }
      // Two series of three, then a minute of quiet; twice in two minutes.
      expect(retries, lessThanOrEqualTo(2 * 6 + 3));
      c.dispose();
    });

    test('a thread reply is matched on the thread row', () {
      final want = InboxWant(channelId: 't1', messageId: 'r2');
      expect(
        want.satisfiedBy([
          {
            'kind': 'thread',
            'threadChannelId': 't1',
            'latestActivityMessageId': 'r1',
          },
        ]),
        isFalse,
      );
      expect(
        want.satisfiedBy([
          {
            'kind': 'thread',
            'threadChannelId': 't1',
            'latestActivityMessageId': 'r2',
          },
        ]),
        isTrue,
      );
    });
  });

  group('SourceActivityUnreadStore', () {
    testWidgets(
      'a stale first window converges once the server lists the message',
      (tester) async {
        _fakeTime(tester);
        final (w, api, client) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        // The server includes m7 only from 1 s after the event.
        var serverHasIt = false;
        api.routes['GET /channels/inbox'] = (_) => _window([
          serverHasIt ? _row('c1', 'm7', 7, 3) : _row('c1', 'm6', 6, 2),
        ]);
        final store = w.activityUnread..start();
        client.ingress.add(const RaftEvent('rooms:joined', null));
        await _drain(tester);
        expect(store.totalUnreadCount, 2);
        final before = _inbox(api).length;

        client.ingress.add(
          const RaftEvent('message:new', {
            'id': 'm7',
            'channelId': 'c1',
            'senderId': 'bob',
            'senderType': 'user',
            'seq': 7,
          }),
        );
        var at = 0;
        Future<void> to(int ms) async {
          while (at < ms) {
            final step = (ms - at).clamp(1, 50);
            await tester.pump(Duration(milliseconds: step));
            await _drain(tester);
            at += step;
          }
        }

        await to(160);
        expect(_inbox(api).length, before + 1, reason: 'the 150 ms read');
        expect(store.totalUnreadCount, 2, reason: 'stale: no m7 yet');
        await to(1000);
        serverHasIt = true;
        await to(1450);
        expect(store.totalUnreadCount, 2, reason: 'the 0.7 s read was stale');
        await to(1700);
        expect(store.totalUnreadCount, 3, reason: 'the 1.5 s read converged');
        final reads = _inbox(api).length;
        expect(reads, before + 3, reason: '150 ms, 0.7 s, 1.5 s');
        await to(20000);
        expect(_inbox(api).length, reads, reason: 'converged: no more reads');
        store.dispose();
      },
    );

    testWidgets('retries are bounded when the window never lists it', (
      tester,
    ) async {
      _fakeTime(tester);
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      api.routes['GET /channels/inbox'] = (_) =>
          _window([_row('c1', 'm6', 6, 2)]);
      final store = w.activityUnread..start();
      client.ingress.add(const RaftEvent('rooms:joined', null));
      await _drain(tester);
      final before = _inbox(api).length;
      for (final id in ['m7', 'm8']) {
        client.ingress.add(
          RaftEvent('message:new', {
            'id': id,
            'channelId': 'c1',
            'senderId': 'bob',
            'senderType': 'user',
            'seq': id == 'm7' ? 7 : 8,
          }),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await _drain(tester);
      }
      for (var i = 0; i < 400; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await _drain(tester);
      }
      // One read for the two events' shared debounce, then the three retries.
      expect(_inbox(api).length - before, 4);
      store.dispose();
    });

    testWidgets(
      'reach completes when the window lists the message, or at the cap',
      (tester) async {
        _fakeTime(tester);
        final (w, api, client) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        var serverHasIt = false;
        api.routes['GET /channels/inbox'] = (_) => _window([
          serverHasIt ? _row('c1', 'm7', 7, 3) : _row('c1', 'm6', 6, 2),
        ]);
        final store = w.activityUnread..start();
        client.ingress.add(const RaftEvent('rooms:joined', null));
        await _drain(tester);

        bool? result;
        unawaited(
          store
              .reach(
                channelId: 'c1',
                messageId: 'm7',
                timeout: const Duration(milliseconds: 1500),
              )
              .then((v) => result = v),
        );
        for (var ms = 0; ms < 1400; ms += 50) {
          await tester.pump(const Duration(milliseconds: 50));
          await _drain(tester);
        }
        expect(result, isNull, reason: 'still waiting before the cap');
        for (var ms = 0; ms < 200; ms += 50) {
          await tester.pump(const Duration(milliseconds: 50));
          await _drain(tester);
        }
        expect(result, isFalse, reason: 'the cap returned without the message');

        serverHasIt = true;
        result = null;
        unawaited(
          store
              .reach(
                channelId: 'c1',
                messageId: 'm7',
                timeout: const Duration(milliseconds: 1500),
              )
              .then((v) => result = v),
        );
        await _drain(tester);
        expect(result, isTrue, reason: 'an immediate read found it');
        store.dispose();
      },
    );

    testWidgets(
      'the store reads on resume at once, and not again inside the guard',
      (tester) async {
        _fakeTime(tester);
        final (w, api, client) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        api.routes['GET /channels/inbox'] = (_) =>
            _window([_row('c1', 'm6', 6, 2)]);
        final store = w.activityUnread..start();
        client.ingress.add(const RaftEvent('rooms:joined', null));
        await _drain(tester);
        await tester.pump(const Duration(seconds: 6));
        final before = _inbox(api).length;

        unawaited(store.refreshOnResume());
        await _drain(tester);
        expect(_inbox(api).length, before + 1);
        // A second return inside the guard, and the resume handshake's reply.
        unawaited(store.refreshOnResume());
        client.ingress.add(const RaftEvent('sync:resume:response', {}));
        await tester.pump(const Duration(seconds: 1));
        await _drain(tester);
        expect(_inbox(api).length, before + 1);
        await tester.pump(const Duration(seconds: 4));
        unawaited(store.refreshOnResume());
        await _drain(tester);
        expect(_inbox(api).length, before + 2);
        store.dispose();
      },
    );
  });

  group('return to the foreground', () {
    testWidgets(
      'reads Activity and the server summary without waiting for sync:resume',
      (tester) async {
        _fakeTime(tester);
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api, client) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        api.routes['GET /channels/inbox'] = (_) =>
            _window([_row('c1', 'm6', 6, 2)]);
        api.routes['GET /servers/unread-summary'] = (_) => [
          {
            'serverId': 's1',
            'unreadCount': 0,
            'activityUnreadCount': 2,
            'serverPushMuted': false,
          },
        ];
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: false),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: const RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        client.ingress.add(const RaftEvent('rooms:joined', null));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 6));
        final inbox = _inbox(api).length;
        int summary() =>
            api.calls.where((r) => r.path == '/servers/unread-summary').length;
        final summaries = summary();

        w.resumeLiveSession();
        await _drain(tester);
        expect(_inbox(api).length, inbox + 1, reason: 'Activity window');
        expect(summary(), summaries + 1, reason: 'cross-server summary');
        expect(client.resumes, isEmpty, reason: 'no watermark in the fixture');

        // The handshake's reply and a second resume add nothing inside 4 s.
        client.ingress.add(const RaftEvent('sync:resume:response', {}));
        w.resumeLiveSession();
        await tester.pump(const Duration(seconds: 1));
        await _drain(tester);
        expect(_inbox(api).length, inbox + 1);
        expect(summary(), summaries + 1);

        await tester.pump(const Duration(seconds: 5));
        w.resumeLiveSession();
        await _drain(tester);
        expect(_inbox(api).length, inbox + 2);
        expect(summary(), summaries + 2);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('OS alert', () {
    Future<
      (
        WorkspaceController,
        MessageAdapter,
        _Client,
        _Notifications,
        NativeContentCoordinator,
      )
    >
    open(WidgetTester tester) async {
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      w.foreground = false;
      api.routes['GET /servers'] = (_) => [
        {'id': 's1', 'slug': 'fixture'},
      ];
      api.routes['GET /channels/c1'] = (_) => {'id': 'c1', 'serverId': 's1'};
      api.routes['GET /messages/context/m7'] = (_) => {
        'messages': [
          {'id': 'm7', 'channelId': 'c1'},
        ],
      };
      final n = _Notifications();
      addTearDown(n.dispose);
      final coordinator = NativeContentCoordinator(
        notifications: n,
        links: const Stream.empty(),
      );
      await tester.runAsync(() async {
        await coordinator.init();
      });
      coordinator.bindWorkspace(w);
      addTearDown(() async {
        await tester.runAsync(coordinator.dispose);
      });
      return (w, api, client, n, coordinator);
    }

    const push = {
      'serverId': 's1',
      'kind': 'channel',
      'channelId': 'c1',
      'messageId': 'm7',
      'title': 'bob',
      'body': 'hello',
    };

    testWidgets('is shown once the Activity window lists the message', (
      tester,
    ) async {
      _fakeTime(tester);
      final (w, api, client, n, _) = await open(tester);
      var serverHasIt = false;
      api.routes['GET /channels/inbox'] = (_) => _window([
        serverHasIt ? _row('c1', 'm7', 7, 3) : _row('c1', 'm6', 6, 2),
      ]);
      final store = w.activityUnread..start();
      client.ingress.add(const RaftEvent('rooms:joined', null));
      await _drain(tester);

      // The socket announces the message, then asks for the alert.
      client.ingress.add(
        const RaftEvent('message:new', {
          'id': 'm7',
          'channelId': 'c1',
          'senderId': 'bob',
          'senderType': 'user',
          'seq': 7,
        }),
      );
      client.ingress.add(const RaftEvent('notification:push', push));
      var at = 0;
      Future<void> to(int ms) async {
        while (at < ms) {
          final step = (ms - at).clamp(1, 50);
          await tester.pump(Duration(milliseconds: step));
          await _drain(tester);
          at += step;
        }
      }

      await to(1000);
      serverHasIt = true;
      expect(n.sent, isEmpty, reason: 'the window predates the message');
      expect(store.totalUnreadCount, 2);
      await to(1450);
      expect(n.sent, isEmpty);
      await to(1550);
      expect(store.totalUnreadCount, 3);
      expect(n.sent, hasLength(1), reason: 'shown once the window had it');
      w.dispose();
    });

    testWidgets('is shown at the cap when the window never lists it', (
      tester,
    ) async {
      _fakeTime(tester);
      final (w, api, client, n, _) = await open(tester);
      api.routes['GET /channels/inbox'] = (_) =>
          _window([_row('c1', 'm6', 6, 2)]);
      w.activityUnread.start();
      client.ingress.add(const RaftEvent('rooms:joined', null));
      await _drain(tester);

      client.ingress.add(const RaftEvent('notification:push', push));
      var at = 0;
      Future<void> to(int ms) async {
        while (at < ms) {
          final step = (ms - at).clamp(1, 50);
          await tester.pump(Duration(milliseconds: step));
          await _drain(tester);
          at += step;
        }
      }

      await to(1400);
      expect(n.sent, isEmpty, reason: 'still waiting for the window');
      await to(1600);
      expect(n.sent, hasLength(1), reason: 'never held past the cap');
      w.dispose();
      // Three checks of the alert, plus the convergence reads.
      expect(
        api.calls
            .where(
              (r) => const {
                '/servers',
                '/channels/c1',
                '/messages/context/m7',
              }.contains(r.path),
            )
            .length,
        3,
      );
    });

    testWidgets('is shown at once when no Activity window is bound', (
      tester,
    ) async {
      _fakeTime(tester);
      final (_, _, client, n, coordinator) = await open(tester);
      client.ingress.add(const RaftEvent('notification:push', push));
      await _drain(tester);
      expect(n.sent, hasLength(1));
      await tester.runAsync(coordinator.dispose);
    });

    testWidgets('is not shown when the app is opened while it waits', (
      tester,
    ) async {
      _fakeTime(tester);
      final (w, api, client, n, _) = await open(tester);
      api.routes['GET /channels/inbox'] = (_) =>
          _window([_row('c1', 'm6', 6, 2)]);
      w.activityUnread.start();
      client.ingress.add(const RaftEvent('rooms:joined', null));
      await _drain(tester);
      client.ingress.add(const RaftEvent('notification:push', push));
      await tester.pump(const Duration(milliseconds: 300));
      await _drain(tester);
      w.setForeground(true);
      await tester.pump(const Duration(seconds: 2));
      await _drain(tester);
      expect(n.sent, isEmpty);
      w.dispose();
    });
  });
}
