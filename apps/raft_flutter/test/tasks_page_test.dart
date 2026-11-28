// The server Tasks page with task v2 (Web v1.24 TasksPage): which page shows,
// every number the server's count, and the page's states. Each hint here is
// shown to resolve: its action is performed and the hint is gone.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/task_content_slot.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/tasks_page_harness.dart';

List<Map<String, dynamic>> fixtureTasks() => [
  pageTask('a1', status: 'todo', claimedBy: meId),
  pageTask('a2', status: 'in_progress', claimedBy: meId),
  pageTask('a3', status: 'backlog', claimedBy: meId),
  pageTask('s1', status: 'todo'),
  pageTask('s2', status: 'todo', claimedBy: 'bob'),
  pageTask('s3', status: 'closed'),
  pageTask('o1', status: 'todo', createdBy: 'bob', claimedBy: 'bob'),
];

Finder headNumber(String text) => find.descendant(
  of: find.byKey(const Key('page-header-surface')),
  matching: find.text(text),
);

List<String?> tabCounts(WidgetTester t) => [
  for (final i
      in t
          .widget<RaftSegmentedControl<TasksPageTab>>(
            find.byType(RaftSegmentedControl<TasksPageTab>),
          )
          .items)
    i.count,
];

Future<void> tapTab(WidgetTester t, TasksPageTab tab) async {
  await t.tap(find.byKey(ValueKey('tasks-page-tab-${tab.name}')));
  await settleTasks(t);
}

