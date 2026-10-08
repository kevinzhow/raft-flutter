import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_flutter/features/provider_views.dart';
import 'package:raft_flutter/features/admin_views.dart';
import 'package:raft_flutter/features/server_setup_gate.dart';
import 'package:raft_flutter/features/account_connections_view.dart';
import 'package:raft_flutter/features/agent_apps_view.dart';
import 'package:raft_flutter/features/im_bridges_view.dart';
import 'package:raft_flutter/features/account_settings.dart';

import 'slack_bridge_contract_test.dart' show bridgeFixture;

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final statuses = <String, int>{};
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final data = route == null
        ? {'error': 'Unexpected endpoint'}
        : await route(o);
    return ResponseBody.fromString(
      jsonEncode(data),
      statuses['${o.method} ${o.path}'] ?? (route == null ? 404 : 200),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(WorkspaceController, _Adapter)> _fixture(String role) async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'name': 'Test workspace', 'role': role});
  w.servers = [w.server!];
  return (w, a);
}

Widget host(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: child),
);
void _appRoutes(
  _Adapter a,
  FutureOr<dynamic> Function(RequestOptions) clients,
) {
  a.routes['GET /integrations/clients'] = clients;
  a.routes['GET /integrations/marketplace'] = (_) => <dynamic>[];
  a.routes['GET /integrations/overview'] = (_) => <dynamic>[];
}

