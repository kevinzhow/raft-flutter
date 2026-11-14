import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

/// A task reference to a task in the v1.24 `backlog` status shows Backlog,
/// not Todo (Web taskStatusUi: backlog has its own label and chip).
void main() {
  testWidgets('a #task reference in backlog keeps the backlog status', (
    tester,
  ) async {
    final w = WorkspaceController(
      RaftClient(
        origin: 'https://api.raft.build',
        sessionStore: MemorySessionStore(),
      ),
    )..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Dev'});
    addTearDown(w.dispose);
    for (final entry in {
      'backlog': RaftMessageTaskStatus.backlog,
      'todo': RaftMessageTaskStatus.todo,
    }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: MessagePresentation(
              key: ValueKey(entry.key),
              controller: w,
              message: RaftMessage({
                'id': 'm1',
                'channelId': 'c1',
                'content': 'see task #7',
              }),
              taskByNumber: (n) => n == 7
                  ? {'taskNumber': 7, 'status': entry.key, 'title': 'T'}
                  : null,
              knownTaskNumber: (_) => true,
              onExternalLink: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      final chip = tester.widget<RaftReferenceChip>(
        find.byType(RaftReferenceChip),
      );
      expect(chip.appearance.taskStatus, entry.value, reason: entry.key);
    }
  });
}
