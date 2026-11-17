// Web v1.24 TaskContentSlot (TaskContentSlot.tsx, tasksPageOpen.ts): with
// task v2 a task opened from the Tasks page shows beside the list, not as the
// centered modal: the list stays, the address is `?open=task:<id>` beside
// `?task=<channel>:task:<id>`, its × and Escape close it and focus goes back
// to the task's card. On a phone it is the task's page, its Back returning to
// the list. Activity / Search open the same slot in their detail column.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/task_content_slot.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'support/app_services_fixture.dart';
import 'task_surface_test.dart' show taskRoutes, flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;

/// A task made the v2 way, with its own conversation.
final v2Task = <String, dynamic>{
  'id': 'task-1',
  'taskNumber': 8,
  'title': 'Scoped actual task',
  'description': 'Accepted task description',
  'channelId': 'c1',
  'channelName': 'test',
  'channelType': 'channel',
  'messageId': 'task-1',
  'sourceMessageId': 'src',
  'sourceRecorded': true,
  'conversationAnchored': true,
  'conversationChannelId': 'task-conv',
  'conversationReplyCount': 0,
  'status': 'todo',
  'revision': 1,
  'createdByType': 'user',
  'createdById': 'alice',
  'createdByName': 'Alice',
};

Future<WorkspaceController> mountTasks(
  WidgetTester t,
  Size size, {
  String section = 'tasks',
  bool v2 = true,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!'${details.exception}'.contains('overflowed')) previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  final (w, api) = await pageFixture(t, section: section);
  taskRoutes(api, v2Task);
  api.routes['GET /tasks/channel/c1'] = (_) => {
    'tasks': [v2Task],
  };
  api.routes['GET /messages/channel/task-conv'] = (_) => {
    'messages': <dynamic>[],
  };
  api.routes['POST /channels/task-conv/read'] = (_) => {};
  api.routes['GET /tasks/task-1'] = (_) => {'task': v2Task};
  // The Tasks page with task v2 reads its lanes and counts (the task is the
  // viewer's own, not assigned: 你发起的).
  final board = api.routes['GET /tasks/server']!;
  api.routes['GET /tasks/server'] = (o) => o.queryParameters['relation'] == null
      ? board(o)
      : {
          'tasks': o.queryParameters['relation'] == 'created_by_me'
              ? [v2Task]
              : <dynamic>[],
          'next_cursor': null,
        };
  api.routes['GET /tasks/server/counts'] = (o) => {
    'counts': {
      'todo': o.queryParameters['relation'] == 'created_by_me' ? 1 : 0,
    },
    'relations': <String, dynamic>{},
  };
  if (v2) TaskV2ConversationsFlag.of(w).markEnabled();
  w.messageDomain.ledger.ingest([
    row('accepted-main', 'c1', 1),
  ], expectedGeneration: w.messageDomain.ledger.generation);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await flush(t);
  return w;
}

Future<void> settle(WidgetTester t) async {
  await flush(t);
  await t.pump(const Duration(milliseconds: 400));
  await flush(t);
}

/// The task's card on the status board (task v2 off), or its row on the
/// Tasks page (on).
final card = find.byWidgetPredicate(
  (w) =>
      (w is RaftTaskCard && w.key == const ValueKey('task-task-1')) ||
      w.key == const ValueKey('tasks-page-row-cell-task-1'),
);
final slot = find.byKey(const ValueKey('task-content-slot'));

bool focusIn(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final target = finder.evaluate().single;
  var inside = identical(focused, target);
  focused.visitAncestorElements((e) {
    if (identical(e, target)) inside = true;
    return !inside;
  });
  return inside;
}

