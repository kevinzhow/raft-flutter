import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'message_presentation_test.dart' show MessageAdapter;
import 'support/app_services_fixture.dart';

class _Adapter extends MessageAdapter {
  bool failUnread = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancellation,
  ) async {
    if (failUnread &&
        request.method == 'POST' &&
        request.path.endsWith('/unread')) {
      calls.add(request);
      return ResponseBody.fromString(
        jsonEncode({'error': 'Unread write failed'}),
        500,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return super.fetch(request, stream, cancellation);
  }
}

class _Client extends RaftClient {
  _Client(_Adapter api)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = api,
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  void emit(String name, Object payload) =>
      ingress.add(RaftEvent(name, payload));
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

class _Scene {
  _Scene(this.w, this.api, this.client, this.kind, this.platform, this.served);
  final WorkspaceController w;
  final _Adapter api;
  final _Client client;
  final String kind;
  final TargetPlatform platform;
  Map<String, dynamic> served;
  final unreadAck = Completer<dynamic>();
  final readAck = Completer<dynamic>();
  String get id => kind == 'thread'
      ? 'thread-1'
      : kind == 'dm'
      ? 'd1'
      : 'c1';
  Finder get card => find.byKey(ValueKey('activity-$kind-$id'));
  Finder get badge => find.descendant(
    of: card,
    matching: find.byKey(const ValueKey('conversation-card-new-badge')),
  );
  dynamic get page => WidgetsBinding.instance is TestWidgetsFlutterBinding
      ? (find.byType(ResourceView).evaluate().single as StatefulElement).state
      : null;

  Map<String, dynamic> answer(int count, int cursor, int version) => {
    'ok': true,
    'unreadCount': count,
    'maxReadSeq': '$cursor',
    'readStateVersion': version,
  };

  Map<String, dynamic> readAnswer(int count, int cursor, int version) => {
    'ok': true,
    'unreadCount': count,
    'seq': cursor,
    'maxReadSeq': cursor,
    'readStateVersion': version,
  };

  void serve(int count, int cursor, int version) {
    served = {
      ...served,
      'unreadCount': count,
      'readState': {
        ...(served['readState'] as Map),
        'maxReadSeq': '$cursor',
        'readStateVersion': version,
      },
    };
  }

  void serveSummary(int count, int cursor, int version) {
    api.routes['GET /channels/unread'] = (_) => {
      'channels': {
        id: {
          'unreadCount': count,
          'readState': {
            ...(served['readState'] as Map),
            'maxReadSeq': '$cursor',
            'readStateVersion': version,
          },
        },
      },
    };
  }

  Future<void> reload(WidgetTester tester) async {
    final loaded = page.load(keep: true, quietErrors: true);
    await tester.pumpAndSettle();
    await loaded;
  }

  Widget app() => MaterialApp(
    theme: raftTheme().copyWith(platform: platform),
    home: withAppServices(
      WorkspaceView(
        controller: w,
        appearance: const RaftAppearance(),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );

  Future<void> toggle(WidgetTester tester) async {
    if (platform == TargetPlatform.android) {
      await tester.longPress(card);
    } else {
      await tester.tapAt(
        tester.getCenter(card),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity-menu-toggle-read')));
    await tester.pumpAndSettle();
  }

  void expectCount(WidgetTester tester, int count) {
    expect(w.section, 'activity');
    expect(card, findsOneWidget);
    expect(badge, count == 0 ? findsNothing : findsOneWidget);
    if (count > 0) {
      expect(
        tester
            .widget<RaftSidebarUnreadCount>(
              find.descendant(
                of: badge,
                matching: find.byType(RaftSidebarUnreadCount),
              ),
            )
            .count,
        count,
      );
    }
    expect(
      page.totalUnreadCount,
      count,
      reason: 'the Activity filter count follows the same accepted row',
    );
    expect(
      w.activityUnread.totalUnreadCount,
      count,
      reason: 'the shared Activity badge follows the same accepted row',
    );
  }

  Future<void> close(WidgetTester tester) async {
    if (!unreadAck.isCompleted) unreadAck.complete(readAnswer(0, 5, 1));
    if (!readAck.isCompleted) readAck.complete(readAnswer(0, 5, 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }
}

Future<_Scene> _mount(
  WidgetTester tester, {
  String kind = 'thread',
  TargetPlatform platform = TargetPlatform.android,
  Size size = const Size(390, 844),
  int initialUnread = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _Adapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final (client, w) = (await tester.runAsync(() async {
    final client = _Client(api);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true})
      ..channels = [
        RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
      ]
      ..dms = [
        RaftChannel({'id': 'd1', 'name': 'Bob', 'type': 'dm', 'joined': true}),
      ]
      ..loading = false
      ..section = 'activity';
    return (client, w);
  }))!;
  addTearDown(w.dispose);
  final row = activityRow(kind, unread: initialUnread);
  row['readState'] = {
    'kind': 'present',
    'maxReadSeq': initialUnread == 0 ? '5' : '0',
    'readStateVersion': 1,
    'latestActivity': {'messageId': 'm5', 'seq': '5'},
  };
  final scene = _Scene(w, api, client, kind, platform, row);
  w.readState.consumeUpdate(
    {
      'serverId': 's1',
      'scopeId': scene.id,
      'maxReadSeq': initialUnread == 0 ? 5 : 0,
      'readStateVersion': 1,
    },
    serverId: 's1',
    principalId: 'alice',
  );
  api.routes['GET /channels/inbox'] = (_) => {
    'items': [scene.served],
    'totalCount': 1,
    'totalUnreadCount': scene.served['unreadCount'],
    'hasMore': false,
  };
  api.routes['GET /channels/unread'] = (_) => {
    'channels': {
      scene.id: {
        'unreadCount': scene.served['unreadCount'],
        'readState': scene.served['readState'],
      },
    },
  };
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'activity_conversation_list_v0', 'enabled': true},
    ],
  };
  api.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  api.routes['POST /channels/${scene.id}/unread'] = (_) =>
      scene.unreadAck.future;
  api.routes['POST /channels/${scene.id}/read-all'] = (_) =>
      scene.readAck.future;
  // Establish the real session-owned Activity cache before the product route.
  w.activityUnread;
  await tester.pumpWidget(scene.app());
  await tester.pumpAndSettle();
  return scene;
}

void main() {
  for (final (kind, platform, size) in [
    ('thread', TargetPlatform.android, const Size(390, 844)),
    ('channel', TargetPlatform.android, const Size(856, 944)),
    ('dm', TargetPlatform.android, const Size(944, 856)),
    ('thread', TargetPlatform.linux, const Size(390, 844)),
    ('channel', TargetPlatform.linux, const Size(1440, 900)),
  ]) {
    testWidgets(
      '$kind ${platform.name} $size unread ACK updates the same Activity row and counts',
      (tester) async {
        final scene = await _mount(
          tester,
          kind: kind,
          platform: platform,
          size: size,
        );
        try {
          scene.expectCount(tester, 0);
          final readsBefore = scene.api.calls
              .where((c) => c.path == '/channels/inbox')
              .length;
          await scene.toggle(tester);
          scene.expectCount(tester, 0);
          expect(
            scene.api.calls.where(
              (c) =>
                  c.method == 'POST' &&
                  c.path == '/channels/${scene.id}/unread',
            ),
            hasLength(1),
          );
          scene.unreadAck.complete(scene.answer(1, 4, 2));
          await tester.pumpAndSettle();
          scene.expectCount(tester, 1);
          expect(scene.w.conversationReads.unread[scene.id], 1);
          expect(
            scene.api.calls.where((c) => c.path == '/channels/inbox'),
            hasLength(readsBefore),
            reason: 'an accepted ACK does not force a redundant inbox reload',
          );
        } finally {
          await scene.close(tester);
        }
      },
    );
  }

  for (final outcome in ['failed', 'no eligible message']) {
    testWidgets('Activity unread $outcome never invents an unread badge', (
      tester,
    ) async {
      final scene = await _mount(tester);
      try {
        if (outcome == 'failed') scene.api.failUnread = true;
        await scene.toggle(tester);
        if (outcome != 'failed') {
          scene.unreadAck.complete(scene.answer(0, 5, 2));
        }
        await tester.pumpAndSettle();
        scene.expectCount(tester, 0);
      } finally {
        await scene.close(tester);
      }
    });
  }

  testWidgets(
    'a newer unread ACK survives a still-pending older Activity read-all',
    (tester) async {
      final scene = await _mount(tester, initialUnread: 2);
      try {
        scene.expectCount(tester, 2);
        await scene.toggle(tester);
        scene.expectCount(tester, 0);
        await scene.toggle(tester);
        scene.unreadAck.complete(scene.answer(1, 4, 3));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        scene.readAck.complete(scene.readAnswer(0, 5, 2));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        expect(scene.w.conversationReads.unread[scene.id], 1);
      } finally {
        await scene.close(tester);
      }
    },
  );

  testWidgets(
    'a conversation read does not consume an independent mention-action notification',
    (tester) async {
      final scene = await _mount(tester, kind: 'channel');
      try {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final store = scene.w.activityUnread;
        store.acceptWindow(
          {
            'items': [
              {
                ...scene.served,
                'kind': 'mention_action',
                'id': 'provider-notification',
                'unreadCount': 1,
              },
            ],
            'totalUnreadCount': 1,
          },
          scope: store.scope,
          firstPage: true,
        );
        expect(store.totalUnreadCount, 1);
        expect(store.acceptedRows.single['unreadCount'], 1);
        expect(store.windowSince(0)!['items'].single['unreadCount'], 1);
      } finally {
        await scene.close(tester);
      }
    },
  );

  testWidgets(
    'an older read-state echo cannot erase a newer accepted unread ACK',
    (tester) async {
      final scene = await _mount(tester);
      try {
        await scene.toggle(tester);
        scene.unreadAck.complete(scene.answer(1, 4, 2));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        scene.client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': scene.id,
          'maxReadSeq': 5,
          'readStateVersion': 1,
        });
        await tester.pump();
        scene.expectCount(tester, 1);
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
      } finally {
        await scene.close(tester);
      }
    },
  );

  testWidgets(
    'an accepted unread survives reopen and a newer read-state event clears it',
    (tester) async {
      final scene = await _mount(tester);
      try {
        await scene.toggle(tester);
        scene.unreadAck.complete(scene.answer(1, 4, 2));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(scene.app());
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        scene.serve(0, 5, 3);
        scene.client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': scene.id,
          'maxReadSeq': 5,
          'readStateVersion': 3,
        });
        await tester.pump();
        scene.expectCount(tester, 0);
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 0);
        expect(
          scene.w.activityUnread.windowSince(0)!['items'].single['unreadCount'],
          0,
        );
      } finally {
        await scene.close(tester);
      }
    },
  );

  testWidgets(
    'Activity retains an unread ACK after the conversation summary converges first',
    (tester) async {
      final scene = await _mount(tester);
      try {
        final stale = scene.served;
        scene.serveSummary(1, 4, 2);
        await scene.toggle(tester);
        scene.unreadAck.complete(scene.answer(1, 4, 2));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        expect(scene.w.conversationReads.queue.receipt(scene.id), isNull);
        // The inbox still serves v1 even though /channels/unread serves v2.
        await scene.reload(tester);
        scene.expectCount(tester, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(scene.app());
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);

        // Once the Activity snapshot itself reaches v2, its exact newer count
        // owns the row, including new activity at the same read-cursor version.
        scene.serve(2, 4, 2);
        scene.served = {
          ...scene.served,
          'latestActivitySeq': '6',
          'readState': {
            ...(scene.served['readState'] as Map),
            'latestActivity': {'messageId': 'm6', 'seq': '6'},
          },
        };
        await scene.reload(tester);
        scene.expectCount(tester, 2);
        // A later older window cannot regress an already accepted Activity row.
        scene.served = stale;
        await scene.reload(tester);
        scene.expectCount(tester, 2);

        scene.serve(0, 6, 3);
        scene.client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': scene.id,
          'maxReadSeq': 6,
          'readStateVersion': 3,
        });
        await tester.pump();
        scene.expectCount(tester, 0);
        await tester.pumpAndSettle();
        scene.expectCount(tester, 0);
      } finally {
        await scene.close(tester);
      }
    },
  );

  testWidgets(
    'a lagging Activity window and older read-all cannot replace a newer unread',
    (tester) async {
      final scene = await _mount(tester, initialUnread: 2);
      try {
        await scene.toggle(tester);
        scene.expectCount(tester, 0);
        scene.serveSummary(1, 4, 3);
        await scene.toggle(tester);
        scene.unreadAck.complete(scene.answer(1, 4, 3));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        expect(scene.w.conversationReads.queue.receipt(scene.id), isNull);
        await scene.reload(tester);
        scene.expectCount(tester, 1);
        scene.readAck.complete(scene.readAnswer(0, 5, 2));
        scene.client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': scene.id,
          'maxReadSeq': 5,
          'readStateVersion': 2,
        });
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        expect(scene.w.conversationReads.unread[scene.id], 1);
      } finally {
        await scene.close(tester);
      }
    },
  );

  testWidgets(
    'an accepted positive unread count survives lagging Activity preview metadata',
    (tester) async {
      final scene = await _mount(tester);
      try {
        final stale = scene.served;
        await scene.toggle(tester);
        // The server has eligible message6; Activity still only describes5.
        scene.unreadAck.complete(scene.answer(1, 5, 2));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        expect(scene.served['latestActivitySeq'], '5');
        scene.client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': scene.id,
          'maxReadSeq': 5,
          'readStateVersion': 2,
        });
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        // The summary converges first and explicitly reports message6, while
        // the independent Activity window continues serving its old message5.
        scene.api.routes['GET /channels/unread'] = (_) => {
          'channels': {
            scene.id: {
              'unreadCount': 1,
              'readState': {
                'kind': 'present',
                'maxReadSeq': '5',
                'readStateVersion': 2,
                'latestActivity': {'messageId': 'm6', 'seq': '6'},
              },
            },
          },
        };
        final summary = scene.w.conversationReads.refreshUnread();
        await tester.pumpAndSettle();
        await summary;
        expect(scene.w.conversationReads.queue.receipt(scene.id), isNull);
        scene.expectCount(tester, 1);
        await scene.reload(tester);
        scene.expectCount(tester, 1);
        // Equal-version canonical Activity data owns its exact count once it
        // arrives; these message facts come from the fixture server, not a
        // count-to-sequence inference in product code.
        scene.serve(2, 5, 2);
        scene.served = {
          ...scene.served,
          'latestActivitySeq': '7',
          'readState': {
            ...(scene.served['readState'] as Map),
            'latestActivity': {'messageId': 'm7', 'seq': '7'},
          },
        };
        await scene.reload(tester);
        scene.expectCount(tester, 2);
        scene.served = stale;
        await scene.reload(tester);
        scene.expectCount(tester, 2);
        scene.client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': scene.id,
          'maxReadSeq': 7,
          'readStateVersion': 3,
        });
        await tester.pumpAndSettle();
        scene.expectCount(tester, 0);
      } finally {
        await scene.close(tester);
      }
    },
  );

  testWidgets(
    'a later read intent survives a stale reload until its numeric read-all ACK',
    (tester) async {
      final scene = await _mount(tester);
      try {
        await scene.toggle(tester);
        scene.unreadAck.complete(scene.answer(1, 5, 2));
        await tester.pumpAndSettle();
        scene.expectCount(tester, 1);
        await scene.toggle(tester);
        scene.expectCount(tester, 0);
        await scene.reload(tester);
        scene.expectCount(tester, 0);
        scene.readAck.complete(scene.readAnswer(0, 6, 3));
        await tester.pumpAndSettle();
        expect(
          scene.w.readState.state('s1', 'alice', scene.id)?['readStateVersion'],
          3,
        );
        scene.expectCount(tester, 0);
        expect(scene.w.conversationReads.queue.receipt(scene.id), isNull);
      } finally {
        await scene.close(tester);
      }
    },
  );

  testWidgets(
    'a newer canonical unread version and a later read intent outrank older ledger facts',
    (tester) async {
      final scene = await _mount(tester);
      try {
        scene.expectCount(tester, 0);
        scene.serve(1, 4, 2);
        await scene.reload(tester);
        scene.expectCount(tester, 1);
        await scene.toggle(tester);
        scene.expectCount(tester, 0);
        // This version was already visible when Read was pressed. Its late
        // ledger arrival does not acknowledge the subsequent read request.
        scene.client.emit('read_state:updated', {
          'serverId': 's1',
          'scopeId': scene.id,
          'maxReadSeq': 4,
          'readStateVersion': 2,
        });
        await tester.pumpAndSettle();
        await scene.reload(tester);
        scene.expectCount(tester, 0);
        scene.readAck.complete(scene.readAnswer(0, 5, 3));
        await tester.pumpAndSettle();
        expect(
          scene.w.readState.state('s1', 'alice', scene.id)?['readStateVersion'],
          3,
        );
        scene.expectCount(tester, 0);
      } finally {
        await scene.close(tester);
      }
    },
  );
}