Future<void> register(WidgetTester tester) async {
  await tester.tap(find.text('Register app'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('field-name')),
    'Native fixture app',
  );
  await tester.tap(find.text('Register'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'backend permission rejection during mutation clears an accepted private bridge projection',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'slack_bridge_v0', 'enabled': true},
        ],
      };
      a.routes['GET /slack-bridge/provisioning'] = (_) => bridgeFixture();
      a.routes['POST /slack-bridge/provisioning/preflight'] = (_) => {
        'error': 'Permission changed',
      };
      a.statuses['POST /slack-bridge/provisioning/preflight'] = 403;
      await tester.pumpWidget(host(IMBridgesView(controller: w)));
      await tester.pumpAndSettle();
      expect(find.text('Fixture Slack'), findsOneWidget);
      await tester.tap(find.text('Verify and enable'));
      await tester.pumpAndSettle();
      expect(find.text('Fixture Slack'), findsNothing);
      expect(find.text('Disconnect Slack'), findsNothing);
      expect(find.textContaining('Permission changed'), findsOneWidget);
    },
  );
  testWidgets(
    'backend permission rejection in a management form closes it and clears prior private rows',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      _appRoutes(
        a,
        (_) => [
          {
            'id': 'a1',
            'name': 'Private owned app',
            'allowedScopes': ['openid'],
          },
        ],
      );
      a.routes['POST /integrations/clients'] = (_) => {
        'error': 'Permission changed',
      };
      a.statuses['POST /integrations/clients'] = 403;
      await tester.pumpWidget(host(IntegrationsView(controller: w)));
      await tester.pumpAndSettle();
      expect(find.text('Private owned app'), findsOneWidget);
      await register(tester);
      expect(find.byType(RaftFormDialog), findsNothing);
      expect(find.text('Private owned app'), findsNothing);
      expect(find.textContaining('Permission changed'), findsOneWidget);
    },
  );

  testWidgets(
    'Slack pair save preserves concurrent mappings and enables only after closed preflight',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      final value = bridgeFixture();
      value['snapshot']['slackChannels'][1]['isMember'] = true;
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'slack_bridge_v0', 'enabled': true},
        ],
      };
      a.routes['GET /slack-bridge/provisioning'] = (_) => value;
      a.routes['PUT /slack-bridge/provisioning/channel-pairs'] = (o) {
        expect(o.data, {
          'pairs': [
            {'raftChannelId': 'r1', 'slackChannelId': 's1'},
            {'raftChannelId': 'r3', 'slackChannelId': 's3'},
            {'raftChannelId': 'r2', 'slackChannelId': 's2'},
          ],
        });
        value['snapshot']['channelPairs'] = (o.data['pairs'] as List)
            .map((p) => {...p, 'bindingEpoch': 8})
            .toList();
        return value;
      };
      a.routes['POST /slack-bridge/provisioning/preflight'] = (_) {
        expect(a.calls.where((c) => c.method == 'PUT'), hasLength(1));
        value['snapshot']['preflight'] = {
          'state': 'passed',
          'checks': [
            for (final id in ['oauth', 'endpoint', 'scope', 'audience'])
              {'id': id, 'state': 'passed'},
          ],
        };
        return value;
      };
      a.routes['POST /slack-bridge/provisioning/enable'] = (_) {
        expect(
          a.calls.where((c) => c.path.endsWith('/preflight')),
          hasLength(1),
        );
        value['snapshot']['stage'] = 'health';
        return value;
      };
      await tester.pumpWidget(host(IMBridgesView(controller: w)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add channel pair'));
      await tester.pumpAndSettle();
      value['snapshot']['raftChannels'].add({'id': 'r3', 'name': 'concurrent'});
      value['snapshot']['slackChannels'].add({
        'id': 's3',
        'name': 'concurrent',
        'isMember': true,
      });
      value['snapshot']['channelPairs'].add({
        'raftChannelId': 'r3',
        'slackChannelId': 's3',
        'bindingEpoch': 9,
      });
      await tester.tap(find.widgetWithText(RaftButton, 'Save'));
      await tester.pumpAndSettle();
      expect(a.calls.where((c) => c.path.endsWith('/enable')), hasLength(1));
    },
  );

  testWidgets(
    'account switch closes profile form and cannot edit the next account',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      await tester.pumpWidget(host(AccountSettings(controller: w)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(RaftFormDialog), findsOneWidget);
      w.client.user = RaftRecord({'id': 'bob', 'name': 'newaccount'});
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(RaftFormDialog), findsNothing);
      expect(
        a.calls.where((c) => c.method == 'PATCH' && c.path == '/auth/me'),
        isEmpty,
      );
    },
  );

  testWidgets(
    'password setup email uses current account and a private confirmation',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      w.client.user = RaftRecord({
        'id': 'alice',
        'email': 'fixture@example.invalid',
      });
      a.routes['GET /auth/identities'] = (_) => {
        'identities': [
          {'provider': 'google', 'providerEmail': 'fixture@example.invalid'},
        ],
        'passwordConfigured': false,
      };
      a.routes['GET /auth/providers'] = (_) => {
        'providers': [
          {'id': 'google', 'label': 'Google', 'enabled': true},
        ],
      };
      a.routes['POST /auth/forgot-password'] = (o) {
        expect(o.data, {'email': 'fixture@example.invalid'});
        return {'ok': true};
      };
      await tester.pumpWidget(host(AccountConnectionsView(controller: w)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set password by email'));
      await tester.pumpAndSettle();
      expect(
        a.calls.where((c) => c.path.endsWith('/forgot-password')),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(RaftButton, 'Send email'));
      await tester.pumpAndSettle();
      expect(
        a.calls.where((c) => c.path.endsWith('/forgot-password')),
        hasLength(1),
      );
      expect(
        find.text(
          'Check your account email for a password setup link. Refresh after setting your password.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'unavailable Slack runtime cannot display setup or healthy connection',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'slack_bridge_v0', 'enabled': true},
        ],
      };
      a.routes['GET /slack-bridge/provisioning'] = (_) => {
        'ok': false,
        'code': 'slack_bridge_provider_unavailable',
      };
      a.statuses['GET /slack-bridge/provisioning'] = 503;
      await tester.pumpWidget(host(IMBridgesView(controller: w)));
      await tester.pumpAndSettle();
      expect(find.text('Connect Slack'), findsNothing);
      expect(find.text('Verify and enable'), findsNothing);
      expect(
        find.text(
          'The install, credential, bindings, and audience are verified.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('disabled Slack flag never reads bridge provisioning', (
    tester,
  ) async {
    final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
    addTearDown(w.dispose);
    a.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'slack_bridge_v0', 'enabled': false},
      ],
    };
    await tester.pumpWidget(host(IMBridgesView(controller: w)));
    await tester.pumpAndSettle();
    expect(
      find.text('Slack bridging is not enabled for this workspace.'),
      findsOneWidget,
    );
    expect(a.calls.where((c) => c.path.startsWith('/slack-bridge')), isEmpty);
  });
  testWidgets('failed Slack preflight never enables bridge', (tester) async {
    final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
    addTearDown(w.dispose);
    a.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'slack_bridge_v0', 'enabled': true},
      ],
    };
    a.routes['GET /slack-bridge/provisioning'] = (_) => bridgeFixture();
    a.routes['POST /slack-bridge/provisioning/preflight'] = (_) {
      final v = bridgeFixture();
      v['snapshot']['preflight'] = {
        'state': 'failed',
        'checks': [
          {'id': 'scope', 'state': 'failed'},
        ],
      };
      return v;
    };
    await tester.pumpWidget(host(IMBridgesView(controller: w)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify and enable'));
    await tester.pumpAndSettle();
    expect(find.text('OAuth scope: Failed'), findsOneWidget);
    expect(a.calls.where((c) => c.path.endsWith('/enable')), isEmpty);
  });
  testWidgets(
    'Slack removal and disconnect send accepted epochs and clear on downgrade',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'slack_bridge_v0', 'enabled': true},
        ],
      };
      final value = bridgeFixture();
      a.routes['GET /slack-bridge/provisioning'] = (_) => value;
      a.routes['DELETE /slack-bridge/provisioning/channel-pairs'] = (o) {
        expect(o.data, {
          'pairs': [
            {
              'raftChannelId': 'r1',
              'slackChannelId': 's1',
              'expectedBindingEpoch': 7,
            },
          ],
        });
        value['snapshot']['channelPairs'] = <dynamic>[];
        return value;
      };
      a.routes['POST /slack-bridge/provisioning/disconnect'] = (o) {
        expect(o.data, {'expectedConnectionEpoch': 4});
        return value;
      };
      await tester.pumpWidget(host(IMBridgesView(controller: w)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RaftButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(a.calls.where((c) => c.method == 'DELETE'), hasLength(1));
      await tester.tap(find.text('Disconnect Slack'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RaftButton, 'Disconnect'));
      await tester.pumpAndSettle();
      expect(
        a.calls.where((c) => c.path.endsWith('/disconnect')),
        hasLength(1),
      );
      w.server = RaftRecord({
        'id': 's1',
        'name': 'Test workspace',
        'role': 'member',
      });
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Verify and enable'), findsNothing);
      expect(find.text('Disconnect Slack'), findsNothing);
    },
  );

  testWidgets(
    'same-generation role downgrade removes private agent events before the next HTTP response',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      final newProfile = Completer<Map<String, dynamic>>();
      a.routes['GET /agents/agent1'] = (_) =>
          w.server?.string('role') == 'owner'
          ? {'id': 'agent1', 'creatorType': 'user', 'creatorId': 'someone-else'}
          : newProfile.future;
      a.routes['GET /integrations/agents/agent1'] = (_) => <dynamic>[];
      a.routes['GET /integrations/agents/agent1/grantable-apps'] = (_) => {
        'apps': <dynamic>[],
      };
      a.routes['GET /integrations/agents/agent1/events'] = (_) => {
        'events': [
          {
            'id': 'event1',
            'summary': 'Private agent event fixture',
            'app': {'name': 'Private app'},
            'kind': 'notification',
            'status': 'accepted',
          },
        ],
      };
      await tester.pumpWidget(
        host(AgentAppAccessView(controller: w, agentId: 'agent1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private agent event fixture'), findsOneWidget);
      final generation = w.client.generation;
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      w.setError(null);
      await tester.pump();
      expect(w.client.generation, generation);
      expect(find.text('Private agent event fixture'), findsNothing);
      expect(find.text('Grant app access'), findsNothing);
      newProfile.complete({
        'id': 'agent1',
        'creatorType': 'user',
        'creatorId': 'someone-else',
      });
      await tester.pumpAndSettle();
      expect(find.text('Private agent event fixture'), findsNothing);
    },
  );
  testWidgets('management header actions wrap at narrow phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
    addTearDown(w.dispose);
    _appRoutes(a, (_) => <dynamic>[]);
    await tester.pumpWidget(host(IntegrationsView(controller: w)));
    await tester.pumpAndSettle();
    expect(find.text('Register app'), findsOneWidget);
    expect(find.text('Install private app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'provider verification rejects a mismatched receipt and retries the same request',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'provider_connections_v0', 'enabled': true},
        ],
      };
      a.routes['GET /provider-connections'] = (_) => {
        'connections': [
          {
            'id': 'p1',
            'name': 'Provider fixture',
            'providerId': 'openai',
            'status': 'configured',
            'enabled': true,
            'assignedAgentCount': 0,
          },
        ],
        'providerOptions': <dynamic>[],
      };
      a.routes['GET /servers/s1/machines'] = (_) => {
        'machines': [
          {
            'id': 'computer1',
            'name': 'Computer fixture',
            'status': 'online',
            'runtimes': ['builtin'],
          },
        ],
      };
      a.routes['GET /provider-connections/p1/models'] = (_) => {
        'models': ['fixture-model'],
      };
      var mismatch = true;
      a.routes['POST /provider-connections/p1/probes'] = (o) {
        final v = o.data as Map;
        return {
          'probe': {
            'probeRequestId': mismatch ? 'wrong-request' : v['probeRequestId'],
            'connectionId': 'p1',
            'computerId': v['computerId'],
            'runtime': 'builtin',
            'model': v['model'],
            'probeKind': 'canary',
            'outcome': 'success',
            'verifiedAt': '2026-10-08T00:00:00Z',
            'closedAt': '2026-10-08T00:00:00Z',
          },
          'reply': null,
        };
      };
      await tester.pumpWidget(host(ProviderConnectionsView(controller: w)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verify on computer'));
      await tester.tap(find.text('Verify on computer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.text('Provider verified'), findsNothing);
      expect(
        find.textContaining(
          'The verification receipt does not match this request. Refresh and retry.',
        ),
        findsOneWidget,
      );
      mismatch = false;
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.text('Provider verified'), findsOneWidget);
      final probes = a.calls
          .where((o) => o.path.endsWith('/probes') && o.method == 'POST')
          .toList();
      expect(probes.length, 2);
      expect(
        probes[0].data['probeRequestId'],
        probes[1].data['probeRequestId'],
      );
      expect(probes[0].receiveTimeout, const Duration(seconds: 50));
    },
  );
  testWidgets(
    'late provider history cannot open a private modal after a role change',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'provider_connections_v0', 'enabled': true},
        ],
      };
      a.routes['GET /provider-connections'] = (_) => {
        'connections': w.server?.string('role') == 'owner'
            ? [
                {
                  'id': 'p1',
                  'name': 'Provider fixture',
                  'providerId': 'openai',
                  'status': 'configured',
                  'enabled': true,
                  'assignedAgentCount': 0,
                },
              ]
            : <dynamic>[],
        'providerOptions': <dynamic>[],
      };
      final pending = Completer<Map<String, dynamic>>();
      a.routes['GET /provider-connections/p1/probes'] = (_) => pending.future;
      await tester.pumpWidget(host(ProviderConnectionsView(controller: w)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verification history'));
      await tester.tap(find.text('Verification history'));
      await tester.pump();
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      w.setError(null);
      await tester.pumpAndSettle();
      pending.complete({
        'receipts': [
          {'model': 'Private previous model', 'outcome': 'success'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Private previous model'), findsNothing);
    },
  );

  testWidgets(
    'a forbidden management refetch erases previously readable private data',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      _appRoutes(
        a,
        (_) => [
          {'id': 'private-app', 'name': 'Private app fixture'},
        ],
      );
      await tester.pumpWidget(host(IntegrationsView(controller: w)));
      await tester.pumpAndSettle();
      expect(find.text('Private app fixture'), findsOneWidget);
      a.statuses['GET /integrations/clients'] = 403;
      a.routes['GET /integrations/clients'] = (_) => {
        'error': 'Permission revoked',
      };
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Private app fixture'), findsNothing);
    },
  );
  testWidgets(
    'last linked sign-in method cannot be disconnected without a password',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['GET /auth/identities'] = (_) => {
        'passwordConfigured': false,
        'identities': [
          {'provider': 'google', 'providerEmail': 'fixture@example.invalid'},
        ],
      };
      a.routes['GET /auth/providers'] = (_) => {
        'providers': [
          {'id': 'google', 'label': 'Google', 'enabled': true},
        ],
      };
      await tester.pumpWidget(host(AccountConnectionsView(controller: w)));
      await tester.pumpAndSettle();
      expect(find.text('Google'), findsOneWidget);
      final disconnect = tester.widget<TextButton>(
        find
            .ancestor(
              of: find.text('Disconnect'),
              matching: find.byWidgetPredicate((w) => w is TextButton),
            )
            .first,
      );
      expect(disconnect.onPressed, isNull);
      expect(a.calls.any((r) => r.method == 'DELETE'), false);
    },
  );

  testWidgets(
    'setup blocks conversation and retains server verdict on failed refetch',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'in_progress',
        'surface': 'computer_runtime',
        'blocksChat': true,
        'allowedExits': <String>[],
        'computerStatus': 'offline',
        'runtimeStatus': 'unknown',
      };
      await tester.pumpWidget(
        host(
          ServerSetupGate(
            controller: w,
            child: const Text('Conversation fixture'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conversation fixture'), findsNothing);
      expect(find.text('Set up your workspace'), findsOneWidget);
      a.routes['GET /servers/s1/setup-projection'] = (_) =>
          throw const RaftApiException('Fixture unavailable');
      await tester.tap(find.text('Refresh setup'));
      await tester.pumpAndSettle();
      expect(find.text('Conversation fixture'), findsNothing);
      expect(find.text('Set up your workspace'), findsOneWidget);
    },
  );
  testWidgets(
    'complete setup still requires authoritative survey and handoff acknowledgment',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      var handoff = true;
      a.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
        'postSetup': {'surveyPending': false, 'handoffPending': handoff},
      };
      a.routes['POST /servers/s1/setup-handoff'] = (_) {
        handoff = false;
        return {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
          'postSetup': {'surveyPending': false, 'handoffPending': false},
        };
      };
      await tester.pumpWidget(
        host(
          ServerSetupGate(
            controller: w,
            child: const Text('Conversation fixture'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conversation fixture'), findsNothing);
      await tester.tap(find.text("Let's Go"));
      await tester.pumpAndSettle();
      expect(find.text('Conversation fixture'), findsOneWidget);
      expect(a.calls.where((o) => o.path.endsWith('/setup-handoff')).length, 1);
    },
  );
  testWidgets('setup survey remains owed even though blocksChat is false', (
    tester,
  ) async {
    final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
    addTearDown(w.dispose);
    a.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
      'postSetup': {'surveyPending': true, 'handoffPending': true},
    };
    await tester.pumpWidget(
      host(
        ServerSetupGate(
          controller: w,
          child: const Text('Conversation fixture'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Conversation fixture'), findsNothing);
    expect(find.text('Tell us about you'), findsOneWidget);
    expect(find.text("Let's Go"), findsNothing);
    await tester.tap(find.text('Tell us about you'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('field-signupRole')), findsOneWidget);
    expect(find.byKey(const ValueKey('field-referralSource')), findsOneWidget);
  });

  testWidgets(
    'disabled providers never read connections or present credential entry',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'provider_connections_v0', 'enabled': false},
        ],
      };
      await tester.pumpWidget(host(ProviderConnectionsView(controller: w)));
      await tester.pumpAndSettle();
      expect(
        find.text('Provider connections are not enabled for this workspace.'),
        findsOneWidget,
      );
      expect(find.text('Add provider'), findsNothing);
      expect(a.calls.any((c) => c.path == '/provider-connections'), false);
      expect(a.calls.any((c) => c.path == '/feature-flags/evaluate'), true);
    },
  );
  testWidgets('admin can read Stripe billing but cannot purchase or cancel', (
    tester,
  ) async {
    final (w, a) = (await tester.runAsync(() => _fixture('admin')))!;
    addTearDown(w.dispose);
    a.routes['GET /billing/subscription'] = (_) => {
      'plan': 'pro',
      'displayName': 'Pro',
      'stripeConfigured': true,
      'permissions': {'canReadBillingSummary': true, 'canManageBilling': false},
      'usage': {'humans': 2, 'agents': 5},
      'provisioned': {'humans': 3, 'agents': 10},
      'subscription': {'status': 'active'},
    };
    await tester.pumpWidget(host(BillingView(controller: w)));
    await tester.pumpAndSettle();
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Manage purchased seats'), findsNothing);
    expect(find.text('Cancel subscription'), findsNothing);
  });
  testWidgets(
    'app registration declares scopes and masks the one-time secret',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      final apps = <Map<String, dynamic>>[];
      _appRoutes(a, (_) => apps);
      a.routes['POST /integrations/clients'] = (o) {
        final app = <String, dynamic>{
          'id': 'created',
          'name': o.data['name'],
          'clientId': 'generated',
          'allowedScopes': o.data['allowedScopes'],
        };
        apps.add(app);
        return {'client': app, 'clientSecret': 'never-render-without-reveal'};
      };
      await tester.pumpWidget(host(IntegrationsView(controller: w)));
      await tester.pumpAndSettle();
      await register(tester);
      expect(find.text('Credential hidden'), findsOneWidget);
      expect(find.text('never-render-without-reveal'), findsNothing);
      expect(
        a.calls
            .singleWhere(
              (c) => c.method == 'POST' && c.path == '/integrations/clients',
            )
            .data['allowedScopes'],
        ['openid', 'profile', 'identity'],
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Native fixture app'), findsOneWidget);
    },
  );
  testWidgets('workspace change dismisses the private credential modal', (
    tester,
  ) async {
    final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
    addTearDown(w.dispose);
    _appRoutes(a, (_) => <dynamic>[]);
    a.routes['POST /integrations/clients'] = (_) => {
      'client': {'id': 'a'},
      'clientSecret': 'private-one-time',
    };
    await tester.pumpWidget(host(IntegrationsView(controller: w)));
    await tester.pumpAndSettle();
    await register(tester);
    expect(find.byType(RaftSecretView), findsOneWidget);
    w.client.selectServer('s2');
    w.server = RaftRecord({'id': 's2', 'role': 'owner'});
    w.setError(null);
    await tester.pumpAndSettle();
    expect(find.byType(RaftSecretView), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets(
    'role change dismisses private credentials without changing workspace generation',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      _appRoutes(a, (_) => <dynamic>[]);
      a.routes['POST /integrations/clients'] = (_) => {
        'client': {'id': 'a'},
        'clientSecret': 'private-one-time',
      };
      await tester.pumpWidget(host(IntegrationsView(controller: w)));
      await tester.pumpAndSettle();
      await register(tester);
      final generation = w.client.generation;
      expect(find.byType(RaftSecretView), findsOneWidget);
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      w.setError(null);
      await tester.pumpAndSettle();
      expect(w.client.generation, generation);
      expect(find.byType(RaftSecretView), findsNothing);
      expect(find.text('Register app'), findsNothing);
    },
  );
  testWidgets(
    'late old workspace response cannot reveal previous private apps',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      final old = Completer<List<Map<String, dynamic>>>();
      _appRoutes(
        a,
        (o) => o.headers['X-Server-Id'] == 's1'
            ? old.future
            : [
                {'id': 'new', 'name': 'New workspace app'},
              ],
      );
      await tester.pumpWidget(host(IntegrationsView(controller: w)));
      await tester.pump();
      w.client.selectServer('s2');
      w.server = RaftRecord({'id': 's2', 'role': 'owner'});
      w.setError(null);
      await tester.pumpAndSettle();
      old.complete([
        {'id': 'old', 'name': 'Old private app'},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('New workspace app'), findsOneWidget);
      expect(find.text('Old private app'), findsNothing);
    },
  );
}
