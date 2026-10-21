import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/resource_view.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;
import 'task_claim_flow_test.dart' show TaskPageWorkspace, row;

void main() {
  // Web TaskCard: `TaskCardLegacy` ("Legacy", task.badge.legacy) follows the
  // number of a pre-thread task and appears on no other card.
  testWidgets('only a pre-thread task card carries the Legacy badge', (
    tester,
  ) async {
    final client = ActivityClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    final w = TaskPageWorkspace(client)
      ..server = RaftRecord({'id': 's1', 'role': 'member'})
      ..channels = [
        RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
      ]
      ..tasks = [
        {...row('old', 'todo', number: 2), 'isLegacy': true},
        row('new', 'todo', number: 3),
      ];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'tasks',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final badge = find.text('Legacy');
    expect(badge, findsOneWidget);
    final card = find.ancestor(of: badge, matching: find.byType(RaftTaskCard));
    expect(
      find.descendant(of: card, matching: find.text('#2')),
      findsOneWidget,
    );
    expect(find.text('LEGACY'), findsNothing);
  });
}
