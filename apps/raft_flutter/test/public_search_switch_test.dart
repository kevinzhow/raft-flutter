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

class _Fixture {
  _Fixture({bool visible = false, bool searchEnabled = false})
    : current = {
        'publiclyVisible': visible,
        'publicGuestJoinEnabled': false,
        'publicSearchEnabled': searchEnabled,
        'slug': 'fixture',
        'exposedChannels': [
          {'name': 'general', 'description': 'Everything'},
        ],
      } {
    client = _Client({
      'POST /feature-flags/evaluate': (_) => {
        'evaluations': [
          {'key': 'public_server_v0', 'enabled': true},
          {'key': 'server_guest_v0', 'enabled': true},
        ],
      },
      'GET /servers/s1/public-visibility': (_) => current,
      'PATCH /servers/s1/public-visibility': (data) => current = {
        ...current,
        'publiclyVisible': (data as Map)['publiclyVisible'],
      },
      'PATCH /servers/s1/public-search': (data) {
        if (failSearch) throw RaftApiException('Boom', status: 500);
        return {'publicSearchEnabled': (data as Map)['publicSearchEnabled']};
      },
      'GET /servers': (_) => [
        {
          'id': 's1',
          'name': 'Fixture',
          'slug': 'fixture',
          'role': 'owner',
          'publicPageLive': current['publiclyVisible'],
        },
      ],
    });
    w = WorkspaceController(client);
    addTearDown(w.dispose);
    final server = RaftRecord({
      'id': 's1',
      'name': 'Fixture',
      'slug': 'fixture',
      'role': 'owner',
    });
    w
      ..server = server
      ..servers = [server];
  }
  Map<String, dynamic> current;
  bool failSearch = false;
  late final _Client client;
  late final WorkspaceController w;
}

Future<void> _pump(WidgetTester t, WorkspaceController w) async {
  t.view.physicalSize = const Size(1000, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
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

bool _on(WidgetTester t, String key) =>
    t.widget<RaftSwitch>(find.byKey(ValueKey(key))).value;

bool _enabled(WidgetTester t, String key) =>
    t.widget<RaftSwitch>(find.byKey(ValueKey(key))).enabled;

void main() {
  testWidgets(
    'Allow search engines sits under the public switch and needs a public server',
    (t) async {
      final f = _Fixture(searchEnabled: true);
      await _pump(t, f.w);
      expect(
        find.byKey(const ValueKey('public-search-setting')),
        findsOneWidget,
      );
      expect(find.text('Allow search engines'), findsOneWidget);
      // The stored choice never reads as on, or editable, while private.
      expect(_on(t, 'public-search-switch'), isFalse);
      expect(_enabled(t, 'public-search-switch'), isFalse);
    },
  );

  testWidgets('the switch PATCHes public-search and shows the answer', (
    t,
  ) async {
    final f = _Fixture(visible: true);
    await _pump(t, f.w);
    expect(_on(t, 'public-search-switch'), isFalse);
    expect(_enabled(t, 'public-search-switch'), isTrue);
    await t.tap(find.byKey(const ValueKey('public-search-switch')));
    await t.pumpAndSettle();
    expect(f.client.sent('PATCH /servers/s1/public-search'), [
      {'publicSearchEnabled': true},
    ]);
    expect(_on(t, 'public-search-switch'), isTrue);
    // The other settings are untouched by it.
    expect(f.client.sent('PATCH /servers/s1/public-visibility'), isEmpty);
    expect(f.client.sent('PATCH /servers/s1/public-guest-join'), isEmpty);
  });

  testWidgets('a failed update keeps the old value and says why', (t) async {
    final f = _Fixture(visible: true, searchEnabled: true)..failSearch = true;
    await _pump(t, f.w);
    await t.tap(find.byKey(const ValueKey('public-search-switch')));
    await t.pumpAndSettle();
    expect(_on(t, 'public-search-switch'), isTrue);
    expect(find.text('Failed to update search engine access'), findsOneWidget);
  });

  testWidgets(
    'turning public off or on reloads the server list for the globe',
    (t) async {
      final f = _Fixture(visible: true);
      await _pump(t, f.w);
      expect(f.client.sent('GET /servers'), isEmpty);
      await t.tap(find.byKey(const ValueKey('public-visibility-switch')));
      await t.pumpAndSettle();
      expect(f.client.sent('PATCH /servers/s1/public-visibility'), [
        {'publiclyVisible': false},
      ]);
      expect(f.client.sent('GET /servers'), hasLength(1));
      expect(f.w.servers.single.json['publicPageLive'], isFalse);
    },
  );
}
