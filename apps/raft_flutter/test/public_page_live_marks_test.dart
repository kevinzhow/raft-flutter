import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/public_page_live.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'human', 'name': 'Public Human'});
    selectServer('s');
  }
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path == '/channels/unread') return {'channels': {}};
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
  @override
  void joinChannel(String id) {}
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {'messages': []};
}

RaftChannel _channel(
  String id, {
  bool guestVisible = false,
  bool archived = false,
  String type = 'channel',
}) => RaftChannel({
  'id': id,
  'serverId': 's',
  'name': 'chan-$id',
  'type': type,
  'joined': true,
  'guestVisible': guestVisible,
  'archivedAt': archived ? '2026-10-01T00:00:00Z' : null,
});

WorkspaceController _workspace({required bool live}) {
  final client = _Client();
  final server = RaftRecord({
    'id': 's',
    'role': 'owner',
    'name': 'Public fixture',
    'publicPageLive': live,
  });
  final w = WorkspaceController(client)
    ..server = server
    ..servers = [server]
    ..channels = [
      _channel('open', guestVisible: true),
      _channel('closed'),
      _channel('old', guestVisible: true, archived: true),
      _channel('priv', guestVisible: true, type: 'private'),
    ]
    ..section = 'home';
  addTearDown(() async {
    w.dispose();
    await client.dispose();
  });
  return w;
}

Future<void> _pump(WidgetTester t, WorkspaceController w) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
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
  await t.pumpAndSettle();
}

Finder _inRow(String id) => find.descendant(
  of: find.byKey(ValueKey('sidebar-channel-$id')),
  matching: find.byKey(const ValueKey('public-channel-mark')),
);

void main() {
  testWidgets(
    'a live public page marks the channels anyone can read, and the server name',
    (t) async {
      final w = _workspace(live: true);
      await _pump(t, w);
      expect(_inRow('open'), findsOneWidget);
      // Not guest visible, archived, or not an ordinary channel: no mark.
      expect(_inRow('closed'), findsNothing);
      expect(_inRow('old'), findsNothing);
      expect(_inRow('priv'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('mobile-server-selector')),
          matching: find.byKey(const ValueKey('public-page-globe')),
        ),
        findsOneWidget,
      );

      await t.tap(find.byKey(const ValueKey('sidebar-channel-open')));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('workspace-mobile-detail-header')),
          matching: find.byKey(const ValueKey('public-channel-mark')),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('nothing is marked while the public page is not live', (t) async {
    final w = _workspace(live: false);
    await _pump(t, w);
    expect(find.byKey(const ValueKey('public-channel-mark')), findsNothing);
    expect(find.byKey(const ValueKey('public-page-globe')), findsNothing);
    await t.tap(find.byKey(const ValueKey('sidebar-channel-open')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('public-channel-mark')), findsNothing);
  });

  test(
    'the fresh server list decides, so a flip shows without reselecting',
    () {
      final w = _workspace(live: false);
      expect(serverPublicPageLive(w), isFalse);
      w.servers = [
        RaftRecord({
          'id': 's',
          'name': 'Public fixture',
          'publicPageLive': true,
        }),
      ];
      expect(serverPublicPageLive(w), isTrue);
      expect(
        channelOnPublicPage(w, _channel('open', guestVisible: true)),
        isTrue,
      );
      expect(channelOnPublicPage(w, _channel('closed')), isFalse);
    },
  );
}
