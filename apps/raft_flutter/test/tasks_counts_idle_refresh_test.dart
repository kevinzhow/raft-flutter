import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';

import 'support/tasks_page_harness.dart';

void main() {
  for (final view in ['list', 'board']) {
    testWidgets(
      'Tasks $view stays still when a retained count starts reading',
      (tester) async {
        final first = pageTask('first');
        final (workspace, server) = (await tester.runAsync(
          () => tasksFixture(tasks: [first]),
        ))!;
        final clock = tester.binding.clock;
        final answer = Completer<void>();
        var hold = false;
        var reads = 0;
        final store = TasksPageStore(
          viewerId: () => workspace.client.user?.id,
          now: clock.now,
          query: (path, query) async {
            if (path == '/tasks/server/counts') {
              reads++;
              if (hold) await answer.future;
            }
            return workspace.query(path, query: query);
          },
        );
        addTearDown(() async {
          if (!answer.isCompleted) answer.complete();
          await tester.pumpWidget(const SizedBox());
          store.dispose();
          workspace.dispose();
        });
        sizeWindow(tester, const Size(1280, 900));
        await tester.pumpWidget(
          tasksApp(
            TasksPage(
              controller: workspace,
              onOpenTask: (_) {},
              currentTaskId: null,
              store: store,
            ),
          ),
        );
        await settleTasks(tester);
        await tester.tap(find.byKey(const ValueKey('tasks-page-tab-all')));
        await tester.tap(find.byKey(ValueKey('tasks-page-view-$view')));
        await settleTasks(tester);

        const all = ServerTaskFilters();
        expect(store.countsCurrent(all), isTrue);
        final before = reads;
        final second = pageTask('second');
        hold = true;
        server.tasks.add(second);
        (workspace.client as TasksClient).emit('task:created', {
          'serverId': 's1',
          'task': second,
        });
        await settleTasks(tester);

        final previous = debugOnRebuildDirtyWidget;
        var builds = 0;
        debugOnRebuildDirtyWidget = (element, firstBuild) {
          if (element.widget is TasksPage) builds++;
          previous?.call(element, firstBuild);
        };
        try {
          await tester.pump(const Duration(seconds: 10));
          await tester.pump();
          expect(reads, greaterThan(before));
          expect(store.counts[all.key]?.data?.total, 1);
          expect(builds, 0);
        } finally {
          debugOnRebuildDirtyWidget = previous;
          answer.complete();
        }
        await settleTasks(tester);
        expect(store.countsCurrent(all), isTrue);
        expect(store.counts[all.key]?.data?.total, 2);
      },
    );
  }
}