void main() {
  group('which page shows', () {
    Future<void> mountResource(WidgetTester t, WorkspaceController w) async {
      sizeWindow(t, const Size(1280, 900));
      await t.pumpWidget(
        tasksApp(
          ResourceView(
            controller: w,
            section: 'tasks',
            onMessage: (_, _) async {},
            onTask: (_, _) {},
          ),
        ),
      );
      await settleTasks(t);
    }

    testWidgets('flag off: today\'s page, and the new page asks for nothing', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(flag: false, tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      await t.runAsync(() => TaskV2ConversationsFlag.of(w).ensure());
      await mountResource(t, w);
      expect(find.byKey(const ValueKey('tasks-page-toolbar')), findsNothing);
      expect(find.byType(TasksPage), findsNothing);
      expect(server.countReads, isEmpty);
      // Today's loader read its status lanes.
      expect(server.taskReads, isNotEmpty);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('flag on: the new page, and the old loader reads nothing', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(flag: true, tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      await t.runAsync(() => TaskV2ConversationsFlag.of(w).ensure());
      await mountResource(t, w);
      expect(find.byType(TasksPage), findsOneWidget);
      expect(find.byKey(const ValueKey('tasks-page-toolbar')), findsOneWidget);
      // Every page read is a lane of the new page (`relation`, 20 rows), none
      // of today's status lanes (30 rows); the counts are the new page's.
      expect(server.taskReads, isNotEmpty);
      for (final read in server.taskReads) {
        expect(read.queryParameters['limit'], '$lanePageSize');
        expect(read.queryParameters, contains('relation'));
      }
      expect(server.countReads, isNotEmpty);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the flag still loading: today\'s page, then the new one', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(flag: true, tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      final release = server.holds['POST /feature-flags/evaluate'] =
          Completer<void>();
      await mountResource(t, w);
      expect(find.byType(TasksPage), findsNothing);
      expect(server.countReads, isEmpty);
      release.complete();
      await settleTasks(t);
      expect(find.byType(TasksPage), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('the numbers are the server\'s', () {
    testWidgets('我的: head, tabs and section totals from the counts', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      // 分配给你 3, 你发起的 2 (the open ones), 全部 7.
      expect(headNumber('5'), findsOneWidget);
      expect(tabCounts(t), ['5', '7']);
      expect(
        t
            .widget<Text>(
              find.byKey(const Key('tasks-page-section-count-assigned')),
            )
            .data,
        '3',
      );
      expect(
        t
            .widget<Text>(
              find.byKey(const Key('tasks-page-section-count-started')),
            )
            .data,
        '2',
      );
      // Exactly four counts, one request each: every task, then the three
      // relations of 我的 (the sections' filters and the head's are the same).
      final doneSince = RegExp('completed_since=[^&]*');
      String key(Map<String, dynamic> q) =>
          (q.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
              .map((e) => '${e.key}=${e.value}')
              .join('&')
              .replaceAll(doneSince, 'completed_since=*');
      expect(
        server.countReads.map((r) => key(r.queryParameters)).toList()..sort(),
        [
          '',
          'completed_since=*&relation=created_by_me&status=backlog,done,in_progress,in_review,todo',
          'completed_since=*&relation=from_my_message&status=backlog,done,in_progress,in_review,todo',
          'relation=assigned_to_me&status=backlog,in_progress,in_review,todo',
        ]..sort(),
      );
      // The sections' first pages: 20 rows, summaries, most recent first.
      expect(
        server.taskReads
            .where((r) => r.queryParameters['relation'] == 'assigned_to_me')
            .single
            .queryParameters,
        {
          'relation': 'assigned_to_me',
          'status': 'backlog,in_progress,in_review,todo',
          'sort': 'activity',
          'limit': '20',
          'detail': 'summary',
        },
      );
      expect(find.byKey(const Key('tasks-page-row-open-a1')), findsOneWidget);
      expect(find.byKey(const Key('tasks-page-row-open-s1')), findsOneWidget);
      // Not mine: only under 全部.
      expect(find.byKey(const Key('tasks-page-row-open-o1')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a filter narrows the head to N / total and the lanes ask '
        'for it', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await t.tap(find.byKey(const ValueKey('tasks-page-filter-status')));
      await settleTasks(t);
      await t.tap(find.byKey(const ValueKey('task-filter-Status-todo')));
      await settleTasks(t);
      // todo: one assigned to me, two I started; of the five 我的 holds.
      expect(headNumber('3 / 5'), findsOneWidget);
      expect(
        server.taskReads
            .where(
              (r) =>
                  r.queryParameters['relation'] == 'assigned_to_me' &&
                  r.queryParameters['status'] == 'todo',
            )
            .length,
        1,
      );
      // Clear filters is there, and clears them.
      expect(
        find.byKey(const ValueKey('tasks-page-clear-filters')),
        findsOneWidget,
      );
      await t.tapAt(const Offset(5, 5));
      await settleTasks(t);
      await t.tap(find.byKey(const ValueKey('tasks-page-clear-filters')));
      await settleTasks(t);
      expect(headNumber('5'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tasks-page-clear-filters')),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('全部: one list with the tab\'s total, every task', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await tapTab(t, TasksPageTab.all);
      expect(headNumber('7'), findsOneWidget);
      expect(find.byKey(const Key('tasks-page-all-list')), findsOneWidget);
      expect(find.byKey(const Key('tasks-page-row-open-o1')), findsOneWidget);
      expect(
        server.taskReads
            .where((r) => !r.queryParameters.containsKey('relation'))
            .length,
        1,
      );
      await t.pumpWidget(const SizedBox());
    });
  });

  group('states', () {
    testWidgets('loading: a skeleton of the list until the counts land', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      final hold = server.holds['GET /tasks/server/counts'] = Completer<void>();
      await mountPage(t, w);
      expect(find.byKey(const Key('tasks-page-mine-loading')), findsOneWidget);
      expect(headNumber('5'), findsNothing);
      hold.complete();
      await settleTasks(t);
      expect(find.byKey(const Key('tasks-page-mine-loading')), findsNothing);
      expect(headNumber('5'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('failed: says so with Try again, and Try again loads it', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      final answer = server.routes['GET /tasks/server/counts'] = (_) =>
          (500, {'error': 'down'});
      expect(answer, isNotNull);
      await mountPage(t, w);
      // Three attempts, a second and two seconds apart.
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(seconds: 2));
        await settleTasks(t, rounds: 3);
      }
      expect(find.byKey(const Key('tasks-page-failed')), findsOneWidget);
      expect(find.text('Tasks didn’t load'), findsOneWidget);
      expect(find.byKey(const Key('tasks-page-mine-loading')), findsNothing);
      server.routes.remove('GET /tasks/server/counts');
      await t.tap(find.byKey(const Key('tasks-page-failed-retry')));
      await settleTasks(t);
      // Resolved: the hint is gone and the list is there.
      expect(find.byKey(const Key('tasks-page-failed')), findsNothing);
      expect(headNumber('5'), findsOneWidget);
      expect(find.byKey(const Key('tasks-page-row-open-a1')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('全部 with nothing: No tasks yet; 我的 with nothing: the '
        'sections say so', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: [])))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      expect(find.byKey(const Key('tasks-page-mine')), findsOneWidget);
      expect(find.text('No tasks'), findsNWidgets(2));
      await tapTab(t, TasksPageTab.all);
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(find.byKey(const Key('tasks-page-empty')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a search with no hit: No tasks match, and the search\'s '
        'clear brings the list back', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('tasks-page-search')),
          matching: find.byType(EditableText),
        ),
        'zzz',
      );
      // Not read while typing; read once typing pauses.
      await t.pump(const Duration(milliseconds: 100));
      expect(
        server.taskReads.where((r) => r.queryParameters.containsKey('q')),
        isEmpty,
      );
      await t.pump(const Duration(milliseconds: 200));
      await settleTasks(t);
      expect(
        server.taskReads.where((r) => r.queryParameters['q'] == 'zzz'),
        isNotEmpty,
      );
      // A search is not counted: the counts take no `q`.
      expect(
        server.countReads.where((r) => r.queryParameters.containsKey('q')),
        isEmpty,
      );
      expect(find.byKey(const Key('tasks-page-empty')), findsOneWidget);
      expect(find.text('No tasks match'), findsOneWidget);
      await t.tap(find.byTooltip('Clear search'));
      await settleTasks(t);
      expect(find.byKey(const Key('tasks-page-empty')), findsNothing);
      expect(find.byKey(const Key('tasks-page-row-open-a1')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  testWidgets('a row opens its task', (t) async {
    final (w, _) = (await t.runAsync(
      () => tasksFixture(tasks: fixtureTasks()),
    ))!;
    addTearDown(w.dispose);
    final opened = await mountPage(t, w);
    await t.tap(find.byKey(const Key('tasks-page-row-open-a2')));
    await settleTasks(t, rounds: 2);
    expect(opened.map((r) => r['id']), ['a2']);
    await t.pumpWidget(const SizedBox());
  });

  group('New task', () {
    Future<void> openDialog(WidgetTester t) async {
      await t.tap(find.byKey(const Key('tasks-page-new-task')));
      await settleTasks(t, rounds: 4);
    }

    testWidgets('opens the create dialog with the one channel filtered to, '
        'and the task it made opens when exactly one was made', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: fixtureTasks()),
      ))!;
      addTearDown(w.dispose);
      await t.runAsync(() => TaskV2ConversationsFlag.of(w).ensure());
      server.routes['POST /tasks/channel/c1'] = (_) => (
        200,
        {
          'tasks': [pageTask('n1', number: 30)],
        },
      );
      final opened = await mountPage(t, w, size: const Size(2600, 900));
      await t.tap(find.byKey(const ValueKey('tasks-page-filter-channel')));
      await settleTasks(t, rounds: 3);
      await t.tap(find.byKey(const ValueKey('task-filter-Channel-c1')));
      await settleTasks(t);
      await t.tapAt(const Offset(5, 5));
      await settleTasks(t, rounds: 2);
      await openDialog(t);
      expect(
        find.byKey(const ValueKey('create-task-message-dialog')),
        findsOneWidget,
      );
      // The channel filtered to is the channel it is in.
      expect(find.textContaining('test'), findsWidgets);
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('create-task-message')),
          matching: find.byType(EditableText),
        ),
        'Ship it',
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('create-task-submit')));
      await settleTasks(t, rounds: 14);
      expect(
        server.requests.where(
          (r) => r.method == 'POST' && r.path == '/tasks/channel/c1',
        ),
        hasLength(1),
      );
      expect(opened.map((r) => r['id']), ['n1']);
      expect(
        find.byKey(const ValueKey('create-task-message-dialog')),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Escape ends the selection before the open task\'s own '
      'Escape (the slot\'s)', (t) async {
    final (w, _) = (await t.runAsync(
      () => tasksFixture(tasks: fixtureTasks()),
    ))!;
    addTearDown(w.dispose);
    sizeWindow(t, const Size(1280, 900));
    var closed = 0;
    final taskFocus = FocusNode();
    addTearDown(taskFocus.dispose);
    await t.pumpWidget(
      tasksApp(
        TaskSlotScope(
          taskId: 'a1',
          onClose: () => closed++,
          surface: (_) => Focus(focusNode: taskFocus, child: const SizedBox()),
          child: Row(
            children: [
              Expanded(
                child: TasksPage(
                  controller: w,
                  onOpenTask: (_) {},
                  currentTaskId: 'a1',
                ),
              ),
              const SizedBox(width: 300, child: TaskContentSlot()),
            ],
          ),
        ),
      ),
    );
    await settleTasks(t);
    // Focus is in the open task (as its composer's would be).
    taskFocus.requestFocus();
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.tap(find.byKey(const Key('tasks-page-row-open-a2')));
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleTasks(t, rounds: 2);
    expect(find.byKey(const Key('tasks-page-selection-bar')), findsOneWidget);
    taskFocus.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleTasks(t, rounds: 2);
    expect(find.byKey(const Key('tasks-page-selection-bar')), findsNothing);
    expect(closed, 0);
    // Nothing selected: the task's Escape is its own.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('in Chinese the page says it as Web does', (t) async {
    final (w, _) = (await t.runAsync(
      () => tasksFixture(tasks: fixtureTasks()),
    ))!;
    addTearDown(w.dispose);
    sizeWindow(t, const Size(2600, 900));
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(),
        home: RaftToastHost(
          child: Scaffold(
            body: TasksPage(
              controller: w,
              onOpenTask: (_) {},
              currentTaskId: null,
            ),
          ),
        ),
      ),
    );
    await settleTasks(t);
    for (final word in [
      '任务',
      '我的',
      '全部',
      '分配给你',
      '你发起的',
      '新建任务',
      '搜索任务',
      '最近更新',
      '列表',
      '看板',
    ]) {
      expect(find.text(word), findsWidgets, reason: word);
    }
    // Select one: the bar's count and the Delete confirmation's words.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.tap(find.byKey(const Key('tasks-page-row-open-a1')));
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleTasks(t, rounds: 2);
    expect(find.textContaining('已选'), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });
}
