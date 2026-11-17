// The board's keyboard drag (raft-ui task-dnd `taskKeyboardCoordinates` with
// dnd-kit's keyboard sensor, Web useTaskBoardDrag): Space picks a card up,
// Left / Right move the target to the nearest column, Space drops, Escape
// puts it back; announcements, and focus back on the card.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/tasks_page/task_board_keyboard_drag.dart';
import 'package:raft_flutter/features/tasks_page/tasks_board_view.dart';

import 'tasks_board_view_test.dart' show boardTask, column, mountBoard, settle;

FocusNode cardNode(WidgetTester t, String id) => Focus.of(
  t.element(
    find
        .descendant(
          of: find.byKey(ValueKey('task-board-focus-$id')),
          matching: find.byType(Semantics),
        )
        .first,
  ),
);

Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await settle(t);
}

/// Focuses card [id] the way Tab would.
Future<FocusNode> focusCard(WidgetTester t, String id) async {
  final node = cardNode(t, id)..requestFocus();
  await t.pump();
  expect(node.hasPrimaryFocus, isTrue);
  return node;
}

bool focusIsIn(WidgetTester t, String status, String id) {
  final node = FocusManager.instance.primaryFocus;
  if (node == null || node != cardNode(t, id)) return false;
  return find
      .descendant(
        of: column(status),
        matching: find.byKey(ValueKey('task-board-focus-$id')),
      )
      .evaluate()
      .isNotEmpty;
}

