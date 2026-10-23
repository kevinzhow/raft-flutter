import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'support/app_services_fixture.dart';
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;

// Web v1.21.23 TaskModalBar: an icon action "View in thread" leaves the task
// for the ordinary thread of its message; legacy tasks and tasks whose message
// is itself a thread reply have none.
void main() {
  const viewInThread = ValueKey('task-modal-view-in-thread');

  Future<(dynamic, dynamic)> openTask(
    WidgetTester t,
    double width,
    Map<String, dynamic> task,
  ) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, api) = await pageFixture(t, section: 'tasks');
    taskRoutes(api, task);
    api.routes['GET /tasks/channel/c1'] = (_) => {
      'tasks': [task],
    };
    api.routes['GET /channels/c1/threads/task-parent'] = (_) => {
      'threadChannelId': 'task-thread',
    };
    api.routes['GET /messages/channel/c1'] = (_) => {
      'messages': [row('task-parent', 'c1', 1)],
    };
    api.routes['GET /messages/context/task-parent'] = (_) => {
      'messages': [row('task-parent', 'c1', 1)],
    };
    api.routes['POST /channels/c1/read'] = (_) => {};
    w.navigation.navigateTask(
      w.location.withQuery({
        task['isLegacy'] == true ? 'legacyTask' : 'task':
            'c1:${task['isLegacy'] == true ? task['id'] : 'task-parent'}',
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(light: RaftFamily.elegant),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await flush(t);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 300));
    });
    return (w, api);
  }

  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'View in thread opens the message thread, not the task ($width)',
      (t) async {
        final (w, api) = await openTask(t, width, modernTask);
        expect(find.byType(SourceTaskSurface), findsOneWidget);
        expect(find.byKey(viewInThread), findsOneWidget);
        expect(find.byTooltip('View in thread'), findsOneWidget);
        await t.tap(find.byKey(viewInThread));
        await flush(t);
        await t.pump(const Duration(milliseconds: 500));
        expect(find.byType(SourceTaskSurface), findsNothing);
        final RaftLocation location = w.location;
        expect(location.task, isNull);
        expect(location.route, RaftRoute.channel);
        expect(location.entityId, 'c1');
        expect(location.thread!.toString(), 'c1:task-parent');
        expect(location.messageId, 'task-parent');
        expect(w.threadIdentity?.parentMessageId, 'task-parent');
        expect(w.threadChannelId, 'task-thread');
        expect(t.takeException(), isNull);
        expect(api.calls.where((r) => r.method == 'PATCH'), isEmpty);
      },
    );
  }

  testWidgets('a legacy task has no View in thread', (t) async {
    await openTask(t, 1280, {
      ...modernTask,
      'id': 'legacy-id',
      'isLegacy': true,
    });
    expect(find.byKey(const ValueKey('legacy-task-panel')), findsOneWidget);
    expect(find.byKey(viewInThread), findsNothing);
  });

  testWidgets('a task on a thread reply has no View in thread', (t) async {
    await openTask(t, 1280, {...modernTask, 'channelType': 'thread'});
    expect(find.byType(SourceTaskSurface), findsOneWidget);
    expect(find.byKey(viewInThread), findsNothing);
  });
}
