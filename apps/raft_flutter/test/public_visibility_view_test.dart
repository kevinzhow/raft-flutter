import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/public_visibility_view.dart';
import 'package:raft_ui/raft_ui.dart';

typedef _Route = Object? Function(dynamic data);

class _Client extends RaftClient {
  _Client(this.routes)
    : super(
        origin: 'https://raft.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'u-owner', 'name': 'owner'});
    selectServer('s1');
  }
  final Map<String, _Route> routes;
  final calls = <(String, dynamic)>[];

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
    final key = '$method $path';
    calls.add((key, data));
    final route = routes[key];
    if (route == null) throw RaftApiException('Not found: $key', status: 404);
    return route(data);
  }

  List<dynamic> sent(String key) => [
    for (final (k, data) in calls)
      if (k == key) data,
  ];
}

(WorkspaceController, _Client) _workspace({
  String role = 'owner',
  bool publicFlag = true,
  bool guestFlag = true,
  bool visible = false,
}) {
  var current = {
    'publiclyVisible': visible,
    'publicGuestJoinEnabled': false,
    'slug': 'fixture',
    'exposedChannels': [
      {'name': 'general', 'description': 'Everything'},
    ],
  };
  final client = _Client({
    'POST /feature-flags/evaluate': (_) => {
      'evaluations': [
        {'key': 'public_server_v0', 'enabled': publicFlag},
        {'key': 'server_guest_v0', 'enabled': guestFlag},
      ],
    },
    'GET /servers/s1/public-visibility': (_) => current,
    'PATCH /servers/s1/public-visibility': (data) => current = {
      ...current,
      'publiclyVisible': (data as Map)['publiclyVisible'],
    },
    'PATCH /servers/s1/public-guest-join': (data) => current = {
      ...current,
      'publicGuestJoinEnabled': (data as Map)['publicGuestJoinEnabled'],
    },
  });
  final w = WorkspaceController(client);
  addTearDown(w.dispose);
  final server = RaftRecord({
    'id': 's1',
    'name': 'Fixture',
    'slug': 'fixture',
    'role': role,
  });
  w
    ..server = server
    ..servers = [server];
  return (w, client);
}

Future<void> _pump(WidgetTester t, WorkspaceController w) async {
  t.view.physicalSize = const Size(1000, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PublicVisibilitySection(
            controller: w,
            webOrigin: 'https://app.raft.test',
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  const section = ValueKey('public-visibility-section');

  testWidgets('only the owner behind public_server_v0 sees the section', (
    t,
  ) async {
    var (w, client) = _workspace(role: 'admin');
    await _pump(t, w);
    expect(find.byKey(section), findsNothing);
    expect(client.sent('GET /servers/s1/public-visibility'), isEmpty);

    (w, client) = _workspace(publicFlag: false);
    await _pump(t, w);
    expect(find.byKey(section), findsNothing);
    expect(client.sent('GET /servers/s1/public-visibility'), isEmpty);
  });

  testWidgets('turning public on asks first, then PATCHes', (t) async {
    final (w, client) = _workspace();
    await _pump(t, w);
    expect(find.byKey(section), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('public-visibility-switch')));
    await t.pumpAndSettle();
    expect(find.text('Make this server public?'), findsOneWidget);
    expect(find.text('Make public'), findsWidgets);
    expect(find.text('general'), findsWidgets);
    expect(client.sent('PATCH /servers/s1/public-visibility'), isEmpty);

    await t.tap(find.byKey(const ValueKey('public-visibility-confirm-button')));
    await t.pumpAndSettle();
    expect(client.sent('PATCH /servers/s1/public-visibility'), [
      {'publiclyVisible': true},
    ]);
    expect(
      find.textContaining('https://app.raft.test/s/fixture'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('public-guest-join-switch')),
      findsOneWidget,
    );
  });

  testWidgets('guest joining and turning public off', (t) async {
    final (w, client) = _workspace(visible: true);
    await _pump(t, w);
    await t.tap(find.byKey(const ValueKey('public-guest-join-switch')));
    await t.pumpAndSettle();
    expect(client.sent('PATCH /servers/s1/public-guest-join'), [
      {'publicGuestJoinEnabled': true},
    ]);

    await t.tap(find.byKey(const ValueKey('public-visibility-switch')));
    await t.pumpAndSettle();
    expect(client.sent('PATCH /servers/s1/public-visibility'), [
      {'publiclyVisible': false},
    ]);
    expect(find.textContaining('/s/fixture'), findsNothing);
  });

  testWidgets('the guest switch needs server_guest_v0', (t) async {
    final (w, _) = _workspace(visible: true, guestFlag: false);
    await _pump(t, w);
    expect(find.byKey(section), findsOneWidget);
    expect(
      find.byKey(const ValueKey('public-guest-join-switch')),
      findsNothing,
    );
  });
}
