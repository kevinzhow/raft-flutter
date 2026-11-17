// The Tasks page's selection and its bar (Web v1.24 TasksSelectionBar): how
// tasks are picked, and what each action sends, per task, with a few in
// flight; the toasts say what was done and skipped, and what the server
// refused stays selected. Each hint is shown to resolve.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/tasks_page_harness.dart';

/// [count] open tasks assigned to me, newest first (`m01` is the newest).
List<Map<String, dynamic>> mine(int count, {String status = 'todo'}) => [
  for (var i = 1; i <= count; i++)
    pageTask(
      'm${i.toString().padLeft(2, '0')}',
      number: i,
      status: status,
      claimedBy: meId,
      activityAt: DateTime.utc(2026, 11, 17, 10, 60 - i).toIso8601String(),
    ),
];

Finder row(String id) => find.byKey(Key('tasks-page-row-open-$id'));
Finder box(String id) => find.byKey(Key('tasks-page-row-select-$id'));
Finder bar = find.byKey(const Key('tasks-page-selection-bar'));
Finder count(int n) => find.descendant(
  of: find.byKey(const Key('selection-bar')),
  matching: find.textContaining('$n'),
);

Future<void> tapWith(
  WidgetTester t,
  Finder target,
  LogicalKeyboardKey key,
) async {
  await t.sendKeyDownEvent(key);
  await t.tap(target);
  await t.sendKeyUpEvent(key);
  await settleTasks(t, rounds: 2);
}

Future<void> selectAll(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(LogicalKeyboardKey.keyA);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await settleTasks(t);
}

List<String> writes(TasksServer s, String method, String suffix) => [
  for (final r in s.requests)
    if (r.method == method && r.path.endsWith(suffix)) r.path,
];

Future<void> pickStatus(WidgetTester t, String label) async {
  await t.tap(find.byKey(const Key('selection-bar-action-status')));
  await settleTasks(t, rounds: 3);
  await t.tap(find.text(label).last);
  await settleTasks(t, rounds: 2);
}

