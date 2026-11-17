// The server Tasks page's board (Web v1.24 TasksBoardView): its columns and
// counts, its cards, selecting, the pointer and touch drags, the Backlog
// reason, the failures, and its paint. The keyboard drag is in
// tasks_board_keyboard_drag_test.dart.
import 'dart:async';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/tasks_page/tasks_board_view.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';
import 'package:raft_flutter/features/tasks_page/tasks_selection.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

Map<String, dynamic> boardTask(
  String id,
  int number,
  String status, {
  String? assignee,
  String? readOnlyReason,
  String? activityAt,
  int replies = 0,
}) {
  // Two hours before the clock the cards read ("2h ago"): a fixed instant
  // made the time label, and so the room left for the assignee, depend on
  // the day the test runs.
  activityAt ??= DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 2))
      .toIso8601String();
  return {
    'id': id,
    'taskNumber': number,
    'title': 'Task $id',
    'description': 'About $id',
    'status': status,
    'channelId': 'c1',
    'channelName': 'general',
    'conversationChannelId': 'conv-$id',
    'conversationReplyCount': replies,
    'createdAt': '2026-11-01T00:00:00.000Z',
    'updatedAt': activityAt,
    'activityAt': activityAt,
    'readOnlyReason': ?readOnlyReason,
    if (assignee != null) ...{
      'claimedByType': 'user',
      'claimedById': assignee,
      'claimedByName': assignee,
    },
  };
}

List<Map<String, dynamic>> defaultRows() => [
  boardTask('t1', 1, 'todo'),
  boardTask('t2', 2, 'in_progress', assignee: 'bob', replies: 3),
  boardTask('t3', 3, 'done', assignee: 'bob'),
  boardTask('t4', 4, 'todo', assignee: 'bob'),
  boardTask('t5', 5, 'closed'),
  boardTask('t6', 6, 'closed'),
  boardTask('t7', 7, 'closed'),
];

const defaultCounts = {
  'backlog': 0,
  'todo': 2,
  'in_progress': 1,
  'done': 1,
  'closed': 3,
};

/// A board over a scripted server, with the page's side of it recorded.
class BoardHarness {
  BoardHarness(this.controller, this.api, this.rows) {
    store = TasksPageStore(
      query: (path, query) async {
        reads.add({...query, 'path': path});
        return handler(path, query);
      },
      viewerId: () => 'alice',
    );
  }

  final WorkspaceController controller;
  final MessageAdapter api;
  final List<Map<String, dynamic>> rows;
  late final TasksPageStore store;
  final selection = TaskSelection();

  /// What the page reads the columns' totals from (it feeds them to the board).
  late final ValueNotifier<Map<String, int>?> counts;
  final opened = <String>[];
  final movedSelected = <String>[];
  final said = <String>[];
  static final reads = <Map<String, dynamic>>[];

  /// The server's page for a lane read (the rows of its statuses).
  dynamic Function(String path, Map<String, dynamic> query) handler = (
    path,
    query,
  ) => const {};

  Iterable<RequestOptions> writes() =>
      api.calls.where((c) => c.method != 'GET' && c.path.startsWith('/tasks/'));
}

