import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_task_cache.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  for (final warm in [true, false]) {
    testWidgets(
      'task URL ${warm ? 'with a known message task shows it at the first frame' : 'without one waits for the real bucket'}',
      (t) async {
        t.view.physicalSize = const Size(1280, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await pageFixture(t, section: 'tasks');
        taskRoutes(api, modernTask);
        final bucket = Completer<Map>();
        final full = Completer<Map>();
        api.routes['GET /tasks/channel/c1'] = (_) => warm
            ? {
                'tasks': [modernTask],
              }
            : bucket.future;
        api.routes['GET /tasks/channel/c1/number/8'] = (_) => full.future;
        if (warm) {
          await t.runAsync(
            () => MessageTaskCache.of(w.client).revalidate(w, 'c1'),
          );
          expect(MessageTaskCache.of(w.client).tasks(w, 'c1'), isNotNull);
        }
        final buckets = api.calls
            .where((r) => r.path == '/tasks/channel/c1')
            .length;
        w.navigation.navigateTask(
          w.location.withQuery({'task': 'c1:task-parent'}),
          kind: RaftNavigationKind.replace,
        );
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: RaftFamily.elegant),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await t.pump();
        expect(find.byType(SourceTaskSurface), findsOneWidget);
        if (warm) {
          // First frame: the known task, no skeleton, no second bucket read.
          expect(find.text('Task #8'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('task-modal-title')),
            findsOneWidget,
          );
          expect(
            api.calls.where((r) => r.path == '/tasks/channel/c1').length,
            buckets,
          );
        } else {
          expect(find.text('Task #8'), findsNothing);
        }
        full.complete({'task': modernTask});
        bucket.complete({
          'tasks': [modernTask],
        });
        await flush(t);
        expect(find.text('Task #8'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(milliseconds: 300));
      },
    );
  }
}
