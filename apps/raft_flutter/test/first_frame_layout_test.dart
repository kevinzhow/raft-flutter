import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First frame final: layout that depends on device preferences or on the
/// last evaluated feature flags is already right on the first frame, and the
/// fresh evaluation replaces it in place (no jump after load).
const _origin = 'https://public-fixture.invalid';

class _Client extends RaftClient {
  _Client() : super(origin: _origin, sessionStore: MemorySessionStore()) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  Future<dynamic> Function()? flags;
  final channelRows = [
    RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
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
      dm ? [] : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {'messages': [], 'threadSummariesByParentMessageId': {}};
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/channels/c') {
      return {'id': 'c', 'serverId': 's', 'name': 'design', 'joined': true};
    }
    if (path == '/channels/unread') return {'channels': {}};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/channels/inbox') return {'items': []};
    if (path == '/channels/saved') {
      return {'globalTotal': 0, 'total': 0, 'saved': []};
    }
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    if (path == '/auth/providers') return {'providers': []};
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path == '/feature-flags/evaluate') {
      return flags?.call() ?? {'evaluations': []};
    }
    return {};
  }
}

Map<String, dynamic> _evaluations(Map<String, bool> flags) => {
  'evaluations': [
    for (final e in flags.entries) {'key': e.key, 'enabled': e.value},
  ],
};

const _scope = [_origin, 'alice', 's', 'owner'];

Future<(WorkspaceController, _Client)> _mount(
  WidgetTester t, {
  required Size size,
  required String section,
  Map<String, Object> prefs = const {},
  Map<String, bool> remembered = const {},
  bool mobile = false,
  Future<dynamic> Function()? flags,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  DevicePreferences.reset();
  // App start: the preferences are loaded before the first workspace frame.
  await t.runAsync(DevicePreferences.load);
  if (remembered.isNotEmpty) FeatureFlagMemory.write(_scope, remembered);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = _Client()..flags = flags;
  c.selectServer('s');
  final w = WorkspaceController(c, mobileNavigation: mobile)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
    ..channels = c.channelRows
    ..channel = c.channelRows.single
    ..section = section;
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: WorkspaceView(
        controller: w,
        appearance: const RaftAppearance(),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
  return (w, c);
}

Future<void> _frames(WidgetTester t, void Function() each, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump(const Duration(milliseconds: 16));
    each();
  }
}

void main() {
  tearDown(DevicePreferences.reset);

  testWidgets(
    'Activity master-detail uses the remembered flag on the first frame; '
    'the evaluation lands without moving the layout',
    (t) async {
      final held = Completer<dynamic>();
      final (w, c) = await _mount(
        t,
        size: const Size(900, 800),
        section: 'activity',
        remembered: {'activity_sidebar_inbox_v0': true},
        flags: () => held.future,
      );
      expect(w.section, 'activity');
      // The compact (768) breakpoint already applies at 900px on frame one.
      final toolbar = find.byType(RaftActivityScopeToolbar);
      expect(toolbar, findsOneWidget);
      expect(t.widget<RaftActivityScopeToolbar>(toolbar).compact, isTrue);
      final rect = t.getRect(toolbar);
      await _frames(t, () => expect(t.getRect(toolbar), rect), 4);
      held.complete(_evaluations({'activity_sidebar_inbox_v0': true}));
      await _frames(t, () {
        expect(toolbar, findsOneWidget);
        expect(t.getRect(toolbar), rect);
        expect(t.widget<RaftActivityScopeToolbar>(toolbar).compact, isTrue);
      });
      expect(c.calls, contains('POST:/feature-flags/evaluate'));
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a flag turned off since the last launch is corrected in place', (
    t,
  ) async {
    final (w, c) = await _mount(
      t,
      size: const Size(900, 800),
      section: 'activity',
      remembered: {'activity_sidebar_inbox_v0': true},
    );
    expect(w.section, 'activity');
    await _frames(t, () {});
    // Default evaluation (flag off) replaces the remembered value.
    expect(FeatureFlagMemory.read(_scope, 'activity_sidebar_inbox_v0'), false);
    await t.pumpWidget(const SizedBox());
    expect(c.calls, contains('POST:/feature-flags/evaluate'));
  });

  testWidgets('IM Bridges settings entry is present on the first frame', (
    t,
  ) async {
    final held = Completer<dynamic>();
    final (w, _) = await _mount(
      t,
      size: const Size(390, 844),
      section: 'home',
      mobile: true,
      remembered: {'slack_bridge_v0': true, 'provider_connections_v0': true},
      flags: () => held.future,
    );
    await _frames(t, () {}, 3);
    await t.tap(find.byKey(const Key('mobile-tab-settings')));
    await _frames(t, () {}, 3);
    final entry = find.byKey(
      const ValueKey('workspace-settings-nav-im-bridges'),
    );
    expect(entry, findsOneWidget);
    final rect = t.getRect(entry);
    held.complete(
      _evaluations({'slack_bridge_v0': true, 'provider_connections_v0': true}),
    );
    await _frames(t, () {
      expect(entry, findsOneWidget);
      expect(t.getRect(entry), rect);
    });
    expect(w.section, 'settings');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('without a remembered flag the entry waits for the evaluation', (
    t,
  ) async {
    await _mount(
      t,
      size: const Size(390, 844),
      section: 'home',
      mobile: true,
      flags: () async => _evaluations({'slack_bridge_v0': true}),
    );
    await t.tap(find.byKey(const Key('mobile-tab-settings')));
    await _frames(t, () {});
    expect(
      find.byKey(const ValueKey('workspace-settings-nav-im-bridges')),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a collapsed sidebar section is collapsed on the first frame', (
    t,
  ) async {
    await _mount(
      t,
      size: const Size(390, 844),
      section: 'home',
      mobile: true,
      prefs: {
        'raft:sidebar-disclosure:'
                '["$_origin","alice","s"]':
            '{"system:channels":true}',
      },
    );
    // Frame one: the section header is there, its rows are not.
    expect(
      find.byKey(const ValueKey('sidebar-section-system:channels')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sidebar-channel-c')), findsNothing);
    await _frames(t, () {
      expect(find.byKey(const ValueKey('sidebar-channel-c')), findsNothing);
    });
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('earlier saves are loaded on connect, even off the sidebar', (
    t,
  ) async {
    final (_, c) = await _mount(
      t,
      size: const Size(390, 844),
      section: 'home',
      mobile: true,
    );
    await t.tap(find.byKey(const Key('mobile-tab-settings')));
    await _frames(t, () {});
    expect(c.calls, contains('GET:/channels/saved'));
    await t.pumpWidget(const SizedBox());
  });
}
