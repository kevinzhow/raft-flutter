import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'support/close_support.dart' show frames;
import 'workspace_source_location_contract_test.dart' show pageFixture;

Future<void> mountDirectory(
  WidgetTester tester,
  MessageAdapter api,
  WorkspaceController workspace,
) async {
  tester.view.physicalSize = const Size(1280, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  api.routes['GET /servers/s1/members'] = (_) => [];
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: DesktopDirectoryView(controller: workspace, onSelected: (_) {}),
      ),
    ),
  );
  await frames(tester);
}

void main() {
  testWidgets('MembersPage.tsx narrow desktop More changes Usage period', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester, section: 'members');
    api.routes['GET /agents'] = (_) => [
      {'id': 'agent', 'name': 'Agent', 'status': 'active'},
    ];
    api.routes['GET /servers/s1/machines'] = (_) => {'machines': []};
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'agent_usage_v0', 'enabled': true},
      ],
    };
    api.routes['GET /servers/s1/agent-usage'] = (request) => {
      'from': request.queryParameters['from'],
      'to': request.queryParameters['to'],
      'as_of': "${request.queryParameters['to']}T12:00:00Z",
      'agents': [],
      'rows': [],
    };
    await mountDirectory(tester, api, workspace);
    await tester.tap(find.byKey(const ValueKey('members-tab-agent')));
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('members-view-usage')));
    await frames(tester);
    tester.view.physicalSize = const Size(390, 844);
    await frames(tester);
    expect(find.byKey(const ValueKey('agent-usage-period')), findsNothing);
    final more = find.byKey(const ValueKey('members-toolbar-more'));
    await tester.tap(more);
    await frames(tester);
    for (final label in ['Today', '7 days', '14 days', '30 days']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Today'));
    await frames(tester);
    expect(
      api.calls.where((call) => call.path == '/servers/s1/agent-usage'),
      hasLength(1),
    );
    tester.view.physicalSize = const Size(1280, 844);
    await frames(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agent-usage-period')),
        matching: find.text('Today'),
      ),
      findsOneWidget,
    );
    tester.view.physicalSize = const Size(390, 844);
    await frames(tester);
    await tester.tap(more);
    await frames(tester);
    await tester.tap(find.text('14 days'));
    await frames(tester);
    final calls = api.calls.where(
      (call) => call.path == '/servers/s1/agent-usage',
    );
    expect(calls, hasLength(2));
    final query = calls.last.queryParameters;
    final from = DateTime.parse(query['from'] as String);
    final to = DateTime.parse(query['to'] as String);
    expect(to.difference(from).inDays, 27);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MembersPage.tsx header includes working and thinking agents', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester, section: 'members');
    api.routes['GET /agents'] = (_) => [
      for (final activity in ['working', 'thinking', 'online'])
        {
          'id': activity,
          'name': activity,
          'status': 'active',
          'activityKind': activity,
        },
    ];
    api.routes['GET /servers/s1/machines'] = (_) => {'machines': []};
    await mountDirectory(tester, api, workspace);
    expect(find.text('2 agents working · 3 members'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('MembersPage.tsx grouped agents get one set of column labels', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester, section: 'members');
    api.routes['GET /agents'] = (_) => [
      for (final name in ['Studio', 'Travel'])
        {
          'id': 'agent-$name',
          'name': 'Agent $name',
          'status': 'active',
          'creatorId': 'creator-$name',
          'creator': {'name': 'Creator $name'},
          'machineId': name,
          'runtime': 'claude',
          'model': 'sonnet',
        },
    ];
    api.routes['GET /servers/s1/machines'] = (_) => {
      'machines': [
        for (final name in ['Studio', 'Travel'])
          {'id': name, 'name': '$name Computer', 'status': 'online'},
      ],
    };
    await mountDirectory(tester, api, workspace);
    await tester.tap(find.byKey(const ValueKey('members-tab-agent')));
    await frames(tester);
    final grouping = find.byKey(const ValueKey('members-group-select'));
    await tester.tap(grouping);
    await frames(tester);
    await tester.tap(find.text('By creator'));
    await frames(tester);
    expect(find.text('Creator Studio  1'), findsOneWidget);
    expect(find.text('Creator Travel  1'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Computer'), findsOneWidget);
    expect(find.text('Studio Computer'), findsOneWidget);

    await tester.tap(grouping);
    await frames(tester);
    await tester.tap(find.text('By computer'));
    await frames(tester);
    expect(find.text('Studio Computer  1'), findsOneWidget);
    expect(find.text('Travel Computer  1'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Computer'), findsNothing);
    expect(find.text('Studio Computer'), findsNothing);
    expect(find.text('Travel Computer'), findsNothing);
    expect(find.text('Agent Studio'), findsOneWidget);
    expect(find.text('Agent Travel'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