void main() {
  const desktop = Size(1280, 800);
  testWidgets('desktop: a v2 task opens beside the Tasks list, × closes it '
      'and focus returns to its card', (t) async {
    final w = await mountTasks(t, desktop);
    await t.tap(card);
    await settle(t);
    expect(find.byType(SourceTaskSurface), findsOneWidget);
    expect(slot, findsOneWidget, reason: 'in place, not the modal');
    expect(card, findsOneWidget, reason: 'the list stays beside it');
    expect(w.location.query('open'), 'task:task-1');
    expect(w.location.query('task'), 'c1:task:task-1');
    // Beside the list: the card is left of the task's column, not under it.
    expect(t.getRect(card).right, lessThanOrEqualTo(t.getRect(slot).left + 1));
    expect(find.byKey(const ValueKey('tasks-route-detail-resize')), findsOne);
    await t.tap(find.byKey(const ValueKey('task-modal-close')));
    await settle(t);
    expect(find.byType(SourceTaskSurface), findsNothing);
    expect(w.location.query('open'), isNull);
    expect(w.location.query('task'), isNull);
    expect(focusIn(card), isTrue, reason: 'focus back on the task card');
  });

  testWidgets('desktop: Escape inside the task closes it, focus back on the '
      'card', (t) async {
    final w = await mountTasks(t, desktop);
    await t.tap(card);
    await settle(t);
    expect(slot, findsOneWidget);
    // Focus a control of the task (its ×), then Escape.
    final close = find.byKey(const ValueKey('task-modal-close'));
    Focus.maybeOf(t.element(close))?.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(t);
    expect(find.byType(SourceTaskSurface), findsNothing);
    expect(w.location.query('open'), isNull);
    expect(focusIn(card), isTrue);
  });

  testWidgets('desktop: Escape in the task\'s composer leaves it open', (
    t,
  ) async {
    final w = await mountTasks(t, desktop);
    await t.tap(card);
    await settle(t);
    final field = find.descendant(
      of: slot,
      matching: find.byType(EditableText),
    );
    expect(field, findsWidgets);
    await t.tap(field.first);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(t);
    expect(slot, findsOneWidget);
    expect(w.location.query('open'), 'task:task-1');
  });

  testWidgets('task v2: the Tasks page has New task, the dialog asks for '
      'the channel; off, it has none', (t) async {
    await mountTasks(t, desktop);
    // The page's own toolbar (a wide window shows its words).
    final newTask = find.byKey(const ValueKey('tasks-page-new-task'));
    expect(newTask, findsOneWidget);
    await t.tap(newTask);
    await settle(t);
    expect(find.byKey(const ValueKey('create-task-channel-field')), findsOne);
    expect(find.byKey(const ValueKey('create-task-status')), findsOne);
    await t.pumpWidget(const SizedBox());
    await mountTasks(t, desktop, v2: false);
    expect(find.byType(RaftNewTaskButton), findsNothing);
  });

  testWidgets('desktop, task v2 off: the Tasks page keeps the dialog', (
    t,
  ) async {
    final w = await mountTasks(t, desktop, v2: false);
    await t.tap(card);
    await settle(t);
    expect(find.byType(SourceTaskSurface), findsOneWidget);
    expect(slot, findsNothing);
    expect(w.location.query('open'), isNull);
  });

  testWidgets('phone: the task is a page over the list, Back returns to it', (
    t,
  ) async {
    final w = await mountTasks(t, const Size(390, 844));
    await t.tap(card);
    await settle(t);
    expect(find.byType(SourceTaskSurface), findsOneWidget);
    expect(w.location.query('task'), 'c1:task:task-1');
    await t.tap(find.byKey(const ValueKey('task-modal-mobile-back')));
    await settle(t);
    expect(find.byType(SourceTaskSurface), findsNothing);
    expect(w.location.query('task'), isNull);
    expect(card, findsOneWidget);
  });

  testWidgets('Activity: a task row opens the task in the detail column', (
    t,
  ) async {
    final w = await mountTasks(t, desktop, section: 'activity');
    final opened = openTaskFromList(w, {
      'kind': 'task',
      'taskId': 'task-1',
      'parentChannelId': 'c1',
      'threadChannelId': 'task-conv',
    }, wide: true);
    expect(opened, isTrue);
    await settle(t);
    expect(w.location.route, RaftRoute.activity);
    expect(w.location.query('open'), 'task:task-1');
    expect(slot, findsOneWidget);
    expect(find.byType(SourceTaskSurface), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('task-modal-close')));
    await settle(t);
    expect(slot, findsNothing);
    expect(w.location.query('open'), isNull);
    expect(w.location.query('task'), isNull);
  });

  test('only task conversation rows and hits open the slot', () {
    expect(
      taskSlotId(
        RaftLocation.parse('/s/demo/activity?open=task:t1&task=c1:task:t1'),
      ),
      't1',
    );
    expect(
      taskSlotId(
        RaftLocation.parse('/s/demo/activity?open=task:t1&task=c1:m1'),
      ),
      isNull,
      reason: 'a message-keyed task is the dialog',
    );
    expect(
      taskSlotId(
        RaftLocation.parse('/s/demo/channel/c1?open=task:t1&task=c1:task:t1'),
      ),
      isNull,
    );
  });
}
