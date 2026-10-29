import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_flutter/features/member_graph_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/app_services_fixture.dart';

Map<String, dynamic> _human(String id, String name, List<String> channels) => {
  'type': 'human',
  'id': id,
  'name': name.toLowerCase(),
  'displayName': name,
  'avatarUrl': null,
  'gravatarHash': '',
  'role': 'member',
  'channelIds': channels,
};

Map<String, dynamic> _agent(String id, String name, List<String> channels) => {
  'type': 'agent',
  'id': id,
  'name': name.toLowerCase(),
  'displayName': name,
  'avatarUrl': 'pixel:robot',
  'status': 'active',
  'runtime': 'codex',
  'channelIds': channels,
};

final _graph = {
  'humans': [
    _human('h1', 'Ann', ['c1']),
    _human('h2', 'Bob', ['c1']),
  ],
  'agents': [
    _agent('a1', 'Cindy', ['c1']),
  ],
  'channels': [
    {
      'id': 'c1',
      'name': 'design',
      'type': 'channel',
      'archivedAt': null,
      'humanCount': 2,
      'agentCount': 1,
      'memberCount': 3,
    },
  ],
  'edges': [],
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final calls = <String>[];
  Object? Function() graph = () => _graph;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
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
  }) async {
    calls.add('$method $path');
    if (path == '/servers/s/member-graph') {
      final out = graph();
      if (out is Exception) throw out;
      return out;
    }
    return [];
  }
}

Future<(WorkspaceController, _Client)> _pump(
  WidgetTester tester, {
  String role = 'owner',
  _Client? client,
  Size size = const Size(1100, 900),
  Widget Function(WorkspaceController)? body,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = (client ?? _Client())..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({
      'id': 's',
      'slug': 'fixture',
      'name': 'Fixture',
      'role': role,
    });
  w.navigation.bind(
    'a/s/$role',
    RaftLocation.at(serverSlug: 'fixture', route: RaftRoute.memberGraph),
  );
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: body?.call(w) ?? MemberGraphPage(controller: w, onBack: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (w, c);
}

Finder _node(String key) => find.byKey(ValueKey('member-graph-node-$key'));

void main() {
  testWidgets('loads the graph, titles the page and counts the members', (
    tester,
  ) async {
    final (_, client) = await _pump(tester);
    expect(client.calls, ['GET /servers/s/member-graph']);
    expect(find.text('Graph'), findsOneWidget);
    expect(find.text('Experimental'), findsOneWidget);
    expect(
      find.textContaining('Connections', findRichText: true),
      findsOneWidget,
    );
    for (final key in ['human:h1', 'human:h2', 'agent:a1']) {
      expect(_node(key), findsOneWidget, reason: key);
    }
    expect(find.text('design'), findsOneWidget);
    expect(find.text('2H/1A'), findsOneWidget);
  });

  testWidgets('a failed read shows its message and Refresh retries', (
    tester,
  ) async {
    final client = _Client()
      ..graph = () => RaftApiException.response(
        'Graph unavailable',
        status: 500,
        body: {'error': 'Graph unavailable'},
      );
    await _pump(tester, client: client);
    expect(find.text('Graph unavailable'), findsOneWidget);
    expect(_node('human:h1'), findsNothing);
    client.graph = () => _graph;
    await tester.tap(find.byKey(const ValueKey('member-graph-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Graph unavailable'), findsNothing);
    expect(_node('human:h1'), findsOneWidget);
    expect(client.calls, hasLength(2));
  });

  testWidgets('an error without a message falls back to the catalog copy', (
    tester,
  ) async {
    final client = _Client()..graph = () => const RaftApiException('');
    await _pump(tester, client: client);
    expect(find.text('Failed to load member graph'), findsOneWidget);
  });

  testWidgets('a raw exception never reaches the banner', (tester) async {
    final client = _Client()
      ..graph = () => const FormatException('https://host/x?token=secret');
    await _pump(tester, client: client);
    expect(find.text('Failed to load member graph'), findsOneWidget);
    expect(find.textContaining('token'), findsNothing);
    expect(find.byType(RaftErrorBanner), findsOneWidget);
  });

  testWidgets('a guest is sent home without reading the graph', (tester) async {
    final (w, client) = await _pump(tester, role: 'guest');
    expect(client.calls, isEmpty);
    expect(w.location.route, RaftRoute.home);
    expect(find.text('Graph'), findsNothing);
  });

  testWidgets('the mobile back chevron only exists below md', (tester) async {
    var back = 0;
    await _pump(
      tester,
      size: const Size(390, 844),
      body: (w) => MemberGraphPage(controller: w, onBack: () => back++),
    );
    await tester.tap(find.byKey(const ValueKey('member-graph-mobile-back')));
    expect(back, 1);
    await _pump(
      tester,
      body: (w) => MemberGraphPage(controller: w, onBack: () {}),
    );
    expect(
      find.byKey(const ValueKey('member-graph-mobile-back')),
      findsNothing,
    );
  });

  testWidgets('the members list opens the graph from its Graph row', (
    tester,
  ) async {
    DesktopContentTarget? opened;
    await _pump(
      tester,
      size: const Size(400, 900),
      body: (w) => DesktopDirectoryView(
        controller: w,
        onSelected: (t) => opened = t,
        selected: const DesktopContentTarget(DesktopContentKind.graph, 'graph'),
      ),
    );
    final row = find.byKey(const ValueKey('desktop-directory-graph'));
    expect(row, findsOneWidget);
    expect(find.text('Graph'), findsOneWidget);
    await tester.tap(row);
    expect(opened?.kind, DesktopContentKind.graph);
  });

  test('graph target maps to /members/graph and closes back to members', () {
    final navigation = DesktopNavigationState();
    navigation.navigation.bind(
      'a/s/owner',
      RaftLocation.at(serverSlug: 'fixture', route: RaftRoute.members),
    );
    navigation.bind('a/s/owner');
    expect(navigation.masterRoute, 'members');
    navigation.selectTarget(
      const DesktopContentTarget(DesktopContentKind.graph, 'graph'),
    );
    expect(navigation.navigation.location.route, RaftRoute.memberGraph);
    expect(navigation.navigation.location.uri.path, '/s/fixture/members/graph');
    expect(navigation.target?.kind, DesktopContentKind.graph);
    expect(navigation.masterRoute, 'members');
    navigation.closeTarget();
    expect(navigation.navigation.location.route, RaftRoute.members);
    expect(navigation.target, isNull);
  });

  testWidgets('on a phone the Graph row opens the page and back returns', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _Client()..selectServer('s');
    final w = WorkspaceController(c, mobileNavigation: true)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
    w.setSection('members');
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(mode: ThemeMode.light),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desktop-directory-graph')));
    await tester.pumpAndSettle();
    expect(w.location.route, RaftRoute.memberGraph);
    expect(find.byKey(const ValueKey('member-graph-page')), findsOneWidget);
    expect(_node('human:h1'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-graph-page')), findsNothing);
    expect(
      find.byKey(const ValueKey('desktop-directory-graph')),
      findsOneWidget,
    );
  });
}
