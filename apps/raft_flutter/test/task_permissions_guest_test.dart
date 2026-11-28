import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/task_surface_controller.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' as messages;
import 'support/tasks_page_harness.dart';
import 'task_surface_test.dart' as details;

void main() {
  testWidgets('the Tasks page opens creation for a guest in their channel', (
    tester,
  ) async {
    final (workspace, server) = (await tester.runAsync(
      () => tasksFixture(role: 'guest'),
    ))!;
    addTearDown(workspace.dispose);
    await tester.runAsync(() => TaskV2ConversationsFlag.of(workspace).ensure());
    server.routes['POST /tasks/channel/c1'] = (_) => (
      200,
      {
        'tasks': [pageTask('created')],
      },
    );
    await mountPage(tester, workspace, size: const Size(2600, 900));
    final create = find.byKey(const ValueKey('tasks-page-new-task'));
    expect(create, findsOneWidget);
    await tester.tap(create);
    await settleTasks(tester);
    await tester.tap(find.byKey(const ValueKey('create-task-channel')));
    await settleTasks(tester);
    await tester.tap(find.text('#test').last);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('create-task-message')),
        matching: find.byType(EditableText),
      ),
      'Ship it',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-task-submit')));
    await settleTasks(tester);
    expect(server.writes('POST').map((request) => request.path), [
      '/tasks/channel/c1',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final readOnly in [false, true]) {
    testWidgets('guest task controls with readOnlyReason=$readOnly', (
      tester,
    ) async {
      final (workspace, api) = (await tester.runAsync(
        () => messages.fixture('guest'),
      ))!;
      final task = {
        ...details.modernTask,
        'conversationAnchored': true,
        'conversationChannelId': 'task-thread',
        'revision': 4,
        if (readOnly) 'readOnlyReason': 'historical_joint_task',
      };
      details.taskRoutes(api, task);
      api.routes['GET /channels/c1/members'] = (_) => {
        'agents': [
          {'id': 'agent-guide', 'displayName': 'Guide'},
        ],
      };
      api.routes['PATCH /tasks/task-1'] = (_) => {
        'task': task..['title'] = 'Updated task',
      };
      api.routes['PATCH /tasks/task-1/assignee'] = (_) => {
        'task': task
          ..['claimedById'] = 'agent-guide'
          ..['claimedByType'] = 'agent'
          ..['claimedByName'] = 'Guide',
      };
      api.routes['PATCH /tasks/task-1/status'] = (_) => {
        'task': task..['status'] = 'done',
      };
      final owner = TaskSurfaceController(
        parent: workspace,
        row: task,
        valid: () => true,
      );
      owner.openDiscussion();
      sizeWindow(tester, const Size(1280, 900));
      try {
        await tester.pumpWidget(
          tasksApp(
            SourceTaskSurface(
              owner: owner,
              onClose: () {},
              onTask: null,
              onViewBilling: null,
            ),
          ),
        );
        await settleTasks(tester);
        final edit = find.byKey(const ValueKey('task-modal-title-edit'));
        final status = find.byKey(const ValueKey('task-properties-status'));
        final assignee = find.byKey(const ValueKey('task-properties-assignee'));
        if (readOnly) {
          expect(edit, findsNothing);
          expect(tester.widget<RaftInlineBadgeEditor>(status).enabled, isFalse);
          expect(
            tester.widget<RaftInlineBadgeEditor>(assignee).enabled,
            isFalse,
          );
        } else {
          await tester.tap(edit);
          await settleTasks(tester);
          final field = find.descendant(
            of: find.byKey(const ValueKey('task-head-title-input')),
            matching: find.byType(EditableText),
          );
          await tester.enterText(field, 'Updated task');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await settleTasks(tester);
          expect(find.text('Updated task'), findsOneWidget);
          await tester.tap(assignee);
          await settleTasks(tester);
          await tester.tap(find.text('Guide'));
          await settleTasks(tester);
          await tester.tap(
            find.byKey(const ValueKey('task-handoff-reason-confirm')),
          );
          await settleTasks(tester);
          expect(find.text('@Guide'), findsOneWidget);
          await tester.tap(status);
          await settleTasks(tester);
          await tester.tap(find.text('Done').last);
          await settleTasks(tester);
          expect(
            tester.widget<RaftInlineBadgeEditor>(assignee).enabled,
            isFalse,
          );
        }
        expect(
          api.calls
              .where((call) => call.method == 'PATCH')
              .map((call) => call.path),
          readOnly
              ? isEmpty
              : [
                  '/tasks/task-1',
                  '/tasks/task-1/assignee',
                  '/tasks/task-1/status',
                ],
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        owner.dispose();
        workspace.dispose();
      }
    });
  }
}
