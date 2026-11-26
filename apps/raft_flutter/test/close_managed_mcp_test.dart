import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'close_dialogs_test.dart' show anyX;
import 'managed_mcp_apps_test.dart' show appId, appView, key, mount, tap;
import 'parity/cases/screens/screen_fixture.dart';
import 'support/close_registry_managed_mcp.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

Future<SurfaceProbe> _open(WidgetTester tester, Size size, String id) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  final client = ScreenFixtureClient(
    (_, path, _) => switch (path) {
      '/mcp/apps' => {
        'apps': [
          {'id': appId, 'name': 'Team Wiki'},
        ],
      },
      '/mcp/apps/$appId' => appView(
        connections: [
          {
            'id': 'primary',
            'name': 'Team account',
            'authKind': 'headers',
            'status': 'ready',
          },
        ],
      ),
      '/mcp/agents/agent' => {
        'servers': [
          {'id': appId, 'name': 'Team Wiki', 'authMode': 'headers'},
        ],
      },
      '/mcp/servers/$appId/connection-authorization' => {
        'viewerRole': 'server_manager',
        'candidates': [],
      },
      _ => const <Object>[],
    },
    user: const {'id': 'owner'},
    server: 'server',
  );
  final agent = id == 'managed-mcp-agent-access';
  final menu = id == 'managed-mcp-connection-menu';
  await mount(
    tester,
    client,
    agentId: agent ? 'agent' : null,
    size: size,
    platform: size.width < 1000 ? TargetPlatform.android : TargetPlatform.linux,
  );
  await tap(
    tester,
    agent
        ? find.text('Change connection')
        : key('connected-app-action-mcp-$appId'),
  );
  if (menu) {
    await tap(tester, key('mcp-connection-actions-primary'));
  }
  final surface = key(
    agent
        ? 'agent-mcp-access'
        : menu
        ? 'mcp-connection-menu'
        : 'connected-app-editor',
  );
  final panel = tester.getRect(surface);
  final scrim = agent
      ? Offset(size.width / 2, panel.top / 2)
      : const Offset(6, 6);
  return SurfaceProbe(
    isOpen: () => surface.evaluate().isNotEmpty,
    x: menu ? null : anyX,
    scrim: scrim,
  );
}

void main() {
  registerCloseTests(managedMcpSurfaces, {
    for (final entry in managedMcpSurfaces)
      entry.id: (tester, size) => _open(tester, size, entry.id),
  });
}
