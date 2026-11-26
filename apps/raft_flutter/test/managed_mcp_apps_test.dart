import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_apps_view.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

const endpoint = 'https://mcp.example.invalid/mcp';
const appId = 'mcp-wiki';

Map<String, Object?> appView({
  String name = 'Team Wiki',
  int tools = 1,
  List<Map<String, Object?>> connections = const [],
}) => {
  'id': appId,
  'kind': 'mcp',
  'profile': {'name': name},
  'source': {'kind': 'url', 'maintainedByRaft': false},
  'server': {
    'endpointUrl': endpoint,
    'authKind': 'headers',
    'requiredHeaderNames': ['Authorization'],
    'health': {'status': 'reachable'},
    'toolCount': tools,
    'tools': [
      for (var index = 0; index < tools; index++) {'name': 'search$index'},
    ],
  },
  'connections': connections,
  'viewer': {'canManage': true},
};

class _RecordingClient extends ScreenFixtureClient {
  _RecordingClient(super.route)
    : super(user: const {'id': 'owner'}, server: 'server');

  final writes = <(String, String, Object?)>[];

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
  }) {
    if (method != 'GET') writes.add((method, path, data));
    return super.request(method, path, data: data, query: query);
  }
}

Future<void> mount(
  WidgetTester tester,
  ScreenFixtureClient client, {
  String? agentId,
  Size size = const Size(1280, 900),
  TargetPlatform platform = TargetPlatform.linux,
}) async {
  final workspace = WorkspaceController(client)
    ..server = RaftRecord({'id': 'server', 'name': 'Garden', 'role': 'owner'});
  addTearDown(workspace.dispose);
  addTearDown(client.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(
        body: agentId == null
            ? IntegrationsView(controller: workspace)
            : AgentAppAccessView(controller: workspace, agentId: agentId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder key(String key) => find.byKey(ValueKey(key));

Future<void> enter(WidgetTester tester, String field, String value) async {
  await tester.ensureVisible(key(field));
  await tester.enterText(key(field), value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('installed MCP apps open their editor and refresh tools', (
    tester,
  ) async {
    var refreshes = 0;
    final client = ScreenFixtureClient(
      (method, path, _) {
        switch ((method, path)) {
          case ('GET', '/mcp/apps'):
            return {
              'apps': [
                {'id': appId, 'name': 'Team Wiki'},
              ],
            };
          case ('GET', '/mcp/apps/$appId'):
            return appView();
          case ('POST', '/mcp/apps/$appId/refresh'):
            refreshes++;
            return appView(tools: 2);
          default:
            return const <Object>[];
        }
      },
      user: const {'id': 'owner'},
      server: 'server',
    );

    await mount(tester, client);
    await tap(tester, find.text('Team Wiki'));
    expect(key('connected-app-editor'), findsOneWidget);
    await tap(tester, find.text('Refresh tools'));
    expect(refreshes, 1);
    expect(find.text('search1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Add app offers custom MCP registration', (tester) async {
    final client = ScreenFixtureClient(
      (_, _, _) => const <Object>[],
      user: const {'id': 'owner'},
      server: 'server',
    );

    await mount(tester, client);
    await tap(tester, find.text('Add app').first);
    await tap(tester, find.text('Add a custom MCP app'));
    expect(find.text('New custom MCP app'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed MCP app read can be retried and reopened', (
    tester,
  ) async {
    var reads = 0;
    final client = ScreenFixtureClient(
      (_, path, _) => switch (path) {
        '/mcp/apps' => {
          'apps': [
            {'id': appId, 'name': 'Team Wiki'},
          ],
        },
        '/mcp/apps/$appId' when reads++ == 0 => throw RaftApiException(
          'Unavailable',
          status: 503,
        ),
        '/mcp/apps/$appId' => appView(),
        _ => const <Object>[],
      },
      user: const {'id': 'owner'},
      server: 'server',
    );

    await mount(tester, client);
    final edit = key('connected-app-action-mcp-$appId');
    await tap(tester, edit);
    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, edit);
    expect(find.text('Refresh tools'), findsOneWidget);
    expect(
      find.descendant(
        of: key('connected-app-editor'),
        matching: find.text('Retry'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: key('connected-app-editor'),
        matching: find.text('Something went wrong. Try again.'),
      ),
      findsNothing,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, edit);
    expect(find.text('Refresh tools'), findsOneWidget);
    expect(
      find.descendant(
        of: key('connected-app-editor'),
        matching: find.text('Retry'),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('probe, create, add a connection and edit an MCP app', (
    tester,
  ) async {
    var created = false;
    var connected = false;
    var name = 'Team Wiki';
    final client = _RecordingClient((method, path, _) {
      switch ((method, path)) {
        case ('GET', '/mcp/apps'):
          return {
            'apps': [
              if (created) {'id': appId, 'name': name},
            ],
          };
        case ('POST', '/mcp/probe'):
          return {
            'endpointUrl': endpoint,
            'outcome': 'headers',
            'suggestedHeaderNames': ['Authorization'],
          };
        case ('POST', '/mcp/apps'):
          created = true;
          return appView();
        case ('GET', '/mcp/apps/$appId'):
          return appView(
            name: name,
            connections: [
              if (connected)
                {
                  'id': 'team',
                  'name': 'Team account',
                  'authKind': 'headers',
                  'status': 'ready',
                },
            ],
          );
        case ('POST', '/mcp/apps/$appId/connections'):
          connected = true;
          return {'id': 'team'};
        case ('PATCH', '/mcp/apps/$appId'):
          name = 'Company Wiki';
          return appView(name: name);
        default:
          return const <Object>[];
      }
    });

    await mount(
      tester,
      client,
      size: const Size(856, 944),
      platform: TargetPlatform.android,
    );
    try {
      await tap(tester, find.text('Add app').first);
      await tap(tester, find.text('Add a custom MCP app'));
      await enter(tester, 'mcp-profile-name', 'Team Wiki');
      await enter(tester, 'mcp-app-endpoint', endpoint);
      await tap(tester, find.text('Validate'));
      expect(find.text('Requires an API key'), findsOneWidget);
      await tap(tester, key('connected-app-editor-submit'));
      expect(
        find.descendant(
          of: key('connected-app-editor'),
          matching: find.text('Team Wiki'),
        ),
        findsWidgets,
      );
      await tap(tester, find.text('Add connection'));
      await enter(tester, 'mcp-connection-name', 'Team account');
      await enter(
        tester,
        'mcp-connection-header-Authorization',
        'fixture-value',
      );
      await tap(tester, key('mcp-connection-submit'));
      expect(find.text('Team account'), findsOneWidget);
      await enter(tester, 'mcp-profile-name', 'Company Wiki');
      await tap(tester, key('connected-app-editor-submit'));
      expect(
        find.descendant(
          of: key('connected-app-editor'),
          matching: find.text('Company Wiki'),
        ),
        findsWidgets,
      );

      expect(
        client.writes
            .where((write) => write.$2.startsWith('/mcp/'))
            .map((write) => [write.$1, write.$2, write.$3]),
        [
          [
            'POST',
            '/mcp/probe',
            {'endpointUrl': endpoint},
          ],
          [
            'POST',
            '/mcp/apps',
            {
              'source': {'kind': 'url', 'endpointUrl': endpoint},
              'authKind': 'headers',
              'requiredHeaderNames': ['Authorization'],
              'profile': {
                'name': 'Team Wiki',
                'description': null,
                'homepageUrl': null,
                'category': null,
                'whenToUse': null,
              },
            },
          ],
          [
            'POST',
            '/mcp/apps/$appId/connections',
            {
              'name': 'Team account',
              'headers': {'Authorization': 'fixture-value'},
              'makeDefault': true,
            },
          ],
          [
            'PATCH',
            '/mcp/apps/$appId',
            {
              'profile': {
                'name': 'Company Wiki',
                'description': null,
                'homepageUrl': null,
                'category': null,
                'whenToUse': null,
              },
            },
          ],
        ],
      );
      expect(
        client.requests.where((request) => request.contains('/mcp/servers')),
        isEmpty,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('revoke removes the row and a fresh grant follows the default', (
    tester,
  ) async {
    const agent = 'agent-helper';
    const catalog = '/mcp/agents/$agent';
    const assignment = '$catalog/assignments/$appId';
    var granted = true;
    final client = _RecordingClient((method, path, _) {
      switch ((method, path)) {
        case ('GET', '/agents/$agent'):
          return {'id': agent, 'creatorType': 'user', 'creatorId': 'owner'};
        case ('GET', catalog):
          return {
            'servers': [
              {
                'id': appId,
                'name': 'Team Wiki',
                'authMode': 'headers',
                'agentConnection': {
                  'mode': granted ? 'default' : 'off',
                  'grant': granted ? 'person' : 'revoked',
                  'status': 'ready',
                  'connectionName': 'Team account',
                },
              },
            ],
          };
        case ('GET', '/mcp/servers/$appId/connection-authorization'):
          return {
            'viewerRole': 'server_manager',
            'app': {'name': 'Team Wiki', 'authKind': 'headers'},
            'candidates': [
              {
                'connectionId': 'team',
                'name': 'Team account',
                'status': 'ready',
                'isServerDefault': true,
              },
            ],
          };
        case ('PUT', assignment):
          granted = !granted;
          return {};
        default:
          return const <Object>[];
      }
    });

    await mount(tester, client, agentId: agent, size: const Size(390, 844));
    try {
      final row = key('agent-mcp-app-row-$appId');
      expect(row, findsOneWidget);
      await tap(tester, find.text('Revoke'));
      expect(row, findsNothing);
      await tap(tester, find.text('Grant access'));
      await tap(tester, find.text('Review Permissions'));
      await tap(tester, key('mcp-agent-commit'));
      expect(row, findsOneWidget);
      expect(client.writes.map((write) => [write.$1, write.$2, write.$3]), [
        [
          'PUT',
          assignment,
          {'enabled': false},
        ],
        [
          'PUT',
          assignment,
          {'enabled': true, 'connectionId': null},
        ],
      ]);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
