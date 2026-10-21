import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'task_surface_test.dart' show flush, modernTask, taskHost, taskRoutes;

// The discussion's deferred initial-scroll timer checks `mounted` after
// disposal; drain teardown after the visible-state assertions.
Future<void> drain(WidgetTester t) async {
  await t.sendKeyEvent(LogicalKeyboardKey.escape);
  await flush(t);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final role in ['owner', 'member']) {
    testWidgets(
      'the detail status picker claims an unassigned todo task as $role',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture(role)))!;
        addTearDown(w.dispose);
        final task = {...modernTask};
        taskRoutes(api, task);
        api.routes['PATCH /tasks/task-1/claim'] = (r) {
          expect(r.data, isNull);
          task
            ..['status'] = 'in_progress'
            ..['claimedById'] = 'alice'
            ..['claimedByType'] = 'user'
            ..['claimedByName'] = 'Alice';
          return {'task': task};
        };
        await t.pumpWidget(taskHost(w, RaftFamily.elegant, false));
        await flush(t);
        await t.tap(find.text('Scoped actual task'));
        await flush(t);
        await t.tap(find.byKey(const ValueKey('task-properties-status')));
        await flush(t);
        await t.tap(
          find.descendant(
            of: find.byType(RaftInlineBadgeMenu),
            matching: find.byKey(const ValueKey('in_progress')),
          ),
        );
        await flush(t);
        final writes = api.calls.where((r) => r.method == 'PATCH').toList();
        expect(writes.map((r) => r.path), ['/tasks/task-1/claim']);
        expect(find.text('@Alice'), findsWidgets);
        expect(
          t
              .widget<RaftInlineBadgeEditor>(
                find.descendant(
                  of: find.byType(SourceTaskSurface),
                  matching: find.byKey(
                    const ValueKey('task-properties-status'),
                  ),
                ),
              )
              .selectedId,
          'in_progress',
        );
        expect(t.takeException(), isNull);
        await drain(t);
      },
    );
  }

  testWidgets('a held todo task still uses the status route in the detail', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    final task = {
      ...modernTask,
      'claimedById': 'bob',
      'claimedByType': 'user',
      'claimedByName': 'Bob',
    };
    taskRoutes(api, task);
    api.routes['PATCH /tasks/task-1/status'] = (r) {
      expect(r.data, {'status': 'in_progress'});
      return {
        'task': {...task, 'status': 'in_progress'},
      };
    };
    await t.pumpWidget(taskHost(w, RaftFamily.elegant, false));
    await flush(t);
    await t.tap(find.text('Scoped actual task'));
    await flush(t);
    await t.tap(find.byKey(const ValueKey('task-properties-status')));
    await flush(t);
    await t.tap(
      find.descendant(
        of: find.byType(RaftInlineBadgeMenu),
        matching: find.byKey(const ValueKey('in_progress')),
      ),
    );
    await flush(t);
    expect(api.calls.where((r) => r.method == 'PATCH').map((r) => r.path), [
      '/tasks/task-1/status',
    ]);
    await drain(t);
  });
}
