// The Tasks page's toolbar (Web v1.24 TasksPageToolbar): the line's height by
// input mode, what gives way as the page narrows, and what each control asks
// the server for.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/tasks_page_harness.dart';

List<Map<String, dynamic>> data() => [
  pageTask('a1', claimedBy: meId),
  pageTask('s1', status: 'in_progress', activityAt: '2026-11-17T09:00:00.000Z'),
];

Finder toolbar = find.byKey(const Key('tasks-page-toolbar'));
Finder key(String k) => find.byKey(Key(k));

/// What the toolbar shows as a word: a label on screen.
bool hasWord(String word) => find
    .descendant(of: toolbar, matching: find.text(word))
    .evaluate()
    .isNotEmpty;

Future<void> enterSearch(WidgetTester t, String text) async {
  await t.enterText(
    find.descendant(
      of: key('tasks-page-search'),
      matching: find.byType(EditableText),
    ),
    text,
  );
}

void main() {
  group('the line', () {
    testWidgets('44px with a mouse, with its seam, at the page\'s sides', (
      t,
    ) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      expect(t.getSize(toolbar).height, 44);
      expect(t.getSize(toolbar).width, 1280);
      // 16 with a mouse at the surface inset.
      final box = t.getTopLeft(find.byKey(const Key('tasks-page-tab-mine')));
      expect(box.dx, greaterThanOrEqualTo(16));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('49px by touch (the line, with room for it)', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      await mountPage(
        t,
        w,
        size: const Size(2600, 944),
        platform: TargetPlatform.android,
      );
      expect(t.getSize(toolbar).height, 49);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('giving way', () {
    testWidgets('the phone scope leaves room for search beside it', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      await mountPage(
        t,
        w,
        size: const Size(390, 844),
        platform: TargetPlatform.android,
      );
      final scope = key('tasks-page-scope-select');
      final search = key('tasks-page-search');
      await t.tap(scope);
      await settleTasks(t, rounds: 3);
      await t.tap(find.text('All').last);
      await settleTasks(t);
      final label = find.descendant(of: scope, matching: find.text('All'));
      final scopeBounds = t.getRect(scope);
      final labelWidth = t.getSize(label).width;
      final searchLeft = t.getTopLeft(search).dx;
      await t.pumpWidget(const SizedBox());

      // FitToolbarPicker has two 10px insets, a 6px gap and a 14px chevron.
      expect(scopeBounds.width - labelWidth, closeTo(40, .01));
      expect(scopeBounds.height, 32);
      expect(searchLeft - scopeBounds.right, 8);
    });

    testWidgets('wide: every word shows', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      // (The test font is wider than the app's: the room the words need.)
      await mountPage(t, w, size: const Size(2600, 900));
      for (final word in [
        'Mine',
        'All',
        'Channel',
        'Status',
        'Creator',
        'Assignee',
        'Recently updated',
        'List',
        'Board',
        'New task',
      ]) {
        expect(hasWord(word), isTrue, reason: word);
      }
      expect(key('tasks-page-more'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a fold (856x944, touch): the toolbar keeps its controls on '
        'one or two lines and nothing overflows', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      await mountPage(
        t,
        w,
        size: const Size(856, 944),
        platform: TargetPlatform.android,
      );
      expect(t.takeException(), isNull);
      expect(key('tasks-page-filter-channel'), findsOneWidget);
      expect(key('tasks-page-search'), findsOneWidget);
      expect(hasWord('New task'), isTrue);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a narrow desktop window (390x844, a mouse): New task is '
        'a +, the sort and the view are in More, the scope is a Select', (
      t,
    ) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      await mountPage(t, w, size: const Size(390, 844));
      expect(t.takeException(), isNull);
      // + with the words kept as its name.
      expect(hasWord('New task'), isFalse);
      expect(find.bySemanticsLabel('New task'), findsWidgets);
      // The scope is a Select naming it; the segmented control is gone.
      expect(key('tasks-page-scope-select'), findsOneWidget);
      expect(find.byType(RaftSegmentedControl<TasksPageTab>), findsNothing);
      // More holds the sort and the view.
      expect(key('tasks-page-more'), findsOneWidget);
      await t.tap(key('tasks-page-more'));
      await settleTasks(t, rounds: 3);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('View as'), findsOneWidget);
      expect(find.text('Least recently updated'), findsOneWidget);
      // Choosing from it works: the board replaces the list.
      expect(find.byKey(const Key('tasks-page-scroll')), findsOneWidget);
      await t.tap(find.text('Board').last);
      await settleTasks(t);
      expect(find.byKey(const Key('tasks-page-scroll')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('as the width goes the sort and the view give their words '
        'up first', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      var wordsAt = <double, Set<String>>{};
      for (final width in [2600.0, 1700.0, 1280.0, 900.0, 600.0]) {
        await mountPage(t, w, size: Size(width, 900));
        wordsAt[width] = {
          for (final word in [
            'Recently updated',
            'List',
            'Board',
            'Channel',
            'Status',
            'New task',
          ])
            if (hasWord(word)) word,
        };
        await t.pumpWidget(const SizedBox());
      }
      // Wide keeps all six; the sort's and the view's words go before the
      // filters' and New task's.
      expect(wordsAt[2600]!.length, 6);
      final order = [
        for (final width in [2600.0, 1700.0, 1280.0, 900.0, 600.0])
          wordsAt[width]!.length,
      ];
      expect(order.first, 6);
      expect(order.last, lessThan(6));
    });

    testWidgets('an empty search is its button at the narrowest, and typing '
        'keeps it open', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      await mountPage(t, w, size: const Size(320, 700));
      expect(t.takeException(), isNull);
      expect(find.byTooltip('Search tasks'), findsWidgets);
      await t.pumpWidget(const SizedBox());
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('text at ${scale}x: the toolbar lays out without an '
          'overflow and keeps its seam', (t) async {
        final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
        addTearDown(w.dispose);
        sizeWindow(t, const Size(856, 944));
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await mountPage(t, w, size: const Size(856, 944));
        expect(t.takeException(), isNull);
        expect(toolbar, findsOneWidget);
        expect(t.getSize(toolbar).width, 856);
        expect(key('tasks-page-search'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      });
    }
  });

  group('what each control asks for', () {
    testWidgets('the sort changes the lanes\' sort, and the view switches '
        'the page to a board', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: data()),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w, size: const Size(2600, 900));
      await t.tap(key('tasks-page-sort'));
      await settleTasks(t, rounds: 3);
      await t.tap(find.text('Recently created').last);
      await settleTasks(t);
      final sorts = {
        for (final r in server.taskReads) r.queryParameters['sort'],
      };
      expect(sorts, {'activity', 'created'});
      expect(find.text('Recently created'), findsOneWidget);
      await t.tap(find.byKey(const Key('tasks-page-view-board')));
      await settleTasks(t);
      expect(
        t
            .widget<RaftSegmentedControl<TasksPageView>>(
              find.byType(RaftSegmentedControl<TasksPageView>),
            )
            .value,
        TasksPageView.board,
      );
      // The board's counts: per relation, statuses left to the columns.
      expect(
        server.countReads.any(
          (r) =>
              r.queryParameters['relation'] == 'created_by_me' &&
              !r.queryParameters.containsKey('status'),
        ),
        isTrue,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the channel filter asks for its channel on both tabs', (
      t,
    ) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: data()),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await t.tap(key('tasks-page-filter-channel'));
      await settleTasks(t, rounds: 3);
      await t.tap(find.byKey(const ValueKey('task-filter-Channel-c1')));
      await settleTasks(t);
      expect(
        server.taskReads.any((r) => r.queryParameters['channel'] == 'c1'),
        isTrue,
      );
      // The filter shows its count and is filled.
      expect(find.text('1'), findsWidgets);
      await t.tapAt(const Offset(5, 5));
      await settleTasks(t, rounds: 3);
      await t.tap(find.byKey(const Key('tasks-page-tab-all')));
      await settleTasks(t);
      expect(
        server.taskReads.any(
          (r) =>
              r.queryParameters['channel'] == 'c1' &&
              !r.queryParameters.containsKey('relation'),
        ),
        isTrue,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the creator and assignee filters list me first, and '
        'Unassigned for the assignee', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: data()),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await t.tap(key('tasks-page-filter-assignee'));
      await settleTasks(t, rounds: 3);
      final popover = find.byKey(
        const ValueKey('task-selection-assignee-popover'),
      );
      expect(
        find.descendant(of: popover, matching: find.text('Assigned to me')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: popover, matching: find.text('Unassigned')),
        findsOneWidget,
      );
      await t.tap(find.byKey(ValueKey('task-filter-Assignee-user:$meId')));
      await settleTasks(t);
      expect(
        server.taskReads.any(
          (r) => r.queryParameters['assignee'] == 'user:$meId',
        ),
        isTrue,
      );
      await t.tapAt(const Offset(5, 5));
      await settleTasks(t, rounds: 3);
      await t.tap(key('tasks-page-filter-creator'));
      await settleTasks(t, rounds: 3);
      final creators = find.byKey(
        const ValueKey('task-selection-creator-popover'),
      );
      expect(
        find.descendant(of: creators, matching: find.text('Created by me')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: creators, matching: find.text('Unassigned')),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the applied filters come first, Clear all at their end '
        'clears them and goes', (t) async {
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      double left(String k) => t.getTopLeft(key(k)).dx;
      expect(
        left('tasks-page-filter-channel') < left('tasks-page-filter-status'),
        isTrue,
      );
      await t.tap(key('tasks-page-filter-assignee'));
      await settleTasks(t, rounds: 3);
      await t.tap(find.byKey(ValueKey('task-filter-Assignee-user:$meId')));
      await settleTasks(t);
      await t.tapAt(const Offset(5, 5));
      await settleTasks(t, rounds: 3);
      // Assignee is applied: it moves ahead of the others.
      expect(
        left('tasks-page-filter-assignee') < left('tasks-page-filter-channel'),
        isTrue,
      );
      expect(key('tasks-page-clear-filters'), findsOneWidget);
      await t.tap(key('tasks-page-clear-filters'));
      await settleTasks(t);
      expect(key('tasks-page-clear-filters'), findsNothing);
      expect(
        left('tasks-page-filter-channel') < left('tasks-page-filter-assignee'),
        isTrue,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the search reads once typing pauses (250 ms), the x clears '
        'it at once, and it takes 200 characters at most', (t) async {
      final (w, server) = (await t.runAsync(
        () => tasksFixture(tasks: data()),
      ))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      int searched() => server.taskReads
          .where((r) => r.queryParameters.containsKey('q'))
          .length;
      await enterSearch(t, 'Task');
      await t.pump(const Duration(milliseconds: 200));
      expect(searched(), 0);
      await enterSearch(t, 'Task a');
      await t.pump(const Duration(milliseconds: 200));
      // Typing on pushes the wait back.
      expect(searched(), 0);
      await t.pump(const Duration(milliseconds: 100));
      await settleTasks(t);
      expect(searched(), greaterThan(0));
      expect(
        {for (final r in server.taskReads) r.queryParameters['q']}
            .difference({null}),
        {'Task a'},
      );
      // The x: at once, no wait.
      await t.tap(find.byTooltip('Clear search'));
      await t.pump();
      await settleTasks(t, rounds: 2);
      expect(find.byKey(const Key('tasks-page-row-open-a1')), findsOneWidget);
      // 200 at most.
      await enterSearch(t, 'x' * 260);
      await t.pump(const Duration(milliseconds: 300));
      await settleTasks(t, rounds: 3);
      final longest = [
        for (final r in server.taskReads)
          r.queryParameters['q'] as String? ?? '',
      ].fold<int>(0, (m, q) => q.length > m ? q.length : m);
      expect(longest, 200);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the tab and the view are remembered on the device, the '
        'tab per server and person', (t) async {
      SharedPreferences.setMockInitialValues({});
      await t.runAsync(DevicePreferences.load);
      addTearDown(DevicePreferences.reset);
      final (w, _) = (await t.runAsync(() => tasksFixture(tasks: data())))!;
      addTearDown(w.dispose);
      await mountPage(t, w);
      await t.tap(find.byKey(const Key('tasks-page-tab-all')));
      await settleTasks(t);
      await t.tap(find.byKey(const Key('tasks-page-view-board')));
      await settleTasks(t);
      await t.pumpWidget(const SizedBox());
      // A new page opens on the last choice.
      await mountPage(t, w);
      expect(
        t
            .widget<RaftSegmentedControl<TasksPageTab>>(
              find.byType(RaftSegmentedControl<TasksPageTab>),
            )
            .value,
        TasksPageTab.all,
      );
      expect(
        t
            .widget<RaftSegmentedControl<TasksPageView>>(
              find.byType(RaftSegmentedControl<TasksPageView>),
            )
            .value,
        TasksPageView.board,
      );
      await t.pumpWidget(const SizedBox());
    });
  });
}
