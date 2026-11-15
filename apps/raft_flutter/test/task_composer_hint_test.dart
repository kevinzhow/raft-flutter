// Web ThreadPanelComposer: a task's own conversation says "Message this
// task", any other thread "Message thread".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_v2_mode.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('the composer hint names the task in its conversation', (
    t,
  ) async {
    late String task, thread;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) {
            task = threadComposerHint(context, true);
            thread = threadComposerHint(context, false);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(task, 'Message this task');
    expect(thread, 'Message thread');
  });
}
