import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_toolbar.dart';

import 'support/tasks_page_harness.dart';

void main() {
  testWidgets('scrolling retains the already built task rows', (tester) async {
    final (workspace, _) = (await tester.runAsync(
      () => tasksFixture(
        tasks: [
          for (var number = 100; number < 160; number++)
            pageTask('task-$number', claimedBy: meId),
        ],
      ),
    ))!;
    addTearDown(workspace.dispose);
    await mountPage(
      tester,
      workspace,
      size: const Size(390, 640),
      platform: TargetPlatform.android,
    );
    final held = find.byKey(const ValueKey('tasks-page-row-task-155'));
    expect(held.hitTestable(), findsOneWidget);
    final retained = tester.element(held);
    final rebuilt = <Key>[];
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, _) {
      if (identical(element, retained)) {
        rebuilt.add(element.widget.key!);
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    final scroll = Scrollable.of(tester.element(held)).position;
    scroll.jumpTo(scroll.pixels + 48);
    await tester.pump();
    expect(held.hitTestable(), findsOneWidget);
    expect(rebuilt, isEmpty);
  });

  testWidgets('a task edit leaves its toolbar and unrelated agent row alone', (
    tester,
  ) async {
    final (workspace, _) = (await tester.runAsync(
      () => tasksFixture(
        tasks: [
          for (var number = 100; number < 160; number++)
            pageTask(
              'task-$number',
              extra: number == 157
                  ? {
                      'claimedByType': 'agent',
                      'claimedById': 'fixture-agent',
                      'claimedByName': 'Fixture agent',
                    }
                  : const {},
            ),
        ],
      ),
    ))!;
    addTearDown(workspace.dispose);
    await mountPage(
      tester,
      workspace,
      size: const Size(390, 640),
      platform: TargetPlatform.android,
    );
    final held = find.byKey(const ValueKey('tasks-page-row-task-157'));
    expect(held.hitTestable(), findsOneWidget);
    final retained = tester.element(held);
    final toolbar = tester.element(find.byType(TasksPageToolbar));
    final rebuilt = <String>[];
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, _) {
      if (identical(element, retained) || identical(element, toolbar)) {
        rebuilt.add(element.widget.toStringShort());
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    (workspace.client as TasksClient).emit('task:updated', {
      'serverId': 's1',
      'task': pageTask(
        'task-159',
        extra: {'title': 'Edited task for the visible list'},
      ),
    });
    await settleTasks(tester, rounds: 3);
    expect(find.text('Edited task for the visible list'), findsOneWidget);
    expect(held.hitTestable(), findsOneWidget);
    expect(rebuilt, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Tasks mounts rows near the viewport and reveals more by scrolling',
    (tester) async {
      final fixture = (await tester.runAsync(
        () => tasksFixture(
          tasks: [
            for (var number = 100; number < 160; number++)
              pageTask('task-$number', claimedBy: meId),
          ],
        ),
      ))!;
      final (workspace, server) = fixture;
      addTearDown(workspace.dispose);
      await mountPage(
        tester,
        workspace,
        size: const Size(390, 640),
        platform: TargetPlatform.android,
      );
      Finder task(int number) =>
          find.byKey(ValueKey('tasks-page-row-cell-task-$number'));
      expect(task(159).hitTestable(), findsOneWidget);
      expect(server.taskReads, isNotEmpty);
      expect(task(140), findsNothing);

      final scroll = find.descendant(
        of: find.byKey(const ValueKey('tasks-page-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(task(140), 225, scrollable: scroll.first);
      expect(task(140).hitTestable(), findsOneWidget);
    },
  );
}
