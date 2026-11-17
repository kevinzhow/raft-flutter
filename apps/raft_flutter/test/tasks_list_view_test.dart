// The Tasks page's list (Web v1.24 TasksListView): 我的 in two sections, 全部
// as one list, rows read a page at a time, and what a live task event does.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_rows.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/tasks_page_harness.dart';

Finder row(String id) => find.byKey(Key('tasks-page-row-open-$id'));

List<Map<String, dynamic>> many(int count) => [
  for (var i = 1; i <= count; i++)
    pageTask(
      'm${i.toString().padLeft(3, '0')}',
      number: i,
      claimedBy: meId,
      activityAt: DateTime.utc(
        2026,
        11,
        17,
        10,
      ).subtract(Duration(minutes: i)).toIso8601String(),
    ),
];

Future<void> scrollDown(WidgetTester t, [double by = 3000]) async {
  await t.drag(find.byKey(const Key('tasks-page-scroll')), Offset(0, -by));
  await settleTasks(t, rounds: 4);
}

void main() {
  group('sections', () {
    testWidgets('我的: 分配给你 without an assignee column, 你发起的 with '
        'who has each; each says No tasks when empty', (t) async {
      final (w, _) = (await t.runAsync(
        () => tasksFixture(
          tasks: [
            pageTask(
              'a1',
              claimedBy: meId,
              extra: {'claimedByName': 'Alice Reader'},
            ),
            pageTask(
              's1',
              claimedBy: 'bob',
              activityAt: '2026-11-17T09:00:00.000Z',
              extra: {'claimedByName': 'Bobby Builder'},
            ),
            pageTask('s2', activityAt: '2026-11-17T08:00:00.000Z'),
          ],
        ),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      expect(find.text('Assigned'), findsOneWidget);
      expect(find.text('Started by you'), findsOneWidget);
      final assigned = find.byKey(const Key('tasks-page-section-assigned'));
      final started = find.byKey(const Key('tasks-page-section-started'));
      expect(
        find.descendant(of: assigned, matching: find.text('Alice Reader')),
        findsNothing,
      );
      expect(
        find.descendant(of: started, matching: find.text('Bobby Builder')),
        findsOneWidget,
      );
      // Nobody has s2.
      expect(
        find.descendant(of: started, matching: find.text('Unassigned')),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a section with nothing says No tasks', (t) async {
      final (w, _) = (await t.runAsync(
        () => tasksFixture(tasks: [pageTask('a1', claimedBy: meId)]),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      final started = find.byKey(const Key('tasks-page-section-started'));
      expect(
        find.descendant(of: started, matching: find.text('No tasks')),
        findsOneWidget,
      );
      expect(
        t
            .widget<Text>(
              find.byKey(const Key('tasks-page-section-count-started')),
            )
            .data,
        '0',
      );
      await t.pumpWidget(const SizedBox());
    });
  });

  group('paging', () {
    testWidgets('the next page is read as the end scrolls into view, with '
        'the cursor the server gave', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: many(65)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w, size: const Size(1280, 500));
      // 20 rows are taller than the window and its margin: no second read.
      final first = server.taskReads
          .where((r) => r.queryParameters['relation'] == 'assigned_to_me')
          .toList();
      expect(first.length, 1);
      expect(first.single.queryParameters.containsKey('cursor'), isFalse);
      expect(row('m021'), findsNothing);
      await scrollDown(t);
      await scrollDown(t);
      final reads = server.taskReads
          .where((r) => r.queryParameters['relation'] == 'assigned_to_me')
          .map((r) => r.queryParameters['cursor'])
          .toList();
      expect(reads.take(3), [null, '20', '40']);
      await scrollDown(t);
      await scrollDown(t);
      expect(row('m065'), findsOneWidget);
      // The end: nothing more is asked for.
      final done = server.taskReads.length;
      await scrollDown(t);
      expect(server.taskReads.length, done);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a page that fails shows Try again in place, and Try again '
        'reads it', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: many(45)),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w, size: const Size(1280, 500));
      server.routes['GET /tasks/server'] = (o) =>
          o.queryParameters['cursor'] == '20'
          ? (500, {'error': 'down'})
          : server.answer(o);
      await scrollDown(t);
      await scrollDown(t);
      expect(find.byKey(const Key('tasks-page-more-retry')), findsOneWidget);
      // It waits for a press: no read on its own.
      final before = server.taskReads.length;
      await settleTasks(t, rounds: 4);
      expect(server.taskReads.length, before);
      server.routes.remove('GET /tasks/server');
      await t.tap(find.byKey(const Key('tasks-page-more-retry')));
      await settleTasks(t);
      expect(find.byKey(const Key('tasks-page-more-retry')), findsNothing);
      await scrollDown(t);
      expect(row('m045'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a first page that fails: Try again, no skeleton', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: many(5)),
      ))!;
      addTearDown(w.dispose);
      server.routes['GET /tasks/server'] = (_) => (500, {'error': 'down'});
      await mountPage(t, w);
      expect(find.byKey(const Key('tasks-page-more-retry')), findsWidgets);
      expect(find.byKey(const Key('tasks-page-rows-loading')), findsNothing);
      server.routes.remove('GET /tasks/server');
      await t.tap(find.byKey(const Key('tasks-page-more-retry')).first);
      await settleTasks(t);
      expect(row('m001'), findsOneWidget);
      expect(find.byKey(const Key('tasks-page-more-retry')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('while the first page is read: row skeletons, each the size '
        'of a loaded row', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: many(5)),
      ))!;
      addTearDown(w.dispose);
      final hold = server.holds['GET /tasks/server'] = Completer<void>();
      await mountPage(t, w);
      expect(find.byKey(const Key('tasks-page-rows-loading')), findsWidgets);
      final skeleton = t.getSize(
        find.byKey(const Key('tasks-page-row-loading-0')).first,
      );
      hold.complete();
      await settleTasks(t);
      expect(find.byKey(const Key('tasks-page-rows-loading')), findsNothing);
      final loaded = t.getSize(
        find.byKey(const Key('tasks-page-row-cell-m001')),
      );
      expect(skeleton.height, loaded.height);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('live events', () {
    testWidgets('a task updated out of the list leaves it, with no read', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(
          tasks: [
            pageTask('a1', claimedBy: meId),
            pageTask(
              'a2',
              claimedBy: meId,
              activityAt: '2026-11-17T09:00:00.000Z',
            ),
          ],
        ),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      expect(row('a1'), findsOneWidget);
      final reads = server.taskReads.length;
      (w.client as TasksClient).emit('task:updated', {
        'serverId': 's1',
        'task': {...pageTask('a1', claimedBy: meId, status: 'done')},
      });
      await settleTasks(t, rounds: 3);
      expect(row('a1'), findsNothing);
      expect(row('a2'), findsOneWidget);
      expect(server.taskReads.length, reads);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a task created for me appears at the top with no read', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(
          tasks: [
            pageTask(
              'a2',
              claimedBy: meId,
              activityAt: '2026-11-17T09:00:00.000Z',
            ),
          ],
        ),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      final reads = server.taskReads.length;
      (w.client as TasksClient).emit('task:created', {
        'serverId': 's1',
        'task': pageTask(
          'a9',
          claimedBy: meId,
          activityAt: '2026-11-17T11:00:00.000Z',
        ),
      });
      await settleTasks(t, rounds: 3);
      expect(row('a9'), findsOneWidget);
      expect(t.getTopLeft(row('a9')).dy < t.getTopLeft(row('a2')).dy, isTrue);
      expect(server.taskReads.length, reads);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a task deleted is gone', (t) async {
      final (w, _) = (await t.runAsync(
        () => tasksFixture(tasks: [pageTask('a1', claimedBy: meId)]),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      (w.client as TasksClient).emit('task:deleted', {
        'serverId': 's1',
        'taskId': 'a1',
      });
      await settleTasks(t, rounds: 3);
      expect(row('a1'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a reconnect starts every read over', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: [pageTask('a1', claimedBy: meId)]),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      final reads = server.taskReads.length, counts = server.countReads.length;
      (w.client as TasksClient).emit('connected', {});
      await settleTasks(t);
      expect(server.taskReads.length, greaterThan(reads));
      expect(server.countReads.length, greaterThan(counts));
      expect(row('a1'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('another server\'s event is ignored', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: [pageTask('a1', claimedBy: meId)]),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      final reads = server.taskReads.length;
      (w.client as TasksClient).emit('task:deleted', {
        'serverId': 'other',
        'taskId': 'a1',
      });
      await settleTasks(t, rounds: 3);
      expect(row('a1'), findsOneWidget);
      expect(server.taskReads.length, reads);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('a row', () {
    testWidgets('the open task\'s row takes the selected fill', (t) async {
      final (w, _) = (await t.runAsync(
        () => tasksFixture(
          tasks: [
            pageTask('a1', claimedBy: meId),
            pageTask(
              'a2',
              claimedBy: meId,
              activityAt: '2026-11-17T09:00:00.000Z',
            ),
          ],
        ),
      ))!;
      addTearDown(w.dispose);
      sizeWindow(t, const Size(1280, 900));
      await t.pumpWidget(
        tasksApp(
          TasksPage(controller: w, onOpenTask: (_) {}, currentTaskId: 'a2'),
        ),
      );
      await settleTasks(t);
      Color? fill(String id) =>
          ((t.widget<DecoratedBox>(
                    find.byKey(Key('tasks-page-row-cell-$id')),
                  )).decoration
                  as BoxDecoration)
              .color;
      final tokens = RaftTokens.of(t.element(row('a1')));
      expect(fill('a2'), tokens.colors['fill-cell-selected']);
      expect(fill('a1'), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('its time is short, and the warning ink when an open task '
        'has had no update for 3 days (said after the time too)', (t) async {
      final now = DateTime.utc(2026, 11, 17, 12);
      Future<void> pumpTime(Map<String, dynamic> task) => t.pumpWidget(
        tasksApp(
          Center(
            child: TaskActivityTime(task: task, now: now),
          ),
        ),
      );
      await pumpTime({
        'status': 'todo',
        'activityAt': '2026-11-17T08:00:00.000Z',
      });
      expect(find.text('4h ago'), findsOneWidget);
      final tokens = RaftTokens.of(t.element(find.text('4h ago')));
      expect(
        t.widget<Text>(find.text('4h ago')).style!.color,
        tokens.ui.foregroundHint,
      );
      await pumpTime({
        'status': 'todo',
        'activityAt': '2026-11-12T08:00:00.000Z',
      });
      expect(find.text('5d ago'), findsOneWidget);
      expect(
        t.widget<Text>(find.text('5d ago')).style!.color,
        tokens.colors['warning-strong'],
      );
      expect(
        find.bySemanticsLabel('5d ago no update for 3 days'),
        findsOneWidget,
      );
      // A finished task is never stale.
      await pumpTime({
        'status': 'done',
        'activityAt': '2026-11-12T08:00:00.000Z',
      });
      expect(
        t.widget<Text>(find.text('5d ago')).style!.color,
        tokens.ui.foregroundHint,
      );
    });
  });

  testWidgets('the store keeps what it read: coming back shows the list '
      'without a loading state', (t) async {
    final (w, server) = (await t.runAsync(
      () => tasksFixture(tasks: [pageTask('a1', claimedBy: meId)]),
    ))!;
    addTearDown(w.dispose);
    await mountPage(t, w);
    expect(row('a1'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    final reads = server.taskReads.length;
    await mountPage(t, w);
    // The first frame already has the rows.
    expect(row('a1'), findsOneWidget);
    expect(find.byKey(const Key('tasks-page-mine-loading')), findsNothing);
    await settleTasks(t);
    expect(server.taskReads.length, reads);
    expect(TasksPageStore.of(w).knownById.keys, contains('a1'));
    await t.pumpWidget(const SizedBox());
  });
}
