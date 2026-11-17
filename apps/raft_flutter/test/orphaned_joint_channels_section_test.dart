import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/orphaned_joint_channels_section.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

/// Web v1.24 OrphanedJointChannelsSection (DEC:F325): GET
/// /channels/joint-connections, Disconnect per channel nobody here is in.
Map<String, dynamic> _conn(
  String id,
  String name, {
  int members = 0,
  String role = 'participant',
  List<Map<String, dynamic>>? servers,
}) => {
  'channelId': id,
  'name': name,
  'role': role,
  'memberCount': members,
  'isMember': members > 0,
  'archived': false,
  'servers':
      servers ??
      [
        {'serverId': 's', 'name': 'Moon', 'role': role},
        {'serverId': 'o1', 'name': 'Mars', 'role': 'host'},
        {'serverId': 'o2', 'name': 'Venus', 'role': 'participant'},
      ],
};

class _Fixture {
  _Fixture({
    String role = 'owner',
    this.externalChannels = false,
    this.failRead = false,
    this.failDisconnectWith,
  }) {
    client = ScreenFixtureClient(
      (method, path, query) {
        requests.add('$method $path');
        if (path == '/channels/joint-connections') {
          if (failRead) throw const RaftApiException('nope');
          return {'connections': connections};
        }
        if (path == '/feature-flags/evaluate') {
          return {
            'evaluations': [
              {'key': 'external_channels_v1', 'enabled': externalChannels},
            ],
          };
        }
        if (path.endsWith('/disconnect') && failDisconnectWith != null) {
          throw failDisconnectWith!;
        }
        if (method == 'GET' && path.startsWith('/channels')) return <dynamic>[];
        return <String, dynamic>{};
      },
      user: {'id': 'alice'},
      server: 's',
    );
    w = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 's',
        'name': 'Moon',
        'slug': 'moon',
        'role': role,
      });
    w.servers = [w.server!];
    addTearDown(w.dispose);
  }
  final bool externalChannels, failRead;
  final Object? failDisconnectWith;
  late final ScreenFixtureClient client;
  late final WorkspaceController w;
  final requests = <String>[];
  List<Map<String, dynamic>> connections = [
    _conn('b', 'beta-sync'),
    _conn('a', 'alpha-sync', role: 'host'),
    _conn('m', 'busy', members: 2),
  ];

  Future<void> mount(WidgetTester t, {double width = 1000}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 1400);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrphanedJointChannelsSection(controller: w),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }
}

final _section = find.byKey(const ValueKey('orphaned-joint-channels-section'));

void main() {
  testWidgets('lists the orphaned copies by name, without ones with members', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(t);
    expect(_section, findsOneWidget);
    final header = t.widget<RaftSettingsSectionHeader>(
      find.byType(RaftSettingsSectionHeader),
    );
    expect(header.label, 'External channels nobody here is in');
    expect(header.count, 2);
    expect(find.text('#busy'), findsNothing);
    expect(
      t.getTopLeft(find.text('#alpha-sync')).dy,
      lessThan(t.getTopLeft(find.text('#beta-sync')).dy),
    );
    expect(
      find.text(
        'Connected with Mars and Venus · nobody from this server is in it',
      ),
      findsNWidgets(2),
    );
    expect(
      find.text(
        'Everyone from Moon has left these channels. Disconnect them to free their slots. The other servers keep the conversation.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a server of its own alone reads "nobody from this server"', (
    t,
  ) async {
    final f = _Fixture()
      ..connections = [
        _conn(
          'a',
          'solo',
          servers: [
            {'serverId': 's', 'name': 'Moon', 'role': 'participant'},
          ],
        ),
      ];
    await f.mount(t);
    expect(find.text('Nobody from this server is in it'), findsOneWidget);
  });

  testWidgets('with external channels on the host copy is not offered', (
    t,
  ) async {
    final f = _Fixture(externalChannels: true);
    await f.mount(t);
    expect(find.text('#alpha-sync'), findsNothing);
    expect(find.text('#beta-sync'), findsOneWidget);
  });

  testWidgets('members who cannot federate channels read nothing', (t) async {
    final f = _Fixture(role: 'member');
    await f.mount(t);
    expect(_section, findsNothing);
    expect(f.requests, isNot(contains('GET /channels/joint-connections')));
  });

  testWidgets('a failed read lists nothing and shows nothing', (t) async {
    final f = _Fixture(failRead: true);
    await f.mount(t);
    expect(_section, findsNothing);
  });

  testWidgets('no orphaned copy, no section', (t) async {
    final f = _Fixture()..connections = [_conn('m', 'busy', members: 1)];
    await f.mount(t);
    expect(_section, findsNothing);
  });

  testWidgets('Disconnect confirms, posts, drops the row and says so', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(t);
    await t.tap(
      find.byKey(const ValueKey('orphaned-joint-channel-disconnect-b')),
    );
    await t.pumpAndSettle();
    expect(find.text('Disconnect joint channel'), findsOneWidget);
    expect(f.requests, isNot(contains('POST /channels/b/disconnect')));
    await t.tap(find.byKey(const Key('orphaned-joint-channel-confirm-button')));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(f.requests, contains('POST /channels/b/disconnect'));
    expect(find.text('#beta-sync'), findsNothing);
    expect(find.text('#alpha-sync'), findsOneWidget);
    expect(find.text('Moon disconnected from #beta-sync'), findsOneWidget);
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('guests_present names the channel and keeps the row', (t) async {
    final f = _Fixture(
      failDisconnectWith: RaftApiException.response(
        'Guests present',
        status: 409,
        body: {'error': 'Guests present', 'code': 'guests_present'},
      ),
    );
    await f.mount(t);
    await t.tap(
      find.byKey(const ValueKey('orphaned-joint-channel-disconnect-b')),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('orphaned-joint-channel-confirm-button')));
    await t.pumpAndSettle();
    expect(
      find.text(
        "#beta-sync has guests, so this server can't disconnect from it. Remove the guests first, or archive the channel.",
      ),
      findsOneWidget,
    );
    expect(find.text('#beta-sync'), findsOneWidget);
  });

  testWidgets('a plain failure shows the server text', (t) async {
    final f = _Fixture(
      failDisconnectWith: RaftApiException.response(
        'Only joint channels can be disconnected',
        status: 400,
        body: {'error': 'Only joint channels can be disconnected'},
      ),
    );
    await f.mount(t);
    await t.tap(
      find.byKey(const ValueKey('orphaned-joint-channel-disconnect-b')),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('orphaned-joint-channel-confirm-button')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('orphaned-joint-channels-error')),
      findsOneWidget,
    );
  });

  // ServerTabContent.tsx order: Profile, Public visibility, Archived channels,
  // Orphaned joint channels, Archived agents, Danger zone.
  testWidgets('the Server tab mounts it before the danger zone', (t) async {
    final f = _Fixture();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1000, 2000);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: ServerSettingsView(controller: f.w)),
      ),
    );
    await t.pumpAndSettle();
    expect(_section, findsOneWidget);
    expect(
      t.getTopLeft(_section).dy,
      lessThan(
        t.getTopLeft(find.byKey(const Key('server-danger-delete-card'))).dy,
      ),
    );
  });
}
