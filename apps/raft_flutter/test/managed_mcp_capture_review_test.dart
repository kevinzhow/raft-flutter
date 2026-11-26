import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/mcp_app_editor.dart';
import 'package:raft_ui/raft_ui.dart';

import 'managed_mcp_apps_test.dart' as support;
import 'parity/cases/screens/screen_fixture.dart';

void main() {
  testWidgets('phone loading keeps the full editor and disabled Add app', (
    tester,
  ) async {
    final client = ScreenFixtureClient(
      (method, path, _) => path == '/mcp/apps'
          ? {
              'apps': [
                {'id': support.appId, 'name': 'Team Wiki'},
              ],
            }
          : path == '/mcp/apps/${support.appId}'
          ? ScreenFixtureClient.pending
          : const [],
      user: const {'id': 'owner'},
      server: 'server',
    );
    await support.mount(
      tester,
      client,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    await support.tap(tester, find.text('Team Wiki'));
    expect(tester.getSize(support.key('connected-app-editor')).width, 390);
    expect(find.text('Loading'), findsOneWidget);
    expect(
      tester
          .widget<RaftButton>(support.key('connected-app-editor-submit'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('profile follows the Web grid and optional field copy', (
    tester,
  ) async {
    final client = ScreenFixtureClient(
      (_, _, _) => const [],
      user: const {'id': 'owner'},
      server: 'server',
    );
    await support.mount(tester, client);
    await support.tap(tester, find.text('Add app'));
    await support.tap(tester, find.text('Add a custom MCP app'));
    final logo = find.text(
      'Create the app first, then upload a logo from Edit.',
    );
    final name = support.key('mcp-profile-name');
    final homepage = support.key('mcp-profile-homepage');
    expect(tester.getTopLeft(name).dx, greaterThan(tester.getTopLeft(logo).dx));
    expect(tester.getTopLeft(homepage).dx, tester.getTopLeft(name).dx);
    expect(find.text('0 / 160 characters'), findsOneWidget);
    expect(
      find.text(
        'Shown to agents in their system prompt; leave empty to hide it.',
      ),
      findsOneWidget,
    );
    final description = tester.widget<TextField>(
      support.key('mcp-profile-description'),
    );
    expect(description.maxLines, isNot(1));
  });

  testWidgets('OAuth add and reconnect open Web without starting an attempt', (
    tester,
  ) async {
    final opened = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      opened.add((call.arguments as Map)['url'] as String);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final oauth = support.appView(
      connections: [
        {'id': 'conn', 'name': 'Team', 'authKind': 'oauth', 'status': 'ready'},
      ],
    );
    (oauth['server'] as Map)['authKind'] = 'oauth';
    final client = ScreenFixtureClient(
      (_, path, _) => path == '/mcp/apps'
          ? {
              'apps': [
                {'id': support.appId, 'name': 'Team Wiki'},
              ],
            }
          : path == '/mcp/apps/${support.appId}'
          ? oauth
          : const [],
      user: const {'id': 'owner'},
      server: 'server',
    );
    await support.mount(tester, client);
    await support.tap(tester, find.text('Team Wiki'));
    await support.tap(tester, find.text('Add connection'));
    expect(opened, hasLength(1));
    expect(Uri.parse(opened.single).path, '/s/server/apps');
    await support.tap(tester, support.key('mcp-connection-actions-conn'));
    await support.tap(tester, find.text('Reauthorize'));
    expect(opened, hasLength(2));
    await tester.pump(const Duration(seconds: 10));
    expect(
      client.requests.where(
        (request) =>
            request.contains('/oauth/start') ||
            request.contains('/oauth/attempts'),
      ),
      isEmpty,
    );
    expect(find.byType(McpAppEditor), findsOneWidget);
  });

  /// Martin's review B4, McpAgentConnectionDrawer.tsx:88-95, 243: with no
  /// server default there is nothing for "use the default" to follow, so the
  /// option is disabled, nothing is preselected and Save stays off.
  testWidgets('no server default leaves the default option off and Save off', (
    tester,
  ) async {
    final client = ScreenFixtureClient(
      (_, path, _) => switch (path) {
        '/mcp/agents/agent' => {
          'servers': [
            {'id': support.appId, 'name': 'Team Wiki', 'authMode': 'headers'},
          ],
        },
        '/mcp/servers/${support.appId}/connection-authorization' => {
          'viewerRole': 'server_manager',
          'candidates': <Object>[],
        },
        _ => const <Object>[],
      },
      user: const {'id': 'owner'},
      server: 'server',
    );
    await support.mount(tester, client, agentId: 'agent');
    await support.tap(tester, find.text('Change connection'));
    final option = tester.widget<RaftRadioGroupItem<String>>(
      find
          .ancestor(
            of: find.text('Use the server default'),
            matching: find.byType(RaftRadioGroupItem<String>),
          )
          .first,
    );
    expect(option.enabled, isFalse);
    expect(
      find.text(
        'No server default yet. Set one or choose a specific connection below.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<RaftButton>(support.key('mcp-agent-commit')).onPressed,
      isNull,
    );
  });

  /// B4 again: every candidate is pinnable, the current server default marked
  /// with its badge (McpAgentConnectionDrawer.tsx:259-271).
  testWidgets('the server default connection can still be pinned', (
    tester,
  ) async {
    final client = ScreenFixtureClient(
      (_, path, _) => switch (path) {
        '/mcp/agents/agent' => {
          'servers': [
            {'id': support.appId, 'name': 'Team Wiki', 'authMode': 'headers'},
          ],
        },
        '/mcp/servers/${support.appId}/connection-authorization' => {
          'viewerRole': 'server_manager',
          'candidates': [
            {
              'connectionId': 'primary',
              'name': 'Team account',
              'status': 'ready',
              'isServerDefault': true,
            },
          ],
        },
        _ => const <Object>[],
      },
      user: const {'id': 'owner'},
      server: 'server',
    );
    await support.mount(tester, client, agentId: 'agent');
    await support.tap(tester, find.text('Change connection'));
    expect(find.text('Team account'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    final option = tester.widget<RaftRadioGroupItem<String>>(
      find
          .ancestor(
            of: find.text('Team account'),
            matching: find.byType(RaftRadioGroupItem<String>),
          )
          .first,
    );
    expect(option.value, 'primary');
    expect(option.enabled, isTrue);
  });
}