Future<BoardHarness> mountBoard(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  List<Map<String, dynamic>>? rows,
  Map<String, int>? counts = defaultCounts,
  bool dark = false,
  RaftInteraction? interaction,
  String? currentTaskId,
  PageFilters filters = const PageFilters(),
  TargetPlatform? platform,
  Completer<void>? hold,
  Widget Function(Widget board)? wrap,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  // The test font is wider than the app's: a card's foot may overflow here
  // (the repo's task tests filter it, as task_content_slot_test does).
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!'${details.exception}'.contains('overflowed')) previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  final (controller, api) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(controller.dispose);
  final h = BoardHarness(controller, api, rows ?? defaultRows());
  addTearDown(h.store.dispose);
  addTearDown(h.selection.dispose);
  h.counts = ValueNotifier(counts);
  addTearDown(h.counts.dispose);
  BoardHarness.reads.clear();
  h.handler = (path, query) async {
    await hold?.future;
    final wanted = '${query['status']}'.split(',');
    return {
      'tasks': [
        for (final row in h.rows)
          if (wanted.contains(row['status'])) row,
      ],
      'next_cursor': null,
    };
  };
  // The server keeps what it was written.
  Map<String, dynamic> write(Map<String, dynamic> fields) => {
    'task': h.rows[0] = {...h.rows[0], ...fields},
  };
  api.routes['PATCH /tasks/t1/status'] = (o) =>
      write({'status': (o.data as Map)['status']});
  api.routes['PATCH /tasks/t1/claim'] = (_) =>
      write({'status': 'in_progress', 'claimedById': 'alice'});
  t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        h.said.add('${(message['data'] as Map)['message']}');
      }
      return null;
    },
  );
  addTearDown(
    () =>
        t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  Widget board() => TasksBoardView(
    controller: controller,
    store: h.store,
    tab: TasksPageTab.all,
    filters: filters,
    sort: ServerTaskSort.activity,
    columns: h.counts.value,
    countCurrent: true,
    selection: h.selection,
    order: () => [for (final r in h.rows) '${r['id']}'],
    currentTaskId: currentTaskId,
    onOpenTask: (task) => h.opened.add('${task['id']}'),
    onMoveSelected: h.movedSelected.add,
  );
  Widget composed() {
    var widget = board();
    if (wrap != null) widget = wrap(widget);
    if (interaction != null) {
      widget = RaftInteractionScope(interaction: interaction, child: widget);
    }
    return widget;
  }

  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark)
          .copyWith(platform: platform ?? TargetPlatform.linux),
      home: RaftToastHost(
        child: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([h.selection, h.counts]),
            builder: (_, _) => composed(),
          ),
        ),
      ),
    ),
  );
  await settle(t);
  return h;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder card(String id) => find.byKey(ValueKey('task-board-card-$id'));
Finder column(String status) => find.byKey(ValueKey('task-drop-$status'));

/// Presses on [from], moves to [to] and lets go (a mouse drag).
Future<void> dragCard(
  WidgetTester t,
  Offset from,
  Offset to, {
  PointerDeviceKind kind = PointerDeviceKind.mouse,
  Duration hold = Duration.zero,
}) async {
  final g = await t.startGesture(from, kind: kind);
  if (hold > Duration.zero) await t.pump(hold);
  await g.moveBy(const Offset(12, 0));
  await t.pump();
  await g.moveTo(to);
  await t.pump();
  await g.up();
  await settle(t);
}

Offset topOf(WidgetTester t, Finder f) =>
    t.getTopLeft(f) + const Offset(40, 20);

