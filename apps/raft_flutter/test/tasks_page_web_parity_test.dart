// The server Tasks page against Web v1.24 (the WP-TASKS Web | Flutter
// comparison): the head, the body colour of the failed and empty states, the
// board's drag and card foot, and the toolbar's give-way.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/tasks_page_harness.dart';

List<Map<String, dynamic>> _tasks() => [
  for (var i = 1; i <= 3; i++) pageTask('a$i', status: 'todo', claimedBy: meId),
  pageTask('s1', status: 'todo'),
];

Future<TasksServer> _mount(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  TargetPlatform platform = TargetPlatform.linux,
  bool dark = false,
  List<Map<String, dynamic>>? tasks,
  bool countsFail = false,
}) async {
  final (w, server) = (await t.runAsync(
    () => tasksFixture(tasks: tasks ?? _tasks()),
  ))!;
  addTearDown(w.dispose);
  if (countsFail) {
    server.routes['GET /tasks/server/counts'] = (_) => (500, {'e': 'down'});
  }
  await t.runAsync(() => TaskV2ConversationsFlag.of(w).ensure());
  await mountPage(t, w, size: size, platform: platform, dark: dark);
  return server;
}

Finder _inHead(Finder f) => find.descendant(
  of: find.byKey(const Key('page-header-surface')),
  matching: f,
);

void main() {
  group('the head', () {
    testWidgets('desktop: the number sits beside the title on one baseline', (
      t,
    ) async {
      await _mount(t, tasks: [pageTask('a1', claimedBy: meId)]);
      // Web PanelSectionHeader: `flex-row items-baseline gap-2`, the number in
      // the mono meta hint ink.
      final title = _inHead(find.text('Tasks'));
      final number = _inHead(find.text('1'));
      expect(title, findsOneWidget);
      expect(number, findsOneWidget);
      final gap = t.getTopLeft(number).dx - t.getTopRight(title).dx;
      expect(gap, inInclusiveRange(8 - 0.5, 8 + 0.5));
      final row = t.widget<Row>(
        find
            .ancestor(of: number, matching: find.byType(Row))
            .evaluate()
            .map((e) => find.byWidget(e.widget))
            .firstWhere(
              (f) =>
                  find.descendant(of: f, matching: title).evaluate().isNotEmpty,
            ),
      );
      expect(row.crossAxisAlignment, CrossAxisAlignment.baseline);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('phone: the number is the bar\'s subtitle, under the name', (
      t,
    ) async {
      await _mount(
        t,
        size: const Size(390, 844),
        platform: TargetPlatform.android,
        tasks: [pageTask('a1', claimedBy: meId)],
      );
      final title = find.text('Tasks').first;
      final number = find.text('1').first;
      expect(
        t.getTopLeft(number).dy,
        greaterThanOrEqualTo(t.getBottomLeft(title).dy - 2),
      );
      expect(t.getTopLeft(number).dx, t.getTopLeft(title).dx);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('the failed and empty body is the plain canvas', () {
    for (final dark in [false, true]) {
      for (final failed in [true, false]) {
        testWidgets(
          '${dark ? 'dark' : 'light'} ${failed ? 'failed' : 'empty'}',
          (t) async {
            await _mount(t, dark: dark, countsFail: failed, tasks: const []);
            if (failed) {
              // Three attempts, a second and two seconds apart.
              for (var i = 0; i < 4; i++) {
                await t.pump(const Duration(seconds: 2));
                await settleTasks(t, rounds: 3);
              }
            } else {
              await t.tap(
                find.byKey(ValueKey('tasks-page-tab-${TasksPageTab.all.name}')),
              );
              await settleTasks(t);
            }
            final key = failed
                ? const ValueKey('tasks-page-failed')
                : const ValueKey('tasks-page-empty');
            expect(find.byKey(key), findsOneWidget);
            final canvas = RaftTokens.of(t.element(find.byKey(key)))
                .colors['layer-canvas'];
            final fill = t.widget<ColoredBox>(
              find
                  .descendant(
                    of: find.byKey(key),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            );
            expect(fill.color, canvas);
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }
  });
}
