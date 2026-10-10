import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/task_board_reconcile.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;
import 'task_snapshot_navigation_test.dart' show taskRow;

class _Tasks extends WorkspaceController {
  _Tasks(super.client);
  // Deliberately not in task-number order: Source sorts at render.
  final tasks = [
    taskRow(3, 'todo'),
    taskRow(9, 'todo'),
    taskRow(5, 'todo'),
    taskRow(7, 'in_progress'),
    taskRow(2, 'in_progress'),
  ];
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (!path.startsWith('/tasks/')) return [];
    final status = query?['status'];
    return {
      'tasks': [
        for (final row in tasks)
          if (status == null || row['status'] == status)
            Map<String, dynamic>.of(row),
      ],
      'next_cursor': null,
    };
  }
}

void main() {
  test(
    'sortedLane orders newest task number first and reuses sorted lanes',
    () {
      final sorted = [taskRow(9, 'todo'), taskRow(5, 'todo')];
      expect(identical(sortedLane(sorted), sorted), isTrue);
      expect(
        sortedLane([
          taskRow(3, 'todo'),
          taskRow(9, 'todo'),
          taskRow(5, 'todo'),
        ]).map((t) => t['taskNumber']),
        [9, 5, 3],
      );
    },
  );

  for (final layout in ['board', 'list']) {
    testWidgets('$layout lanes render newest task number first', (
      tester,
    ) async {
      final client = ActivityClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      final w = _Tasks(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
        ];
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = layout == 'board'
          ? const Size(1400, 900)
          : const Size(400, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: RaftDensityScope(
            density: layout == 'board'
                ? RaftDensity.desktop
                : RaftDensity.touch,
            child: Scaffold(
              body: ResourceView(
                controller: w,
                section: 'tasks',
                onMessage: (_, _) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ResourceView));
      expect(state.taskLayout, layout);
      double top(int n) => tester.getTopLeft(find.text('Task $n')).dy;
      expect(top(9), lessThan(top(5)));
      expect(top(5), lessThan(top(3)));
      expect(top(7), lessThan(top(2)));
    });
  }
}