void main() {
  group('columns', () {
    testWidgets('a column per status with its server count, Closed folded', (
      t,
    ) async {
      final h = await mountBoard(t);
      for (final status in boardStatuses) {
        expect(column(status), findsOneWidget);
      }
      expect(
        find.descendant(of: column('todo'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: column('closed'), matching: find.text('3')),
        findsOneWidget,
      );
      // Cards of the open columns, none of the folded Closed one.
      expect(card('t1'), findsOneWidget);
      expect(card('t2'), findsOneWidget);
      expect(card('t5'), findsNothing);
      expect(
        BoardHarness.reads.where((r) => '${r['status']}' == 'closed'),
        isEmpty,
      );
      expect(h.store.collapsed, isEmpty);
    });

    testWidgets('unfolding a column never read reads its first page at once', (
      t,
    ) async {
      await mountBoard(t);
      await t.tap(find.text('Closed'));
      await settle(t);
      expect(
        BoardHarness.reads.where((r) => '${r['status']}' == 'closed'),
        hasLength(1),
      );
      expect(card('t5'), findsOneWidget);
    });

    testWidgets('a status filter shows just its columns and opens Closed', (
      t,
    ) async {
      await mountBoard(
        t,
        filters: const PageFilters(statuses: ['todo', 'closed']),
      );
      expect(column('todo'), findsOneWidget);
      expect(column('closed'), findsOneWidget);
      expect(column('done'), findsNothing);
      expect(card('t5'), findsOneWidget);
    });

    testWidgets('a count of nothing reads nothing and says so', (t) async {
      await mountBoard(t);
      expect(
        BoardHarness.reads.where((r) => '${r['status']}' == 'backlog'),
        isEmpty,
      );
      expect(
        find.descendant(
          of: column('backlog'),
          matching: find.text('No Backlog tasks'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a column shows a skeleton card until its first page lands', (
      t,
    ) async {
      final hold = Completer<void>();
      await mountBoard(t, hold: hold);
      expect(
        find.byKey(const ValueKey('task-board-card-skeleton')),
        findsNWidgets(3),
        reason: 'the open columns with something to read',
      );
      expect(find.text('No Todo tasks'), findsNothing);
      hold.complete();
      await settle(t);
      expect(
        find.byKey(const ValueKey('task-board-card-skeleton')),
        findsNothing,
      );
      expect(card('t1'), findsOneWidget);
    });

    testWidgets('narrow phone and unfolded fold keep every column', (t) async {
      for (final size in const [Size(390, 844), Size(856, 944)]) {
        await mountBoard(t, size: size);
        expect(find.byType(RaftTaskBoardColumn), findsNWidgets(5));
        expect(card('t1'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('cards', () {
    testWidgets('a card shows its replies, assignee, Unassigned and time', (
      t,
    ) async {
      await mountBoard(t);
      expect(
        find.descendant(of: card('t2'), matching: find.text('3')),
        findsOneWidget,
        reason: 'reply count after the title',
      );
      expect(
        find.descendant(of: card('t1'), matching: find.text('Unassigned')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card('t4'), matching: find.text('bob')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card('t1'),
          matching: find.byKey(const ValueKey('tasks-page-activity-time')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a task nobody updated for three days is stale', (t) async {
      final old = DateTime.now()
          .subtract(const Duration(days: 4))
          .toUtc()
          .toIso8601String();
      await mountBoard(t, rows: [boardTask('t1', 1, 'todo', activityAt: old)]);
      expect(
        find.descendant(
          of: card('t1'),
          matching: find.byKey(
            const ValueKey('tasks-page-activity-time-stale'),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('4d ago'), findsOneWidget);
    });

    testWidgets('a click opens the task, a modified click selects', (t) async {
      final h = await mountBoard(t);
      await t.tap(card('t1'));
      await settle(t);
      expect(h.opened, ['t1']);
      expect(h.selection.selected, isEmpty);

      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.tap(card('t2'));
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(t);
      expect(h.selection.selected, {'t2'});
      expect(h.opened, ['t1']);
    });

    testWidgets('Shift-click picks the run, a click while selecting picks', (
      t,
    ) async {
      final h = await mountBoard(t);
      h.selection.select('t1');
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.tap(card('t4'));
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(t);
      // The order is t1..t5: the run from t1 to t4.
      expect(h.selection.selected, {'t1', 't2', 't3', 't4'});

      await t.tap(card('t3'));
      await settle(t);
      expect(h.selection.selected, {'t1', 't2', 't4'});
      expect(h.opened, isEmpty);
    });

    testWidgets(
      'selected and current cards paint as Web does, light and dark',
      (t) async {
        for (final dark in [false, true]) {
          final h = await mountBoard(t, dark: dark, currentTaskId: 't2');
          h.selection.select('t1');
          await settle(t);
          final tokens = RaftTokens.of(t.element(card('t1')));
          BoxDecoration surface(String id) =>
              (t
                      .widget<Container>(
                        find.descendant(
                          of: card(id),
                          matching: find.byKey(
                            const ValueKey('task-card-surface'),
                          ),
                        ),
                      )
                      .decoration!
                  as BoxDecoration);
          expect(surface('t1').color, tokens.colors['fill-cell-selected']);
          expect(surface('t2').color, tokens.colors['fill-cell-selected']);
          expect(
            surface('t4').color,
            isNot(tokens.colors['fill-cell-selected']),
          );
          final ring = t.widget<DecoratedBox>(
            find.descendant(
              of: card('t1'),
              matching: find.byKey(const ValueKey('task-card-selected-ring')),
            ),
          );
          final border = (ring.decoration as BoxDecoration).border! as Border;
          expect(border.top.width, 2);
          expect(border.top.color, tokens.colors['info']);
          // Only a selected card is ringed.
          expect(
            find.descendant(
              of: card('t2'),
              matching: find.byKey(const ValueKey('task-card-selected-ring')),
            ),
            findsNothing,
          );
          await t.pumpWidget(const SizedBox());
        }
      },
    );
  });

  group('pointer drag', () {
    testWidgets('a drop on another column sends the status and applies it', (
      t,
    ) async {
      final h = await mountBoard(t);
      await dragCard(t, topOf(t, card('t1')), t.getCenter(column('done')));
      final write = h.writes().single;
      expect('${write.method} ${write.path}', 'PATCH /tasks/t1/status');
      expect(write.data, {'status': 'done'});
      expect(h.store.knownById['t1']!['status'], 'done');
      expect(h.said.last, 'Task #1 moved to Done');
    });

    testWidgets('an unassigned todo task dropped on In progress is the claim', (
      t,
    ) async {
      final h = await mountBoard(t);
      await dragCard(
        t,
        topOf(t, card('t1')),
        t.getCenter(column('in_progress')),
      );
      final write = h.writes().single;
      expect('${write.method} ${write.path}', 'PATCH /tasks/t1/claim');
      expect(write.data, isNull);
      expect(h.said.last, 'Task #1 moved to In progress');
    });

    testWidgets('a drop in its own column sends nothing', (t) async {
      final h = await mountBoard(t);
      await dragCard(t, topOf(t, card('t1')), t.getCenter(column('todo')));
      expect(h.writes(), isEmpty);
      expect(h.movedSelected, isEmpty);
    });

    testWidgets('the card leaves its column while its copy follows: no ghost, '
        'no gap, no placeholder in the target (Web visibleTasks)', (t) async {
      await mountBoard(t);
      final first = topOf(t, card('t1'));
      final target = topOf(t, card('t3'));
      final g = await t.startGesture(
        topOf(t, card('t1')),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(12, 0));
      await t.pump();
      await g.moveTo(t.getCenter(column('done')));
      await t.pump();
      // The lifted copy is the only card showing it; nothing is left at 40%.
      expect(find.text('Task t1'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == .4),
        findsNothing,
      );
      expect(card('t1'), findsNothing);
      // The card under it took its place in the column (no gap left by the
      // card, none between them).
      expect(topOf(t, card('t4')), first);
      // The target column opens no gap for the card.
      expect(topOf(t, card('t3')), target);
      // The copy floats with the shadow of a lifted card (`shadow-float`).
      final lifted = find.ancestor(
        of: find.text('Task t1'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              ((w.decoration as BoxDecoration).boxShadow?.isNotEmpty ?? false),
        ),
      );
      expect(lifted, findsWidgets);
      await g.up();
      await settle(t);
      expect(card('t1'), findsOneWidget);
    });

    testWidgets('a selected card dropped while several are selected moves '
        'them through the page and sends nothing itself', (t) async {
      final h = await mountBoard(t);
      h.selection.setAll(['t1', 't4']);
      await settle(t);
      await dragCard(t, topOf(t, card('t1')), t.getCenter(column('done')));
      expect(h.movedSelected, ['done']);
      expect(h.writes(), isEmpty);
    });

    testWidgets('a card not selected moves alone while others are', (t) async {
      final h = await mountBoard(t);
      h.selection.setAll(['t2', 't4']);
      await settle(t);
      await dragCard(t, topOf(t, card('t1')), t.getCenter(column('done')));
      expect(h.movedSelected, isEmpty);
      expect(h.writes().single.path, '/tasks/t1/status');
    });

    testWidgets('a read-only task is refused with its reason', (t) async {
      final h = await mountBoard(
        t,
        rows: [
          boardTask('t1', 1, 'todo', readOnlyReason: 'historical_joint'),
          boardTask('t2', 2, 'done'),
        ],
      );
      final g = await t.startGesture(
        topOf(t, card('t1')),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(12, 0));
      await t.pump();
      await g.moveTo(t.getCenter(column('backlog')));
      await t.pump();
      expect(
        find.text(
          'This task was created before other servers connected. Only the host server can change it.',
        ),
        findsOneWidget,
      );
      await g.up();
      await settle(t);
      expect(h.writes(), isEmpty);
    });

    testWidgets('a column the task has no way to is blocked with why', (
      t,
    ) async {
      // A pre-v2 task (legacy) has no Backlog.
      final legacy = {...boardTask('t1', 1, 'todo'), 'isLegacy': true};
      final h = await mountBoard(t, rows: [legacy]);
      final g = await t.startGesture(
        topOf(t, card('t1')),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(12, 0));
      await t.pump();
      await g.moveTo(t.getCenter(column('backlog')));
      await t.pump();
      expect(find.text("Can't move from Todo to Backlog"), findsOneWidget);
      await g.up();
      await settle(t);
      expect(h.writes(), isEmpty);
    });

    testWidgets('a failed move says so in a toast and leaves the card', (
      t,
    ) async {
      final h = await mountBoard(t);
      h.api.routes.remove('PATCH /tasks/t1/status');
      await dragCard(t, topOf(t, card('t1')), t.getCenter(column('done')));
      expect(h.writes(), hasLength(1));
      expect(find.text("Couldn't move the task. Try again."), findsOneWidget);
      expect(h.store.knownById['t1']!['status'], 'todo');
      expect(h.said, isEmpty, reason: 'no "moved" for a move that failed');
    });
  });

  group('drop states paint', () {
    testWidgets('an allowed folded column is outlined, a blocked one says why '
        'in the muted ink, light and dark', (t) async {
      for (final dark in [false, true]) {
        await mountBoard(
          t,
          dark: dark,
          rows: [
            boardTask('t1', 1, 'todo'),
            boardTask('t2', 2, 'todo', readOnlyReason: 'historical_joint'),
          ],
        );
        final tokens = RaftTokens.of(t.element(card('t1')));
        // Over the folded Closed column: allowed, so its outline shows.
        final g = await t.startGesture(
          topOf(t, card('t1')),
          kind: PointerDeviceKind.mouse,
        );
        await g.moveBy(const Offset(12, 0));
        await t.pump();
        await g.moveTo(t.getCenter(column('closed')));
        await t.pump();
        final closed = find.descendant(
          of: column('closed'),
          matching: find.byType(RaftTaskBoardColumn),
        );
        expect(t.widget<RaftTaskBoardColumn>(closed).dropActive, isTrue);
        expect(
          find.descendant(
            of: column('closed'),
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.foregroundPainter != null,
            ),
          ),
          findsOneWidget,
          reason: 'the dashed outline of a folded column a card may drop on',
        );
        await g.up();
        await settle(t);

        // A read-only card over the empty Backlog: blocked, with its reason.
        final blocked = await t.startGesture(
          topOf(t, card('t2')),
          kind: PointerDeviceKind.mouse,
        );
        await blocked.moveBy(const Offset(12, 0));
        await t.pump();
        await blocked.moveTo(t.getCenter(column('backlog')));
        await t.pump();
        final reason = t.widget<Text>(
          find.descendant(
            of: column('backlog'),
            matching: find.textContaining('created before other servers'),
          ),
        );
        expect(reason.style?.color, tokens.ui.foregroundMuted);
        expect(
          t
              .widget<RaftTaskBoardColumn>(
                find.descendant(
                  of: column('backlog'),
                  matching: find.byType(RaftTaskBoardColumn),
                ),
              )
              .dropActive,
          isFalse,
        );
        await blocked.up();
        await settle(t);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('the Backlog reason', () {
    testWidgets('a drop on Backlog asks first, from the column heading', (
      t,
    ) async {
      final h = await mountBoard(t);
      await dragCard(t, topOf(t, card('t1')), t.getCenter(column('backlog')));
      expect(h.writes(), isEmpty);
      final popover = find.byKey(const ValueKey('task-backlog-reason'));
      expect(popover, findsOneWidget);
      // Hung from the Backlog heading.
      final heading = t.getRect(find.text('Backlog').first);
      expect(
        t.getTopLeft(popover).dy,
        greaterThan(heading.bottom),
        reason: 'under the heading',
      );
      await t.enterText(
        find.byKey(const ValueKey('task-backlog-reason-input')),
        'later',
      );
      await t.tap(find.byKey(const ValueKey('task-backlog-reason-confirm')));
      await settle(t);
      final write = h.writes().single;
      expect(write.path, '/tasks/t1/status');
      expect(write.data, {'status': 'backlog', 'reason': 'later'});
      expect(popover, findsNothing);
      expect(h.said.last, 'Task #1 moved to Backlog');
    });

    testWidgets('Cancel leaves the card where it was and sends nothing', (
      t,
    ) async {
      final h = await mountBoard(t);
      await dragCard(t, topOf(t, card('t1')), t.getCenter(column('backlog')));
      await t.tap(find.byKey(const ValueKey('task-backlog-reason-cancel')));
      await settle(t);
      expect(h.writes(), isEmpty);
      expect(find.byKey(const ValueKey('task-backlog-reason')), findsNothing);
      expect(h.store.knownById['t1']!['status'], 'todo');
    });

    testWidgets('a refused move shows under the field and stays open', (
      t,
    ) async {
      final h = await mountBoard(t);
      h.api.routes.remove('PATCH /tasks/t1/status');
      await dragCard(t, topOf(t, card('t1')), t.getCenter(column('backlog')));
      await t.tap(find.byKey(const ValueKey('task-backlog-reason-confirm')));
      await settle(t);
      expect(h.writes(), hasLength(1));
      expect(
        find.byKey(const ValueKey('task-backlog-reason-error')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('task-backlog-reason')), findsOneWidget);
    });

    testWidgets('the status chip asks the same, from the card', (t) async {
      final h = await mountBoard(t);
      await t.tap(find.descendant(of: card('t1'), matching: find.text('Todo')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('backlog')).last);
      await settle(t);
      expect(find.byKey(const ValueKey('task-backlog-reason')), findsOneWidget);
      expect(h.writes(), isEmpty);
    });
  });

  group('the status chip', () {
    testWidgets('moves in place, and a todo task nobody holds is the claim', (
      t,
    ) async {
      final h = await mountBoard(t);
      await t.tap(find.descendant(of: card('t1'), matching: find.text('Todo')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('in_progress')).last);
      await settle(t);
      expect(h.writes().single.path, '/tasks/t1/claim');
    });

    testWidgets('a read-only task has no chip menu', (t) async {
      await mountBoard(
        t,
        rows: [boardTask('t1', 1, 'todo', readOnlyReason: 'historical_joint')],
      );
      expect(
        find.descendant(
          of: card('t1'),
          matching: find.byType(RaftTaskStatusEditor),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: card('t1'), matching: find.byType(RaftTaskStatus)),
        findsOneWidget,
      );
    });
  });

  group('paging', () {
    testWidgets('the column end reads the next page, a failure waits for a '
        'press', (t) async {
      final many = [
        for (var i = 1; i <= 25; i++)
          boardTask(
            'p$i',
            i,
            'todo',
            activityAt: '2026-11-17T10:${59 - i}:00Z',
          ),
      ];
      final h = await mountBoard(
        t,
        rows: many,
        counts: {...defaultCounts, 'todo': 25},
        size: const Size(1280, 6000),
      );
      var fail = true;
      h.handler = (path, query) {
        if (query['cursor'] == null) {
          return {'tasks': many.take(20).toList(), 'next_cursor': 'c2'};
        }
        if (fail) throw StateError('offline');
        return {'tasks': many.skip(20).toList(), 'next_cursor': null};
      };
      h.store.reset();
      await settle(t);
      final reads = BoardHarness.reads.where((r) => r['cursor'] != null);
      expect(reads, hasLength(1), reason: 'one read of the next page');
      expect(find.byKey(const ValueKey('task-load-more-todo')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(card('p25'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('touch', () {
    testWidgets('on a fold a long press lifts a card and a drop moves it', (
      t,
    ) async {
      final h = await mountBoard(
        t,
        size: const Size(856, 944),
        interaction: RaftInteraction.touchMode,
        platform: TargetPlatform.android,
      );
      final g = await t.startGesture(
        topOf(t, card('t1')),
        kind: PointerDeviceKind.touch,
      );
      await t.pump(const Duration(milliseconds: 600));
      await g.moveBy(const Offset(0, 8));
      await t.pump();
      await g.moveTo(t.getCenter(column('in_progress')));
      await t.pump();
      await g.up();
      await settle(t);
      expect(h.writes().single.path, '/tasks/t1/claim');
    });

    testWidgets('a press that moves at once scrolls the board, not the card', (
      t,
    ) async {
      final h = await mountBoard(
        t,
        size: const Size(390, 844),
        interaction: RaftInteraction.touchMode,
        platform: TargetPlatform.android,
      );
      final g = await t.startGesture(
        topOf(t, card('t1')),
        kind: PointerDeviceKind.touch,
      );
      await g.moveBy(const Offset(-80, 0));
      await t.pump();
      await g.up();
      await settle(t);
      expect(h.writes(), isEmpty);
      expect(card('t1'), findsOneWidget);
    });

    testWidgets('on a phone a long press drag to Backlog asks the reason', (
      t,
    ) async {
      final h = await mountBoard(
        t,
        size: const Size(390, 844),
        interaction: RaftInteraction.touchMode,
        platform: TargetPlatform.android,
      );
      final g = await t.startGesture(
        topOf(t, card('t4')),
        kind: PointerDeviceKind.touch,
      );
      await t.pump(const Duration(milliseconds: 600));
      await g.moveBy(const Offset(-4, 4));
      await t.pump();
      await g.moveTo(t.getCenter(column('backlog')));
      await t.pump();
      await g.up();
      await settle(t);
      expect(find.byKey(const ValueKey('task-backlog-reason')), findsOneWidget);
      expect(h.writes(), isEmpty);
    });

    testWidgets('a quick touch on a card opens it, and drags nothing', (
      t,
    ) async {
      final h = await mountBoard(
        t,
        interaction: RaftInteraction.touchMode,
        platform: TargetPlatform.android,
      );
      await t.tap(card('t1'));
      await settle(t);
      expect(h.opened, ['t1']);
      expect(h.writes(), isEmpty);
    });
  });

  group('autoscroll', () {
    testWidgets('a drag held at the board edge scrolls it on a phone', (
      t,
    ) async {
      await mountBoard(t, size: const Size(390, 844));
      final position = Scrollable.of(
        t.element(find.byKey(const ValueKey('tasks-page-board'))),
        axis: Axis.horizontal,
      ).position;
      final before = position.pixels;
      final g = await t.startGesture(
        topOf(t, card('t4')),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(12, 0));
      await t.pump();
      await g.moveTo(const Offset(384, 300));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await g.up();
      await settle(t);
      expect(position.pixels, greaterThan(before));
    });
  });
}
