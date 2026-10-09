import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;

class _ActivityAdapter extends MessageAdapter {
  final statuses = <String, int>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    final status = statuses['${request.method} ${request.path}'];
    if (status == null) return super.fetch(request, body, cancel);
    calls.add(request);
    return ResponseBody.fromString(
      jsonEncode({'error': 'Fixture HTTP failure'}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  List<RequestOptions> get inbox =>
      calls.where((r) => r.path == '/channels/inbox').toList();
}

class _ActivityClient extends RaftClient {
  _ActivityClient({required super.transport})
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

Future<(WorkspaceController, _ActivityAdapter, _ActivityClient)>
_fixture() async {
  final api = _ActivityAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = _ActivityClient(transport: Dio()..httpClientAdapter = api);
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
  api.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  return (w, api, client);
}

Map<String, dynamic> _window(int unread) => {
  'items': <dynamic>[],
  'totalUnreadCount': unread,
};

Future<void> _dispatch(WidgetTester tester) async {
  // Dio's interceptor queue dispatches asynchronously. Observe requests after
  // draining that queue; pending UI frames below remain asserted individually.
  for (var turn = 0; turn < 8; turn++) {
    await tester.pump(Duration.zero);
  }
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K09f] $family/$dark actual Chat preloads accepted Activity and reconciles while Activity is unopened',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api, client) = (await tester.runAsync(_fixture))!;
        addTearDown(w.dispose);
        final initial = Completer<Map<String, dynamic>>();
        api.routes['GET /channels/inbox'] = (_) => initial.future;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        Finder attention() => find.descendant(
          of: find.byKey(const ValueKey('rail-activity')),
          matching: find.byType(RaftRailAttention),
        );
        expect(w.section, 'chat');
        expect(api.inbox, isEmpty);
        client.ingress.add(const RaftEvent('rooms:joined', null));
        await _dispatch(tester);
        expect(api.inbox, hasLength(1));
        expect(api.inbox.single.queryParameters, {
          'filter': 'all',
          'sort': 'desc',
          'limit': 30,
          'offset': 0,
        });
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(attention(), findsNothing);
          expect(w.section, 'chat');
        }
        await tester.runAsync(() async {
          initial.complete(_window(7));
        });
        await tester.pumpAndSettle();
        expect(attention(), findsOneWidget);
        expect(find.byType(RaftRailUnreadCount), findsNothing);
        expect(w.section, 'chat');

        final live = Completer<Map<String, dynamic>>();
        api.routes['GET /channels/inbox'] = (_) => live.future;
        client.ingress.add(
          const RaftEvent('message:new', {
            'id': 'live-1',
            'channelId': 'c1',
            'content': 'Actual live ingress',
            'senderId': 'bob',
            'senderType': 'user',
            'seq': 1,
          }),
        );
        await tester.pump(const Duration(milliseconds: 149));
        expect(api.inbox, hasLength(1));
        await tester.pump(const Duration(milliseconds: 1));
        await _dispatch(tester);
        expect(api.inbox, hasLength(2));
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            attention(),
            findsOneWidget,
            reason: 'background wait retains the accepted Activity total',
          );
        }
        await tester.runAsync(() async {
          live.complete(_window(0));
        });
        await tester.pumpAndSettle();
        expect(attention(), findsNothing);
        expect(w.section, 'chat');

        api.routes['GET /channels/inbox'] = (_) => _window(9);
        client.ingress.add(const RaftEvent('dm:new', {'channelId': 'dm-new'}));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(attention(), findsOneWidget);
        api.statuses['GET /channels/inbox'] = 500;
        client.ingress.add(
          const RaftEvent('thread:updated', {
            'threadChannelId': 't1',
            'parentMessageId': 'p1',
            'replyCount': 1,
          }),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(
          attention(),
          findsOneWidget,
          reason: 'transient failure retains the accepted private count',
        );
        api.statuses['GET /channels/inbox'] = 403;
        client.ingress.add(const RaftEvent('rooms:joined', null));
        await tester.pumpAndSettle();
        expect(
          attention(),
          findsNothing,
          reason: 'an actual HTTP authority denial clears the projection',
        );
        expect(w.section, 'chat');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  // The owner-only timer/transport checks below do not mount a product page.
  // Only the three actual Chat cases above supply mounted K09f evidence.
  testWidgets(
    'boot owner cancels offline fallback at rooms and excludes connect/update/read-state wake fetches',
    (tester) async {
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      api.routes['GET /channels/inbox'] = (_) => _window(4);
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      client.ingress.add(const RaftEvent('connected', null));
      client.ingress.add(
        const RaftEvent('message:updated', {'channelId': 'c1'}),
      );
      client.ingress.add(const RaftEvent('channel:updated', {'id': 'c1'}));
      client.ingress.add(
        const RaftEvent('sync:resume:response', {'messages': []}),
      );
      client.ingress.add(
        const RaftEvent('read_state:updated', {
          'serverId': 's1',
          'scopeId': 'c1',
        }),
      );
      await tester.pump(const Duration(milliseconds: 1999));
      expect(api.inbox, isEmpty);
      client.ingress.add(const RaftEvent('rooms:joined', null));
      await tester.pumpAndSettle();
      expect(api.inbox, hasLength(1));
      expect(store.totalUnreadCount, 4);
      await tester.pump(const Duration(seconds: 3));
      expect(api.inbox, hasLength(1));
    },
  );

  testWidgets(
    'offline boot fallback performs one real inbox request without requiring Activity navigation',
    (tester) async {
      final (w, api, _) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      api.routes['GET /channels/inbox'] = (_) => _window(3);
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(api.inbox, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(api.inbox, hasLength(1));
      expect(store.totalUnreadCount, 3);
      await tester.pump(const Duration(seconds: 5));
      expect(api.inbox, hasLength(1));
    },
  );

  testWidgets(
    'one trailing reconcile accepts ready hydration and shares a completion without request storms',
    (tester) async {
      final (w, api, _) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final first = Completer<Map<String, dynamic>>(),
          last = Completer<Map<String, dynamic>>();
      api.routes['GET /channels/inbox'] = (_) =>
          api.inbox.length == 1 ? first.future : last.future;
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      final opening = store.refresh();
      final trailing = store.refresh();
      expect(identical(trailing, store.refresh()), isTrue);
      await _dispatch(tester);
      expect(api.inbox, hasLength(1));
      await tester.runAsync(() async {
        first.complete(_window(5));
      });
      await _dispatch(tester);
      expect(store.totalUnreadCount, 5);
      expect(api.inbox, hasLength(2));
      await tester.runAsync(() async {
        last.complete(_window(0));
      });
      await tester.pumpAndSettle();
      await opening;
      await trailing;
      expect(store.totalUnreadCount, 0);
      expect(api.inbox, hasLength(2));
      store.dispose();
    },
  );

  testWidgets(
    'accepted page total supersedes old background response and denial fences pending acceptance',
    (tester) async {
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final held = Completer<Map<String, dynamic>>();
      api.routes['GET /channels/inbox'] = (_) => held.future;
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      final loading = store.refresh();
      await tester.pump();
      store.acceptWindow(_window(0), scope: store.scope);
      await tester.runAsync(() async {
        held.complete(_window(99));
      });
      await tester.pumpAndSettle();
      await loading;
      expect(store.totalUnreadCount, 0);
      client.ingress.add(
        const RaftEvent('server:membership-removed', {
          'serverId': 'other-server',
        }),
      );
      client.ingress.add(const RaftEvent('server:membership-removed', {}));
      expect(
        store.totalUnreadCount,
        0,
        reason:
            'unrelated or unidentified membership facts cannot deny this scope',
      );
      final denied = Completer<Map<String, dynamic>>();
      api.routes['GET /channels/inbox'] = (_) => denied.future;
      final old = store.refresh();
      await tester.pump();
      client.ingress.add(
        const RaftEvent('server:membership-removed', {'serverId': 's1'}),
      );
      expect(store.totalUnreadCount, isNull);
      store.acceptWindow(_window(88), scope: store.scope);
      await tester.runAsync(() async {
        denied.complete(_window(88));
      });
      await tester.pumpAndSettle();
      await old;
      expect(store.totalUnreadCount, isNull);
      store.dispose();
    },
  );

  testWidgets(
    'HTTP denial recovery rejects pre-denial page and read receipts in the same server scope',
    (tester) async {
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      store.acceptWindow(_window(7), scope: store.scope);
      final oldPageEpoch = store.authorityEpoch;
      final heldRead = Completer<Map<String, dynamic>>();
      api.routes['POST /channels/c1/read'] = (_) => heldRead.future;
      final oldRead = client.post('/channels/c1/read', data: {'seq': 10});
      await _dispatch(tester);
      api.statuses['GET /channels/inbox'] = 403;
      final failed = store.refresh();
      await _dispatch(tester);
      await failed;
      expect(store.totalUnreadCount, isNull);
      api.statuses.remove('GET /channels/inbox');
      api.routes['GET /channels/inbox'] = (_) => _window(0);
      client.ingress.add(const RaftEvent('rooms:joined', null));
      await _dispatch(tester);
      expect(store.totalUnreadCount, 0);
      store.acceptWindow(
        _window(88),
        scope: store.scope,
        authorityEpoch: oldPageEpoch,
      );
      store.deny(scope: store.scope, authorityEpoch: oldPageEpoch);
      expect(
        store.totalUnreadCount,
        0,
        reason:
            'a pre-denial page receipt cannot resurrect after room recovery',
      );
      await tester.runAsync(() async {
        heldRead.complete({'maxReadSeq': 10, 'readStateVersion': 1});
      });
      await _dispatch(tester);
      await oldRead;
      expect(
        api.inbox,
        hasLength(2),
        reason: 'the pre-denial read does not issue a post-recovery fetch',
      );
      store.dispose();
    },
  );

  testWidgets(
    'scope retirement rejects old server/principal/role snapshots and starts only current server load',
    (tester) async {
      final (w, api, _) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final s1 = Completer<Map<String, dynamic>>(),
          s2 = Completer<Map<String, dynamic>>();
      api.routes['GET /channels/inbox'] = (r) =>
          r.headers['X-Server-Id'] == 's1' ? s1.future : s2.future;
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      store.acceptWindow(_window(7), scope: store.scope);
      final opening = store.refresh();
      await tester.pump();
      w.client.selectServer('s2');
      w.server = RaftRecord({'id': 's2', 'role': 'owner'});
      w.notifyListeners();
      expect(store.totalUnreadCount, isNull);
      await tester.pump();
      await tester.runAsync(() async {
        s1.complete(_window(99));
        s2.complete(_window(2));
      });
      await tester.pumpAndSettle();
      await opening;
      expect(store.totalUnreadCount, 2);
      expect(api.inbox.map((r) => r.headers['X-Server-Id']), ['s1', 's2']);
      api.routes['GET /channels/inbox'] = (_) => _window(0);
      w.client.user = RaftRecord({'id': 'bob'});
      w.notifyListeners();
      expect(store.totalUnreadCount, isNull);
      await tester.pumpAndSettle();
      expect(store.totalUnreadCount, 0);
      store.acceptWindow(_window(6), scope: store.scope);
      w.server = RaftRecord({'id': 's2', 'role': 'guest'});
      w.notifyListeners();
      expect(store.totalUnreadCount, isNull);
      await tester.pumpAndSettle();
      expect(store.totalUnreadCount, 0);
    },
  );

  testWidgets(
    'Source mute policy ignores muted ingress but refreshes mentions, pre-mute history and thread context',
    (tester) async {
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      w.channels = [
        RaftChannel({
          'id': 'c1',
          'joined': true,
          'activityMuted': true,
          'muteFromSeq': 10,
        }),
      ];
      api.routes['GET /channels/inbox'] = (_) => _window(2);
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      client.ingress.add(
        const RaftEvent('message:new', {
          'id': 'muted-10',
          'channelId': 'c1',
          'seq': 10,
        }),
      );
      client.ingress.add(
        const RaftEvent('message:new', {
          'id': 'muted-11',
          'channelId': 'c1',
          'seq': 11,
          'mentions': [
            {'type': 'user', 'id': 'another'},
          ],
        }),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(api.inbox, isEmpty);
      for (final payload in [
        {
          'channelId': 'c1',
          'seq': 11,
          'mentions': [
            {'type': 'user', 'id': 'alice'},
          ],
        },
        {'channelId': 'c1', 'seq': 9},
        {
          'channelId': 'c1',
          'seq': 11,
          'conversationContext': {'channelType': 'thread'},
        },
      ]) {
        client.ingress.add(
          RaftEvent('message:new', {
            'id': 'accepted-${api.inbox.length}',
            ...payload,
          }),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
      }
      expect(api.inbox, hasLength(3));
      store.dispose();
    },
  );

  testWidgets(
    'accepted read authority clears fully-read row without GET and persisted acknowledgement reconciles',
    (tester) async {
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      store.acceptWindow({
        'totalUnreadCount': 3,
        'items': [
          {
            'kind': 'channel',
            'channelId': 'c1',
            'unreadCount': 2,
            'readState': {
              'kind': 'present',
              'latestActivity': {'seq': '10'},
            },
          },
          // A display seq from a parent channel cannot prove the thread read.
          {
            'kind': 'thread',
            'threadChannelId': 't1',
            'unreadCount': 1,
            'latestActivitySeq': '1',
          },
        ],
      }, scope: store.scope);
      client.ingress.add(
        const RaftEvent('read_state:updated', {
          'serverId': 's1',
          'scopeId': 'c1',
          'maxReadSeq': 10,
          'readStateVersion': 1,
        }),
      );
      await tester.pump();
      expect(store.totalUnreadCount, 1);
      expect(api.inbox, isEmpty);
      api.routes['POST /channels/c1/read'] = (_) => {
        'maxReadSeq': 10,
        'readStateVersion': 2,
      };
      api.routes['GET /channels/inbox'] = (_) => _window(0);
      final read = client.post('/channels/c1/read', data: {'seq': 10});
      await _dispatch(tester);
      await read;
      await _dispatch(tester);
      await tester.pumpAndSettle();
      expect(api.inbox, hasLength(1));
      expect(store.totalUnreadCount, 0);
      store.dispose();
    },
  );

  testWidgets(
    'a late old-scope persisted read cannot reconcile the new principal',
    (tester) async {
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      api.routes['GET /channels/inbox'] = (_) => _window(0);
      final heldRead = Completer<Map<String, dynamic>>();
      api.routes['POST /channels/c1/read'] = (_) => heldRead.future;
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      store.acceptWindow(_window(7), scope: store.scope);
      final oldRead = client.post('/channels/c1/read', data: {'seq': 10});
      await _dispatch(tester);
      expect(
        api.calls.where((r) => r.path == '/channels/c1/read'),
        hasLength(1),
      );
      w.client.user = RaftRecord({'id': 'bob'});
      w.notifyListeners();
      await _dispatch(tester);
      expect(store.totalUnreadCount, 0);
      expect(api.inbox, hasLength(1));
      await tester.runAsync(() async {
        heldRead.complete({'maxReadSeq': 10, 'readStateVersion': 1});
      });
      await _dispatch(tester);
      await oldRead;
      expect(
        api.inbox,
        hasLength(1),
        reason: 'the old principal read acknowledgement has no new-scope side effects',
      );
      expect(store.totalUnreadCount, 0);
      store.dispose();
    },
  );

  testWidgets(
    'accepted read revision rejects stale background count without display-sequence suppression',
    (tester) async {
      final (w, api, client) = (await tester.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final stale = Completer<Map<String, dynamic>>();
      api.routes['GET /channels/inbox'] = (_) => stale.future;
      final store = SourceActivityUnreadStore(w);
      addTearDown(store.dispose);
      final accepted = {
        'totalUnreadCount': 2,
        'items': [
          {
            'kind': 'channel',
            'channelId': 'c1',
            'unreadCount': 2,
            'readState': {
              'kind': 'present',
              'latestActivity': {'seq': '10'},
            },
          },
        ],
      };
      store.acceptWindow(accepted, scope: store.scope);
      final pending = store.refresh();
      await _dispatch(tester);
      client.ingress.add(
        const RaftEvent('read_state:updated', {
          'serverId': 's1',
          'scopeId': 'c1',
          'maxReadSeq': 10,
          'readStateVersion': 1,
        }),
      );
      expect(store.totalUnreadCount, 0);
      await tester.runAsync(() async {
        stale.complete(_window(99));
      });
      await _dispatch(tester);
      await pending;
      expect(store.totalUnreadCount, 0);
      expect(api.inbox, hasLength(1));
      store.dispose();
    },
  );
}
