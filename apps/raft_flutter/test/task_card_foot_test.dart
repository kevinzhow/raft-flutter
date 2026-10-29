import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;
import 'task_claim_flow_test.dart' show TaskPageWorkspace, row;

void main() {
  // Web v1.21.23 TaskCard foot: `mt-2 flex min-w-0 items-center gap-2`, the
  // status chip is the first item (v1.21.12 pushed it to the end with
  // `justify-end`) and its menu is left-aligned (dropdownAlign="left").
  testWidgets('the status chip sits at the start of the card foot', (
    tester,
  ) async {
    final client = ActivityClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    final w = TaskPageWorkspace(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
      ]
      ..tasks = [row('a', 'todo')];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
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
    final card = tester.getRect(find.byType(RaftTaskCard));
    final chip = tester.getRect(find.byType(RaftInlineBadgeEditor));
    expect(chip.left - card.left, lessThan(24));
    expect(card.right - chip.right, greaterThan(card.width / 2));
    expect(
      tester
          .widget<RaftInlineBadgeEditor>(find.byType(RaftInlineBadgeEditor))
          .alignRight,
      isFalse,
    );
  });
}
