// Web v1.21.23 AgentAppAccessTab: the App events section is for every viewer
// of the Apps tab, its app chips come from the events seen, and the app cards
// carry date, grant source, description, manifest and a service link.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_apps_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/integ_fixture.dart';

Map<String, dynamic> _event(String id, String app, String clientId) => {
  'id': id,
  'summary': 'Event $id',
  'app': {'clientId': clientId, 'name': app},
  'kind': 'notification',
  'status': 'delivered',
  'createdAt': '2026-10-21T01:02:03.000Z',
};

void main() {
  Future<IntegAdapter> pump(WidgetTester t, String role) async {
    final (w, a) = (await t.runAsync(() => integFixture(role)))!;
    addTearDown(w.dispose);
    a.routes['GET /agents/a1'] = (_) => {
      'id': 'a1',
      'creatorType': 'user',
      'creatorId': 'someone-else',
    };
    a.routes['GET /integrations/agents/a1'] = (_) => [
      {
        'id': 'g1',
        'type': 'active',
        'clientId': 'c1',
        'clientName': 'Acme',
        'clientDescription': 'Acme does things',
        'clientHomepageUrl': 'https://acme.example.com',
        'clientAgentManifestUrl': 'https://acme.example.com/manifest.json',
        'scopes': ['agent:read'],
        'createdAt': '2026-10-20T01:02:03.000Z',
        'grantSource': 'agent_login',
      },
    ];
    a.routes['GET /integrations/agents/a1/events/1'] = (_) => {
      'id': '1',
      'payload': {'hello': 'world'},
    };
    a.routes['GET /integrations/agents/a1/events'] = (o) {
      final only = o.queryParameters['clientId'];
      return {
        'events': [
          if (only == null || only == 'c1') _event('1', 'Acme', 'c1'),
          if (only == null || only == 'c2') _event('2', 'Bolt', 'c2'),
        ],
        'nextCursor': null,
      };
    };
    t.view.physicalSize = const Size(900, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: AgentAppAccessView(controller: w, agentId: 'a1'),
        ),
      ),
    );
    await t.pumpAndSettle();
    return a;
  }

  testWidgets('a plain member sees the App events', (t) async {
    final a = await pump(t, 'member');
    expect(find.text('Event 1'), findsOneWidget);
    expect(find.text('Event 2'), findsOneWidget);
    expect(find.text('Delivered'), findsNWidgets(2));
    expect(a.calls.where((c) => c.path.endsWith('/events')), isNotEmpty);
    // Granting stays with the managers.
    expect(find.text('Grant Access'), findsNothing);
    expect(find.text('Revoke'), findsNothing);
  });

  testWidgets('the app chips come from the events and filter them', (t) async {
    final a = await pump(t, 'member');
    expect(find.text('All Apps'), findsOneWidget);
    await t.tap(find.text('Bolt').first);
    await t.pumpAndSettle();
    expect(find.text('Event 2'), findsOneWidget);
    expect(find.text('Event 1'), findsNothing);
    expect(a.calls.last.queryParameters['clientId'], 'c2');
    // The chips survive the filtered read.
    expect(find.text('All Apps'), findsOneWidget);
    await t.tap(find.text('All Apps'));
    await t.pumpAndSettle();
    expect(find.text('Event 1'), findsOneWidget);
  });

  testWidgets(
    'the app card carries source, description, manifest and service',
    (t) async {
      await pump(t, 'member');
      expect(find.text('Granted when the agent signed in'), findsOneWidget);
      expect(find.text('Acme does things'), findsOneWidget);
      expect(
        find.text('Agent manifest: https://acme.example.com/manifest.json'),
        findsOneWidget,
      );
      expect(find.text('View service'), findsOneWidget);
    },
  );

  testWidgets('an event opens its payload under the row and reads it once', (
    t,
  ) async {
    final a = await pump(t, 'member');
    int reads() => a.calls.where((c) => c.path.endsWith('/events/1')).length;
    expect(find.byKey(const ValueKey('app-event-payload-1')), findsNothing);
    await t.tap(find.text('Event 1'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('app-event-payload-1')), findsOneWidget);
    expect(find.textContaining('"hello": "world"'), findsOneWidget);
    expect(reads(), 1);
    await t.tap(find.text('Event 1'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-event-payload-1')), findsNothing);
    await t.tap(find.text('Event 1'));
    await t.pumpAndSettle();
    expect(find.textContaining('"hello": "world"'), findsOneWidget);
    expect(reads(), 1);
  });

  testWidgets('a failed payload read shows the error under the row', (t) async {
    await pump(t, 'member');
    await t.tap(find.text('Event 2'));
    await t.pumpAndSettle();
    // The unrouted read answers 404; the row shows the failure, not JSON.
    expect(find.byKey(const ValueKey('app-event-payload-2')), findsNothing);
    expect(find.byType(RaftErrorBanner), findsOneWidget);
  });
}
