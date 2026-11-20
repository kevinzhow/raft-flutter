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
  TargetPlatform? platform,
  List<Map<String, dynamic>> discussionMessages = const [],
  bool twoTasks = false,
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
  final second = <String, dynamic>{
    ...v2Task,
    'id': 'task-2',
    'messageId': 'task-2',
    'title': 'Second task title',
    'taskNumber': 9,
    'conversationChannelId': 'second-conv',
    'hostMessageId': 'earlier',
  };
  final tasks = [v2Task, if (twoTasks) second];
  if (twoTasks) {
    api.routes['GET /tasks/server'] = (request) => {
      'tasks': request.queryParameters['relation'] == 'created_by_me'
          ? tasks
          : <dynamic>[],
      'next_cursor': null,
    };
    api.routes['GET /tasks/channel/c1/number/9'] = (_) => {'task': second};
    api.routes['GET /tasks/task-2/history'] = (_) => {'events': <dynamic>[]};
    api.routes['GET /messages/channel/second-conv'] = (_) => {
      'messages': <dynamic>[],
    };
    api.routes['POST /channels/second-conv/read'] = (_) => {};
  }
  if (section == 'activity') {
    api.routes['GET /channels/inbox'] = (_) => {
      'items': [
        {
          'kind': 'task',
          'threadChannelId': 'task-conv',
          'parentChannelId': 'c1',
          'parentChannelName': 'test',
          'parentChannelType': 'channel',
          'taskId': 'task-1',
          'taskTitle': v2Task['title'],
          'taskNumber': 8,
          'taskStatus': 'todo',
          'lastActivityAt': '2026-11-18T12:00:00Z',
          'unreadCount': 0,
          'isFollowing': true,
        },
      ],
      'hasMore': false,
      'totalCount': 1,
      'totalUnreadCount': 0,
    };
  }
  api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': tasks};
  api.routes['GET /messages/channel/task-conv'] = (_) => {
    'messages': discussionMessages,
  };
  api.routes['POST /channels/task-conv/read'] = (_) => {};
  api.routes['GET /tasks/task-1'] = (_) => {'task': v2Task};
  if (v2) TaskV2ConversationsFlag.of(w).markEnabled();
  w.messageDomain.ledger.ingest([
    row('accepted-main', 'c1', 1),
  ], expectedGeneration: w.messageDomain.ledger.generation);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
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
  testWidgets('Tasks detail shows its head and one empty discussion on open '
      'and switch, then close returns to the list', (t) async {
    try {
      final w = await mountTasks(t, desktop, twoTasks: true);
      final second = find.byKey(const ValueKey('tasks-page-row-cell-task-2'));
      final title = find.byKey(const ValueKey('task-modal-title'));
      final empty = find.text('No discussion in this task yet');
      final replies = find.text('No replies yet');

      await t.tap(card.hitTestable());
      await settle(t);
      expect(w.location.query('open'), 'task:task-1');
      expect(title.hitTestable(), findsOneWidget);
      expect(t.widget<Text>(title).data, v2Task['title']);
      expect(empty.hitTestable(), findsOneWidget);
      expect(replies, findsNothing);
      expect(find.byType(RaftComposer), findsOneWidget);

      final editor = find.descendant(
        of: slot,
        matching: find.byType(EditableText),
      );
      await t.enterText(editor, 'Draft stays with the task');
      final expand = find.byKey(const ValueKey('task-focus-mode'));
      final initialWidth = t.getSize(slot).width;
      await t.tap(expand.hitTestable());
      await settle(t);
      expect(t.getSize(slot).width, greaterThan(initialWidth));
      expect(
        t.widget<EditableText>(editor).controller.text,
        'Draft stays with the task',
      );
      expect(w.location.query('open'), 'task:task-1');
      await t.tap(expand.hitTestable());
      await settle(t);
      expect(t.getSize(slot).width, initialWidth);
      expect(
        t.widget<EditableText>(editor).controller.text,
        'Draft stays with the task',
      );

      await t.tap(second.hitTestable());
      await settle(t);
      expect(w.location.query('open'), 'task:task-2');
      expect(title.hitTestable(), findsOneWidget);
      expect(t.widget<Text>(title).data, 'Second task title');
      expect(empty.hitTestable(), findsOneWidget);
      expect(replies, findsNothing);

      await t.tap(find.byKey(const ValueKey('task-modal-close')).hitTestable());
      await settle(t);
      expect(w.location.query('open'), isNull);
      expect(title, findsNothing);
      expect(empty, findsNothing);
      expect(second.hitTestable(), findsOneWidget);
      expect(focusIn(second), isTrue);
    } finally {
      await t.pumpWidget(const SizedBox());
      await t.pump();
    }
  });
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

  for (final escape in [false, true]) {
    testWidgets(
      'Activity: ${escape ? 'Escape' : '×'} restores task row focus',
      (t) async {
        final w = await mountTasks(t, desktop, section: 'activity');
        final row = find.byKey(const ValueKey('activity-thread-task-conv'));
        expect(row.hitTestable(), findsOneWidget);
        await t.tap(row);
        await settle(t);
        expect(w.location.route, RaftRoute.activity);
        expect(w.location.query('open'), 'task:task-1');
        expect(slot, findsOneWidget);
        expect(find.byType(SourceTaskSurface), findsOneWidget);
        final close = find.byKey(const ValueKey('task-modal-close'));
        Focus.maybeOf(t.element(close))?.requestFocus();
        await t.pump();
        expect(focusIn(slot), isTrue);
        if (escape) {
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await t.tap(close);
        }
        await settle(t);
        expect(slot, findsNothing);
        expect(w.location.query('open'), isNull);
        expect(w.location.query('task'), isNull);
        expect(focusIn(row), isTrue);
      },
    );
  }

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
