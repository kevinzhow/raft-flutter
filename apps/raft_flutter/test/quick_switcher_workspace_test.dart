import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/recent_conversations.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/quick_switcher.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  final channelRows = [
    RaftChannel({
      'id': 'c-general',
      'name': 'general',
      'type': 'channel',
      'lastMessageAt': '2026-10-09T00:00:00Z',
      'joined': true,
    }),
    RaftChannel({
      'id': 'c-design',
      'name': 'design',
      'type': 'channel',
      'joined': true,
      'description': 'Design work',
      'lastMessageAt': '2026-10-08T00:00:00Z',
    }),
    RaftChannel({
      'id': 'c-ops',
      'name': 'ops',
      'type': 'channel',
      'lastMessageAt': '2026-10-07T00:00:00Z',
      'joined': true,
    }),
  ];
  final dmRows = [
    RaftChannel({
      'id': 'dm-bob',
      'type': 'dm',
      'peerId': 'bob',
      'peerType': 'user',
    }),
  ];
  final people = <Map<String, dynamic>>[
    {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob'},
    {'userId': 'carol', 'name': 'carol', 'displayName': 'Carol'},
  ];
  final agents = <Map<String, dynamic>>[
    {
      'id': 'a-cindy',
      'name': 'cindy',
      'displayName': 'Cindy',
      'status': 'active',
      'runtime': 'x',
      'model': 'y',
    },
  ];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? dmRows : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('messages:$id');
    return {'messages': [], 'threadSummariesByParentMessageId': {}};
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path.endsWith('/members')) return people;
    if (path == '/agents') return agents;
    if (path.endsWith('/machines')) return {'machines': []};
    if (path == '/messages/search') {
      return {
        'results': [
          {
            'id': 'hit',
            'channelId': 'c-ops',
            'channelName': 'ops',
            'channelType': 'channel',
            'senderId': 'bob',
            'senderName': 'Bob',
            'senderType': 'user',
            'snippet': 'quarterly plan',
            'createdAt': '2026-10-08T00:00:00Z',
          },
        ],
      };
    }
    if (path.startsWith('/channels/') && path.split('/').length == 3) {
      final id = path.split('/').last;
      final row = [
        ...channelRows,
        ...dmRows,
      ].where((c) => c.id == id).firstOrNull;
      if (row != null) return row.json;
    }
    if (path == '/channels/unread') return {'channels': {}};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    if (path == '/auth/providers') return {'providers': []};
    return [];
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) => method == 'POST' ? post(path, data: data) : get(path, query: query);

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path == '/channels/dm' && data is Map) {
      return {
        'id': 'dm-new',
        'type': 'dm',
        'peerId': data['userId'] ?? data['agentId'],
        'peerType': data['userId'] != null ? 'user' : 'agent',
      };
    }
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '2', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

