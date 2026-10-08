import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/mcp_views.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_flutter/features/admin_views.dart';
import 'package:raft_flutter/features/provider_views.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for native management UI.');
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  final lists = find.byType(ListView);
  if (lists.evaluate().isEmpty) {
    throw TestFailure('Management control is missing.');
  }
  final scroll = find.descendant(
    of: lists.last,
    matching: find.byType(Scrollable),
  );
  final state = tester.state<ScrollableState>(scroll.first);
  state.position.jumpTo(0);
  await tester.pumpAndSettle();
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    final next = (state.position.pixels + 300).clamp(
      0.0,
      state.position.maxScrollExtent,
    );
    if (next == state.position.pixels) break;
    state.position.jumpTo(next);
    await tester.pumpAndSettle();
  }
  if (finder.evaluate().isEmpty) {
    throw TestFailure('Management control did not appear while scrolling.');
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _formText(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey('field-$key'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(field, value);
}

/// Creates a dedicated workspace and deletes only exact resource ids from it.
/// Credential reveal/copy and chargeable/external provider operations are excluded.
Future<void> verifyManagementFlow(
  WidgetTester tester,
  WorkspaceController w, {
  required Future<void> Function(String) section,
  required Future<void> Function(String) capture,
}) async {
  final original = w.server!;
  final marker = DateTime.now().microsecondsSinceEpoch;
  String? serverId, appId, mcpId;
  try {
    final created = await w.client.post(
      '/servers',
      data: {
        'name': 'Native management $marker',
        'slug': 'native-management-$marker',
      },
    );
    serverId = created['id'];
    await w.recoverMembership();
    await w.selectServer(w.servers.singleWhere((s) => s.id == serverId));
    await tester.pumpAndSettle();
    await section('integrations');
    await _until(
      tester,
      () =>
          find.byType(IntegrationsView).evaluate().isNotEmpty &&
          find.text('Register app').evaluate().isNotEmpty,
    );
    await _tap(tester, find.text('Register app'));
    await _formText(tester, 'name', 'Native app $marker');
    await _formText(tester, 'description', '中文 日本語 native app');
    await _tap(tester, find.text('Register'));
    await _until(
      tester,
      () => find.byType(RaftSecretView).evaluate().isNotEmpty,
    );
    expect(find.byKey(const Key('credential-hidden')), findsOneWidget);
    expect(find.text('Reveal credential'), findsOneWidget);
    await _tap(tester, find.text('Close'));
    final ownApps = await w.client.get('/integrations/clients') as List;
    appId = ownApps.cast<Map>().singleWhere(
      (a) => a['name'] == 'Native app $marker',
    )['id'];
    await _tap(tester, find.text('Native app $marker'));
    await _until(
      tester,
      () => find.byType(AppManagementView).evaluate().isNotEmpty,
    );
    await _tap(tester, find.text('Edit app'));
    await _formText(tester, 'description', 'Native app metadata updated');
    await _tap(tester, find.text('Save'));
    await _until(
      tester,
      () => find.text('Native app metadata updated').evaluate().isNotEmpty,
    );
    await _tap(tester, find.text('Edit notification permissions'));
    await _formText(tester, 'groups', 'agent');
    await _formText(tester, 'events', 'agent.status_changed');
    await _tap(tester, find.text('Save'));
    await _until(
      tester,
      () => find.text('Permission groups: agent').evaluate().isNotEmpty,
    );
    final permissions = await w.client.get(
      '/integrations/clients/$appId/app-notifications',
    );
    expect(permissions['current_groups'], contains('agent'));
    expect(permissions['current_events'], contains('agent.status_changed'));
    await _tap(tester, find.text('Create sharing link'));
    await _until(
      tester,
      () => find.byType(RaftSecretView).evaluate().isNotEmpty,
    );
    expect(find.byKey(const Key('credential-hidden')), findsOneWidget);
    await _tap(tester, find.text('Close'));
    await _tap(tester, find.text('Revoke sharing link'));
    await _tap(tester, find.text('Revoke'));
    await _until(
      tester,
      () => find.text('No active sharing link.').evaluate().isNotEmpty,
    );
    await capture('linux-app-management');
    await _tap(tester, find.text('Delete app').last);
    await _tap(tester, find.text('Delete'));
    await _until(
      tester,
      () => find.byType(AppManagementView).evaluate().isEmpty,
    );
    appId = null;
    await _tap(tester, find.text('MCP'));
    await _until(tester, () => find.byType(AgentMcpView).evaluate().isNotEmpty);
    await _tap(tester, find.text('Add connection'));
    await _formText(tester, 'name', 'Native MCP $marker');
    await _formText(tester, 'endpointUrl', 'https://example.com/mcp');
    await _tap(tester, find.text('Add'));
    await _until(
      tester,
      () => find.text('Native MCP $marker').evaluate().isNotEmpty,
    );
    final catalog = await w.client.get('/mcp/servers');
    mcpId = (catalog['servers'] as List).cast<Map>().singleWhere(
      (s) => s['name'] == 'Native MCP $marker',
    )['id'];
    await _tap(tester, find.text('Edit connection'));
    await _formText(tester, 'description', 'Native MCP metadata updated');
    await _tap(tester, find.text('Save'));
    await _until(
      tester,
      () => find.text('Native MCP metadata updated').evaluate().isNotEmpty,
    );
    await _tap(tester, find.text('Disable'));
    await _until(
      tester,
      () => find.textContaining('Disabled · none').evaluate().isNotEmpty,
    );
    final disabled = await w.client.get('/mcp/servers');
    expect(
      (disabled['servers'] as List).cast<Map>().singleWhere(
        (s) => s['id'] == mcpId,
      )['enabled'],
      false,
    );
    await capture('linux-mcp-management');
    await _tap(tester, find.text('Delete connection'));
    await _tap(tester, find.text('Delete'));
    await _until(
      tester,
      () => find.text('Native MCP $marker').evaluate().isEmpty,
    );
    mcpId = null;
    final mcpContext = tester.element(find.byType(AgentMcpView));
    Navigator.pop(mcpContext);
    await tester.pumpAndSettle();
    await section('administration');
    await _until(
      tester,
      () => find.byType(AdministrationView).evaluate().isNotEmpty,
    );
    final originalAnalytics = await w.client.get(
      '/servers/$serverId/product-analytics-settings',
    );
    final target = originalAnalytics['productAnalyticsEnabled'] != true;
    await _tap(
      tester,
      find.widgetWithText(SwitchListTile, 'Share product usage data'),
    );
    await _until(
      tester,
      () =>
          tester
              .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Share product usage data'),
              )
              .value ==
          target,
    );
    expect(
      (await w.client.get(
        '/servers/$serverId/product-analytics-settings',
      ))['productAnalyticsEnabled'],
      target,
    );
    await _tap(tester, find.text('Edit agreement'));
    await _formText(tester, 'title', 'Native join agreement');
    await _formText(
      tester,
      'bodyMarkdown',
      'Accept this native test agreement to join.',
    );
    await tester.tap(find.byKey(const ValueKey('field-enabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Required').last);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save'));
    await _until(
      tester,
      () => find.text('Native join agreement').evaluate().isNotEmpty,
    );
    expect(
      (await w.client.get('/servers/$serverId/agreement'))['enabled'],
      true,
    );
    await capture('linux-workspace-administration');
    await section('billing');
    await _until(tester, () => find.byType(BillingView).evaluate().isNotEmpty);
    final billing = await w.client.get('/billing/subscription');
    expect(find.text('${billing['displayName']}'), findsOneWidget);
    if (billing['stripeConfigured'] != true) {
      expect(
        find.text('Online billing is not configured for this server.'),
        findsOneWidget,
      );
    }
    await capture('linux-billing');
    // Match the same current server/platform gate that controls the sidebar.
    // Unknown evaluations are failures rather than evidence of an OFF gate.
    final gateResult = await w.client.post(
      '/feature-flags/evaluate',
      data: {
        'keys': ['provider_connections_v0'],
        'serverId': w.server!.id,
        'platform':
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)
            ? 'mobile'
            : 'web',
      },
    );
    expect(gateResult, isA<Map>());
    final evaluations = (gateResult as Map)['evaluations'];
    expect(evaluations, isA<List>());
    final providerGate = (evaluations as List).whereType<Map>().where(
      (row) => row['key'] == 'provider_connections_v0',
    );
    expect(providerGate, hasLength(1));
    expect(providerGate.single['enabled'], isA<bool>());
    expect(w.can('manageExternalAuth'), isTrue);
    if (providerGate.single['enabled'] == true) {
      await _until(
        tester,
        () => find.byKey(const Key('nav-providers')).evaluate().isNotEmpty,
      );
      await section('providers');
      await _until(
        tester,
        () => find.byType(ProviderConnectionsView).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      await capture('linux-provider-connections');
    } else {
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nav-providers')), findsNothing);
      expect(find.byType(ProviderConnectionsView), findsNothing);
      await capture('linux-provider-connections-gate-disabled');
    }
  } finally {
    if (w.client.serverId != serverId && serverId != null) {
      w.client.selectServer(serverId);
    }
    Future<void> remove(String path) async {
      try {
        await w.client.delete(path);
      } on RaftApiException catch (e) {
        if (e.status != 404) rethrow;
      }
    }

    if (appId != null) await remove('/integrations/clients/$appId');
    if (mcpId != null) await remove('/mcp/servers/$mcpId');
    if (serverId != null) {
      await w.client.exitServer(serverId, delete: true);
      w.revokeServer(serverId);
    }
    await w.recoverMembership();
    await w.selectServer(w.servers.singleWhere((s) => s.id == original.id));
    await tester.pumpAndSettle();
  }
}