void main() {
  group('columns by keyboard', () {
    const centers = {'backlog': 100.0, 'todo': 350.0, 'done': 600.0};

    test('the nearest column that way, none past the end', () {
      expect(nearestColumn(centers, 'todo', 1), 'done');
      expect(nearestColumn(centers, 'todo', -1), 'backlog');
      expect(nearestColumn(centers, 'done', 1), isNull);
      expect(nearestColumn(centers, 'backlog', -1), isNull);
      expect(nearestColumn(centers, 'nowhere', 1), isNull);
    });

    test('skips the columns on the way when the nearer is the same spot', () {
      expect(
        nearestColumn({'a': 0, 'b': 0.5, 'c': 200}, 'a', 1),
        'c',
        reason: 'a column within a pixel is not that way',
      );
    });
  });

  group('the keyboard drag', () {
    late TaskBoardKeyboardDrag drag;
    late List<String> events;
    var positions = <String, double>{};

    KeyEvent down(LogicalKeyboardKey k) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: k,
      timeStamp: Duration.zero,
    );

    setUp(() {
      events = [];
      positions = {'a': 0, 'b': 100, 'c': 200};
      drag = TaskBoardKeyboardDrag(
        centers: () => positions,
        onPickUp: (id, s) => events.add('up $id $s'),
        onOver: (id, s) => events.add('over $id $s'),
        onDrop: (id, s) => events.add('drop $id $s'),
        onCancel: (id) => events.add('cancel $id'),
      );
      addTearDown(drag.dispose);
    });

    test('Space picks up and drops, Enter never picks up', () {
      expect(
        drag.handle('t1', 'b', down(LogicalKeyboardKey.enter)),
        KeyEventResult.ignored,
      );
      expect(drag.active, isFalse);
      expect(
        drag.handle('t1', 'b', down(LogicalKeyboardKey.space)),
        KeyEventResult.handled,
      );
      expect(drag.taskId, 't1');
      expect(drag.over, 'b');
      expect(
        drag.handle('t1', 'b', down(LogicalKeyboardKey.space)),
        KeyEventResult.handled,
      );
      expect(drag.active, isFalse);
      expect(events, ['up t1 b', 'drop t1 b']);
    });

    test(
      'the arrows move the target, Up and Down are taken and go nowhere',
      () {
        drag.handle('t1', 'b', down(LogicalKeyboardKey.space));
        drag.handle('t1', 'b', down(LogicalKeyboardKey.arrowRight));
        expect(drag.over, 'c');
        drag.handle('t1', 'b', down(LogicalKeyboardKey.arrowRight));
        expect(drag.over, 'c', reason: 'no column further right');
        expect(
          drag.handle('t1', 'b', down(LogicalKeyboardKey.arrowDown)),
          KeyEventResult.handled,
        );
        expect(
          drag.handle('t1', 'b', down(LogicalKeyboardKey.arrowUp)),
          KeyEventResult.handled,
        );
        expect(drag.over, 'c');
        drag.handle('t1', 'b', down(LogicalKeyboardKey.arrowLeft));
        drag.handle('t1', 'b', down(LogicalKeyboardKey.arrowLeft));
        expect(drag.over, 'a');
        expect(
          drag.handle('t1', 'b', down(LogicalKeyboardKey.enter)),
          KeyEventResult.handled,
          reason: 'taken, so it does not open the card under the drag',
        );
        expect(drag.active, isTrue, reason: 'raft-ui drops on Space only');
        drag.handle('t1', 'b', down(LogicalKeyboardKey.space));
        expect(events.last, 'drop t1 a');
      },
    );

    test('Escape puts it back and takes the key only while dragging', () {
      expect(
        drag.handle('t1', 'b', down(LogicalKeyboardKey.escape)),
        KeyEventResult.ignored,
      );
      drag.handle('t1', 'b', down(LogicalKeyboardKey.space));
      expect(
        drag.handle('t1', 'b', down(LogicalKeyboardKey.escape)),
        KeyEventResult.handled,
      );
      expect(drag.active, isFalse);
      expect(events, ['up t1 b', 'cancel t1']);
    });

    test('another card hears nothing while one is dragged', () {
      drag.handle('t1', 'b', down(LogicalKeyboardKey.space));
      expect(
        drag.handle('t2', 'a', down(LogicalKeyboardKey.space)),
        KeyEventResult.ignored,
      );
      expect(drag.taskId, 't1');
    });

    test('a drag ended from outside cancels', () {
      drag.handle('t1', 'b', down(LogicalKeyboardKey.space));
      drag.cancel();
      drag.cancel();
      expect(events, ['up t1 b', 'cancel t1']);
    });
  });

  group('on the board', () {
    testWidgets('Space, Right, Space moves the card and says so; focus follows '
        'it to its column', (t) async {
      final h = await mountBoard(t);
      await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.space);
      expect(h.said.last, 'Picked up task #1. Over Todo.');
      await key(t, LogicalKeyboardKey.arrowRight);
      expect(h.said.last, 'Over In progress.');
      // The column it is over shows it takes the card.
      await key(t, LogicalKeyboardKey.space);
      expect(h.said, contains('Dropped task #1 in In progress.'));
      final write = h.writes().single;
      expect(write.path, '/tasks/t1/claim', reason: 'an unassigned todo task');
      expect(h.said.last, 'Task #1 moved to In progress');
      expect(focusIsIn(t, 'in_progress', 't1'), isTrue);
    });

    testWidgets('Escape puts it back, and no one else hears it', (t) async {
      var escapes = 0;
      final h = await mountBoard(
        t,
        wrap: (board) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => escapes++,
          },
          child: board,
        ),
      );
      final node = await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.space);
      await key(t, LogicalKeyboardKey.arrowRight);
      await key(t, LogicalKeyboardKey.escape);
      expect(
        escapes,
        0,
        reason: 'a task open, a selection: Escape is the drag\'s',
      );
      expect(h.said.last, 'Cancelled. Task #1 is back in Todo.');
      expect(h.writes(), isEmpty);
      expect(node.hasPrimaryFocus, isTrue);
      // Once the drag is over Escape reaches the app again.
      await key(t, LogicalKeyboardKey.escape);
      expect(escapes, 1);
    });

    testWidgets('over a column the task cannot go to it says why, and a drop '
        'goes back', (t) async {
      final h = await mountBoard(
        t,
        rows: [
          boardTask('t1', 1, 'todo', readOnlyReason: 'historical_joint'),
          boardTask('t2', 2, 'done'),
        ],
      );
      await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.space);
      await key(t, LogicalKeyboardKey.arrowRight);
      expect(
        h.said.last,
        "Task #1 can't go to In progress. This task was created before other "
        'servers connected. Only the host server can change it.',
      );
      expect(
        find.text(
          'This task was created before other servers connected. Only the host server can change it.',
        ),
        findsOneWidget,
        reason: 'the empty column says it too',
      );
      await key(t, LogicalKeyboardKey.space);
      expect(
        h.said.last,
        'This task was created before other servers connected. Only the host '
        'server can change it. Cancelled. Task #1 is back in Todo.',
      );
      expect(h.writes(), isEmpty);
      expect(focusIsIn(t, 'todo', 't1'), isTrue);
    });

    testWidgets('a drop where it started sends nothing', (t) async {
      final h = await mountBoard(t);
      await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.space);
      await key(t, LogicalKeyboardKey.space);
      expect(h.said.last, 'Dropped task #1 in Todo.');
      expect(h.writes(), isEmpty);
      expect(focusIsIn(t, 'todo', 't1'), isTrue);
    });

    testWidgets('a drop on Backlog asks first: Cancel gives focus back, '
        'Move writes and focus follows', (t) async {
      final h = await mountBoard(t);
      await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.space);
      await key(t, LogicalKeyboardKey.arrowLeft);
      await key(t, LogicalKeyboardKey.space);
      expect(find.byKey(const ValueKey('task-backlog-reason')), findsOneWidget);
      expect(h.writes(), isEmpty);
      await t.tap(find.byKey(const ValueKey('task-backlog-reason-cancel')));
      await settle(t);
      expect(h.writes(), isEmpty);
      expect(focusIsIn(t, 'todo', 't1'), isTrue);

      await key(t, LogicalKeyboardKey.space);
      await key(t, LogicalKeyboardKey.arrowLeft);
      await key(t, LogicalKeyboardKey.space);
      await t.tap(find.byKey(const ValueKey('task-backlog-reason-confirm')));
      // The page reads the totals again after a task changes.
      h.counts.value = {...h.counts.value!, 'backlog': 1, 'todo': 1};
      await settle(t);
      expect(h.writes().single.data, {'status': 'backlog'});
      expect(h.said.last, 'Task #1 moved to Backlog');
      expect(focusIsIn(t, 'backlog', 't1'), isTrue);
    });

    testWidgets('a selected card dropped while several are selected moves '
        'them through the page', (t) async {
      final h = await mountBoard(t);
      h.selection.setAll(['t1', 't4']);
      await settle(t);
      await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.space);
      await key(t, LogicalKeyboardKey.arrowRight);
      await key(t, LogicalKeyboardKey.arrowRight);
      await key(t, LogicalKeyboardKey.space);
      expect(h.movedSelected, ['done']);
      expect(h.writes(), isEmpty);
      expect(focusIsIn(t, 'todo', 't1'), isTrue);
    });

    testWidgets('a refused move toasts and focus stays on the card', (t) async {
      final h = await mountBoard(t);
      h.api.routes.remove('PATCH /tasks/t1/status');
      await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.space);
      await key(t, LogicalKeyboardKey.arrowRight);
      await key(t, LogicalKeyboardKey.arrowRight);
      await key(t, LogicalKeyboardKey.space);
      expect(h.writes(), hasLength(1));
      expect(find.text("Couldn't move the task. Try again."), findsOneWidget);
      expect(focusIsIn(t, 'todo', 't1'), isTrue);
    });

    testWidgets('Space on a card\'s own open button does not pick it up', (
      t,
    ) async {
      final h = await mountBoard(t);
      await focusCard(t, 't1');
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(cardNode(t, 't1').hasPrimaryFocus, isFalse);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(t);
      expect(h.said, isEmpty);
      expect(h.opened, ['t1'], reason: 'it opens the task, as a button');
    });

    testWidgets('Enter on the card does not pick it up', (t) async {
      final h = await mountBoard(t);
      await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.enter);
      expect(h.said, isEmpty);
    });

    testWidgets('the card tells a screen reader how to drag it', (t) async {
      await mountBoard(t);
      final hints = find
          .descendant(
            of: find.byKey(const ValueKey('task-board-focus-t1')),
            matching: find.byType(Semantics),
          )
          .evaluate()
          .map((e) => (e.widget as Semantics).properties.hint)
          .whereType<String>();
      expect(
        hints.first,
        'To pick up an item, press Space. Use the arrow keys to move it, Space '
        'to drop it, Escape to cancel.',
      );
    });

    testWidgets('the target column scrolls into view on a phone and a fold', (
      t,
    ) async {
      for (final size in const [Size(390, 844), Size(856, 944)]) {
        final h = await mountBoard(t, size: size);
        await focusCard(t, 't1');
        await key(t, LogicalKeyboardKey.space);
        for (var i = 0; i < 2; i++) {
          await key(t, LogicalKeyboardKey.arrowRight);
        }
        final rect = t.getRect(column('done'));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(h.said.last, 'Over Done.');
        await key(t, LogicalKeyboardKey.escape);
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a drag ends when focus leaves its card', (t) async {
      final h = await mountBoard(t);
      await focusCard(t, 't1');
      await key(t, LogicalKeyboardKey.space);
      cardNode(t, 't2').requestFocus();
      await settle(t);
      expect(h.said.last, 'Cancelled. Task #1 is back in Todo.');
      // The next arrow moves nothing: no drag is on.
      await key(t, LogicalKeyboardKey.arrowRight);
      expect(h.said.last, 'Cancelled. Task #1 is back in Todo.');
    });

    testWidgets('pointer and keyboard agree: allowed statuses', (t) async {
      expect(allowedDropStatuses(boardTask('x', 1, 'todo')), contains('done'));
      expect(
        allowedDropStatuses(
          boardTask('x', 1, 'todo', readOnlyReason: 'historical_joint'),
        ),
        isEmpty,
      );
      // v2 retires In review (a task in it keeps it).
      expect(
        allowedDropStatuses(boardTask('x', 1, 'todo')),
        isNot(contains('in_review')),
      );
      expect(
        allowedDropStatuses(boardTask('x', 1, 'in_review')),
        contains('in_review'),
      );
      expect(
        allowedDropStatuses({...boardTask('x', 1, 'todo'), 'isLegacy': true}),
        isNot(contains('backlog')),
      );
    });
  });
}