void main() {
  group('picking', () {
    testWidgets('Ctrl-click toggles, Shift-click adds the run from the last '
        'pick, any tap while selecting toggles instead of opening', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(6))))!;
      addTearDown(w.dispose);
      final opened = await mountPage(t, w);
      expect(bar, findsNothing);
      await tapWith(t, row('m02'), LogicalKeyboardKey.controlLeft);
      expect(bar, findsOneWidget);
      expect(count(1), findsOneWidget);
      await tapWith(t, row('m05'), LogicalKeyboardKey.shiftLeft);
      // m02 to m05, on screen order.
      expect(count(4), findsOneWidget);
      // A plain tap while selecting toggles (m03 leaves) and opens nothing.
      await t.tap(row('m03'));
      await settleTasks(t, rounds: 2);
      expect(count(3), findsOneWidget);
      expect(opened, isEmpty);
      // The box of a row is a toggle too.
      await t.tap(box('m06'), warnIfMissed: false);
      await settleTasks(t, rounds: 2);
      expect(count(4), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Escape ends the selection, and so does the bar\'s x', (
      t,
    ) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(3))))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await tapWith(t, row('m01'), LogicalKeyboardKey.controlLeft);
      expect(bar, findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleTasks(t, rounds: 2);
      expect(bar, findsNothing);
      await tapWith(t, row('m01'), LogicalKeyboardKey.controlLeft);
      await t.tap(find.byKey(const Key('selection-bar-clear')));
      await settleTasks(t, rounds: 2);
      expect(bar, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Escape and Ctrl+A are a field\'s while the search has '
        'focus', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(3))))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await tapWith(t, row('m01'), LogicalKeyboardKey.controlLeft);
      await t.tap(find.byKey(const ValueKey('tasks-page-search')));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleTasks(t, rounds: 2);
      expect(bar, findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Ctrl+A selects everything under the filters, read to its '
        'end', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(120)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      // Only the first pages are on screen; the rest are read for Select all.
      expect(row('m100'), findsNothing);
      await selectAll(t);
      expect(count(120), findsOneWidget);
      final bigReads = server.taskReads.where(
        (r) => r.queryParameters['limit'] == '500',
      );
      expect(bigReads, isNotEmpty);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Select all past 2000 stops there and says so', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(2100))))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      // The toast lasts a few seconds: look for it as the read ends.
      for (var i = 0; i < 600; i++) {
        await settleTasks(t, rounds: 1);
        if (find.textContaining('Selected the first').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text('Selected the first 2,000 tasks'), findsOneWidget);
      expect(count(2000), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Select all cut short by a failed read says what it got', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(30)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      server.routes['GET /tasks/server'] = (o) =>
          o.queryParameters['limit'] == '500'
          ? (500, {'error': 'down'})
          : server.answer(o);
      server.routes.remove('x');
      await selectAll(t);
      // What was on screen stays selected, and the toast says the rest
      // could not be read.
      expect(find.textContaining("the rest couldn't be read"), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a change of sort, view or filter ends the selection', (
      t,
    ) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(3))))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await tapWith(t, row('m01'), LogicalKeyboardKey.controlLeft);
      expect(bar, findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tasks-page-sort')));
      await settleTasks(t, rounds: 3);
      await t.tap(find.text('Least recently updated').last);
      await settleTasks(t);
      expect(bar, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a long press by touch selects (a fold, 856x944)', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(3))))!;
      addTearDown(w.dispose);
      await mountPage(
        t,
        w,
        size: const Size(856, 944),
        platform: TargetPlatform.android,
      );
      await t.longPress(row('m02'));
      await settleTasks(t, rounds: 2);
      expect(bar, findsOneWidget);
      expect(count(1), findsOneWidget);
      // Now a tap toggles.
      await t.tap(row('m03'));
      await settleTasks(t, rounds: 2);
      expect(count(2), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a narrow desktop window (390x844, a mouse) selects with '
        'Ctrl-click', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(3))))!;
      addTearDown(w.dispose);
      await mountPage(t, w, size: const Size(390, 844));
      await tapWith(t, row('m02'), LogicalKeyboardKey.controlLeft);
      expect(bar, findsOneWidget);
      expect(count(1), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('actions', () {
    testWidgets('moving ten tasks: ten per-task status requests, four in '
        'flight at most, one toast, the selection gone', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(10)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      expect(count(10), findsOneWidget);
      final gate = server.gate = Completer<void>();
      await pickStatus(t, 'Done');
      await settleTasks(t);
      // Four started, the rest waiting for a place.
      expect(writes(server, 'PATCH', '/status').length, 4);
      expect(server.inFlight, 4);
      gate.complete();
      await settleTasks(t, rounds: 12);
      final patches = writes(server, 'PATCH', '/status');
      expect(patches.length, 10);
      expect(patches.toSet().length, 10);
      expect(server.maxInFlight, 4);
      for (final r in server.requests.where(
        (r) => r.path.endsWith('/status'),
      )) {
        expect(r.data, {'status': 'done'});
      }
      // Never the bulk PATCH /tasks/:id, never /claim.
      expect(server.requests.where((r) => r.path.endsWith('/claim')), isEmpty);
      expect(find.text('Moved 10 tasks to Done'), findsOneWidget);
      expect(bar, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('one refusal: the toast says skipped, and that task stays '
        'selected to try again', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(4)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      server.routes['PATCH /tasks/m03/status'] = (_) => (403, {'error': 'No'});
      await pickStatus(t, 'Done');
      await settleTasks(t, rounds: 6);
      expect(find.text('Moved 3 tasks to Done, skipped 1'), findsOneWidget);
      expect(bar, findsOneWidget);
      expect(count(1), findsOneWidget);
      // Try again: the same action, now answered (the toast has gone).
      await t.pump(const Duration(seconds: 10));
      server.routes.remove('PATCH /tasks/m03/status');
      await pickStatus(t, 'Done');
      await settleTasks(t, rounds: 6);
      expect(find.text('Moved 1 task to Done'), findsOneWidget);
      expect(bar, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a task the viewer may not change is skipped, and with '
        'none left the toast is an error', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(
          tasks: [
            ...mine(2),
            pageTask(
              'r1',
              number: 9,
              claimedBy: meId,
              extra: {
                'readOnlyReason': 'archived',
                'activityAt': '2026-11-17T08:00:00.000Z',
              },
            ),
          ],
        ),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      await pickStatus(t, 'Done');
      await settleTasks(t, rounds: 6);
      expect(writes(server, 'PATCH', '/status').length, 2);
      expect(find.text('Moved 2 tasks to Done, skipped 1'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Assign to me: PATCH /tasks/:id/assignee for each, with the '
        'assignee', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(
          role: 'member',
          tasks: [
            pageTask('u1', number: 1, activityAt: '2026-11-17T10:00:00.000Z'),
            pageTask('u2', number: 2, activityAt: '2026-11-17T09:00:00.000Z'),
          ],
        ),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      // Created by me, not assigned: under 你发起的.
      await selectAll(t);
      expect(count(2), findsOneWidget);
      await t.tap(find.byKey(const Key('selection-bar-action-assignee')));
      await settleTasks(t, rounds: 3);
      await t.tap(find.byKey(const Key('tasks-batch-assignee-me')));
      await settleTasks(t, rounds: 8);
      final patches = [
        for (final r in server.requests)
          if (r.method == 'PATCH' && r.path.endsWith('/assignee')) r,
      ];
      expect(patches.map((r) => r.path), [
        '/tasks/u1/assignee',
        '/tasks/u2/assignee',
      ]);
      expect(patches.first.data, {
        'assignee': {'type': 'user', 'id': meId},
      });
      expect(find.text('Assigned 2 tasks to you'), findsOneWidget);
      expect(bar, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Unassigned clears the assignee', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(2)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      await t.tap(find.byKey(const Key('selection-bar-action-assignee')));
      await settleTasks(t, rounds: 3);
      await t.tap(find.byKey(const Key('tasks-batch-assignee-none')));
      await settleTasks(t, rounds: 8);
      final patches = [
        for (final r in server.requests)
          if (r.method == 'PATCH' && r.path.endsWith('/assignee')) r,
      ];
      expect(patches.length, 2);
      expect(patches.first.data, {'assignee': null});
      expect(find.text('Cleared the assignee of 2 tasks'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('no Assignee action without the capability', (t) async {
      final (w, _) = (await t.runAsync(
        () => tasksFixture(role: 'observer', tasks: mine(2)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      expect(bar, findsOneWidget);
      expect(
        find.byKey(const Key('selection-bar-action-assignee')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('selection-bar-action-status')),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Follow: each task\'s conversation, one request each', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(3)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      await t.tap(find.byKey(const Key('selection-bar-action-follow')));
      await settleTasks(t, rounds: 8);
      final follows = [
        for (final r in server.requests)
          if (r.path == '/channels/threads/follow') r.data['threadChannelId'],
      ];
      expect(follows, unorderedEquals(['conv-m01', 'conv-m02', 'conv-m03']));
      // They have conversations: none is created.
      expect(
        server.requests.where((r) => r.path.endsWith('/conversation')),
        isEmpty,
      );
      expect(find.text('Following 3 tasks'), findsOneWidget);
      expect(bar, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Delete asks first; Cancel sends nothing', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(3)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      await t.tap(find.byKey(const Key('selection-bar-action-delete')));
      await settleTasks(t, rounds: 3);
      expect(find.byKey(const Key('task-delete-confirm')), findsOneWidget);
      expect(find.text('Delete 3 tasks?'), findsOneWidget);
      expect(find.text('Delete 3 tasks'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settleTasks(t, rounds: 3);
      expect(find.byKey(const Key('task-delete-confirm')), findsNothing);
      expect(server.requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(bar, findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Delete waits in its dialog, says what the server refused '
        'there, and a retry closes it', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(3)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      server.routes['DELETE /tasks/m02'] = (_) => (500, {'error': 'No'});
      await t.tap(find.byKey(const Key('selection-bar-action-delete')));
      await settleTasks(t, rounds: 3);
      await t.tap(find.byKey(const Key('task-delete-confirm-action')));
      await settleTasks(t, rounds: 8);
      expect(
        writes(
          server,
          'DELETE',
          '',
        ).where((p) => p.startsWith('/tasks/')).length,
        3,
      );
      // Open, with the sentence; the refused task is the one still selected.
      expect(find.byKey(const Key('task-delete-confirm')), findsOneWidget);
      expect(find.text("1 task wasn't deleted. Try again."), findsOneWidget);
      server.routes.remove('DELETE /tasks/m02');
      await t.tap(find.byKey(const Key('task-delete-confirm-action')));
      await settleTasks(t, rounds: 8);
      expect(find.byKey(const Key('task-delete-confirm')), findsNothing);
      expect(find.text('Deleted 1 task'), findsOneWidget);
      expect(bar, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Delete is only for tasks the viewer may delete: the rest '
        'are skipped', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(
          role: 'member',
          tasks: [
            pageTask('d1', number: 1, claimedBy: meId),
            pageTask(
              'd2',
              number: 2,
              claimedBy: meId,
              createdBy: 'bob',
              activityAt: '2026-11-17T09:00:00.000Z',
            ),
          ],
        ),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      await t.tap(find.byKey(const Key('selection-bar-action-delete')));
      await settleTasks(t, rounds: 3);
      await t.tap(find.byKey(const Key('task-delete-confirm-action')));
      await settleTasks(t, rounds: 8);
      expect(
        [
          for (final r in server.requests)
            if (r.method == 'DELETE') r.path,
        ],
        ['/tasks/d1'],
      );
      expect(find.text('Deleted 1 task, skipped 1'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('no Delete where nothing selected is the viewer\'s to '
        'delete', (t) async {
      final (w, _) = (await t.runAsync(
        () => tasksFixture(
          role: 'member',
          tasks: [pageTask('d2', number: 2, claimedBy: meId, createdBy: 'bob')],
        ),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      expect(bar, findsOneWidget);
      expect(
        find.byKey(const Key('selection-bar-action-delete')),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('one batch at a time: a second action while one runs does '
        'nothing', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: mine(3)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await selectAll(t);
      final gate = server.gate = Completer<void>();
      await pickStatus(t, 'Done');
      await settleTasks(t, rounds: 3);
      // The bar is busy: its actions are off.
      final status = t.widget<RaftDropdownMenu>(
        find.byKey(const Key('selection-bar-action-status')),
      );
      expect(status.enabled, isFalse);
      gate.complete();
      await settleTasks(t, rounds: 8);
      expect(writes(server, 'PATCH', '/status').length, 3);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('focus', () {
    testWidgets('the bar gone with focus in it: focus returns to the row '
        'picked last', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(3))))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await tapWith(t, row('m02'), LogicalKeyboardKey.controlLeft);
      await t.tap(find.byKey(const Key('selection-bar-clear')));
      await settleTasks(t, rounds: 4);
      expect(bar, findsNothing);
      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull);
      var inRow = false;
      focus!.context!.visitAncestorElements((e) {
        if (e.widget.key == const Key('tasks-page-row-cell-m02')) inRow = true;
        return !inRow;
      });
      expect(inRow, isTrue);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('paint', () {
    for (final dark in [false, true]) {
      testWidgets('the bar and the toolbar seam, ${dark ? 'dark' : 'light'}', (
        t,
      ) async {
        final (w, _) = (await t.runAsync(() => tasksFixture(tasks: mine(2))))!;
        addTearDown(w.dispose);
        await mountPage(t, w, dark: dark);
        await selectAll(t);
        final tokens = RaftTokens.of(t.element(bar));
        final seam = tokens.colors['line-seam'];
        final toolbar = t.widget<Container>(
          find.byKey(const Key('tasks-page-toolbar')),
        );
        final decoration = toolbar.decoration! as BoxDecoration;
        expect((decoration.border! as Border).bottom.color, seam);
        expect(decoration.color, tokens.colors['layer-canvas']);
        final surface = t.widget<DecoratedBox>(
          find.byKey(const Key('selection-bar')),
        );
        final bg = surface.decoration as BoxDecoration;
        expect(bg.color, tokens.popover);
        expect(bg.boxShadow!.last.color, seam);
        expect(tokens.dark, dark);
        await t.pumpWidget(const SizedBox());
      });
    }
  });
}