Future<(_Client, WorkspaceController)> mount(
  WidgetTester t, {
  Size size = const Size(1280, 900),
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
  String section = 'chat',
}) async {
  SharedPreferences.setMockInitialValues({});
  DevicePreferences.adopt(await SharedPreferences.getInstance());
  addTearDown(DevicePreferences.reset);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final client = _Client()..selectServer('s');
  final w = WorkspaceController(client)
    ..server = RaftRecord({
      'id': 's',
      'slug': 'fixture',
      'name': 'Fixture',
      'role': 'owner',
    })
    ..channels = client.channelRows
    ..dms = client.dmRows
    ..channel = client.channelRows.first
    ..section = section;
  w.ledger.switchServer('s');
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: WorkspaceView(
        controller: w,
        appearance: const RaftAppearance(),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
  await t.pumpAndSettle();
  return (client, w);
}

Future<void> chord(
  WidgetTester t,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey k,
) async {
  await t.sendKeyDownEvent(modifier);
  await t.sendKeyEvent(k);
  await t.sendKeyUpEvent(modifier);
}

void main() {
  for (final modifier in [
    ('Ctrl', LogicalKeyboardKey.controlLeft),
    ('Cmd', LogicalKeyboardKey.metaLeft),
  ]) {
    testWidgets(
      '[N26] ${modifier.$1}+K floats the switcher over the current conversation with cached results in its first frame',
      (t) async {
        final (client, w) = await mount(t);
        expect(find.byType(QuickSwitcher), findsNothing);
        final calls = client.calls.length;
        await chord(t, modifier.$2, LogicalKeyboardKey.keyK);
        // One frame: the overlay and its rows are already there; no request.
        await t.pump();
        expect(find.byType(QuickSwitcher), findsOneWidget);
        expect(find.byKey(const Key('quick-switcher-recent')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('quick-switcher-channel:c-design')),
          findsOneWidget,
        );
        expect(client.calls.length, calls);
        // The page behind keeps its place.
        expect(w.section, 'chat');
        expect(w.channel!.id, 'c-general');
        expect(find.byType(ResourceView), findsNothing);
        // Typing finds a person and a profile-less agent from cached lists.
        await t.enterText(find.byType(TextField).last, 'cin');
        await t.pump();
        expect(
          find.byKey(const ValueKey('quick-switcher-agent:a-cindy')),
          findsOneWidget,
        );
        await key(t, LogicalKeyboardKey.escape);
        expect(find.byType(QuickSwitcher), findsNothing);
        expect(w.channel!.id, 'c-general');
      },
    );
  }

  testWidgets(
    '[N26] choosing a channel opens it like the sidebar and the next opening lists it first',
    (t) async {
      final (client, w) = await mount(t);
      await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
      await t.pump();
      await t.enterText(find.byType(TextField).last, 'ops');
      await t.pump();
      await key(t, LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byType(QuickSwitcher), findsNothing);
      expect(w.channel!.id, 'c-ops');
      expect(w.section, 'chat');
      // The visit is remembered per workspace and account, and survives a
      // new store (restart) through the device preference.
      final scope = RecentConversationScope(client.origin, 's', 'alice');
      expect(RecentConversationStore().idsFor(scope).take(2).toList(), [
        'c-ops',
        'c-general',
      ]);
      await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
      await t.pump();
      // The conversation behind the overlay is never listed.
      expect(
        find.byKey(const ValueKey('quick-switcher-channel:c-ops')),
        findsNothing,
      );
      expect(
        t
            .getTopLeft(
              find.byKey(const ValueKey('quick-switcher-channel:c-general')),
            )
            .dy,
        lessThan(
          t
              .getTopLeft(
                find.byKey(const ValueKey('quick-switcher-channel:c-design')),
              )
              .dy,
        ),
      );
    },
  );

  testWidgets('[N26] a person without a DM creates one and opens it', (
    t,
  ) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.enterText(find.byType(TextField).last, 'carol');
    await t.pump();
    await key(t, LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(client.calls, contains('POST:/channels/dm'));
    expect(w.channel!.id, 'dm-new');
    expect(find.byType(QuickSwitcher), findsNothing);
  });

  testWidgets('[N26] a person with a DM opens it without a request', (t) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.enterText(find.byType(TextField).last, 'bob');
    await t.pump();
    final posts = client.calls.where((c) => c.startsWith('POST:/channels/dm'));
    await key(t, LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(posts, isEmpty);
    expect(w.channel!.id, 'dm-bob');
  });

  testWidgets('[N26] the Search for row opens the full page with the query', (
    t,
  ) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.enterText(find.byType(TextField).last, 'quarterly');
    await t.pump();
    await key(t, LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
    expect(w.section, 'search');
    expect(find.byType(ResourceView), findsOneWidget);
    expect(w.location.query('q'), 'quarterly');
  });

  testWidgets('[N26] a message preview hit jumps to the message', (t) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.enterText(find.byType(TextField).last, 'quarterly');
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    expect(
      find.textContaining('quarterly plan', findRichText: true),
      findsOneWidget,
    );
    await key(t, LogicalKeyboardKey.arrowDown);
    await key(t, LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(w.channel!.id, 'c-ops');
    expect(find.byType(QuickSwitcher), findsNothing);
  });

  testWidgets('[N26] clicking outside the card closes the switcher', (t) async {
    final (_, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
    expect(w.channel!.id, 'c-general');
  });

  testWidgets('[N26] a narrow window keeps the full Search page', (t) async {
    final (_, w) = await mount(t, size: const Size(390, 844));
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
    expect(w.section, 'search');
  });

  testWidgets('Cmd+, still opens settings and Escape still dismisses panels', (
    t,
  ) async {
    final (_, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.comma);
    await t.pumpAndSettle();
    expect(w.section, 'settings');
    expect(find.byType(QuickSwitcher), findsNothing);
  });

  testWidgets('[N26] the switcher closes when the workspace scope changes', (
    t,
  ) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    expect(find.byType(QuickSwitcher), findsOneWidget);
    w.server = RaftRecord({
      'id': 's2',
      'slug': 'other',
      'name': 'Other',
      'role': 'owner',
    });
    w.notifyListeners();
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
  });

  testWidgets(
    '[N26] the shortcut works from inside the composer, not with extra modifiers, and not under a dialog',
    (t) async {
      final (_, w) = await mount(t);
      await t.tap(find.byType(TextField).first);
      await t.pump();
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyK);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
      expect(find.byType(QuickSwitcher), findsNothing);
      await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
      await t.pump();
      expect(find.byType(QuickSwitcher), findsOneWidget);
      // A second press while open leaves exactly one switcher.
      await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
      await t.pump();
      expect(find.byType(QuickSwitcher), findsOneWidget);
      expect(w.section, 'chat');
    },
  );
}

Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump();
}
