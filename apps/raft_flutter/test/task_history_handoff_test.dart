import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;
import 'task_surface_test.dart' show taskRoutes, modernTask, taskHost, flush;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '[K10d] $family/$dark/$width displayed History accepts pointer during reply handoff',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = (await t.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          taskRoutes(api, modernTask);
          final replies = Completer<dynamic>();
          api.routes['GET /messages/channel/task-thread'] = (_) =>
              replies.future;
          api.routes['GET /tasks/task-1/history'] = (_) => {
            'events': [
              {
                'eventType': 'created',
                'actorName': 'Alice',
                'createdAt': '2026-10-10T00:00:00Z',
              },
            ],
          };
          await t.pumpWidget(taskHost(w, family, dark));
          await flush(t);
          await t.tap(find.text('Scoped actual task'));
          await flush(t);
          final history = find.byKey(const ValueKey('task-properties-history'));
          expect(history.hitTestable(), findsOneWidget);
          final pointer = t.getCenter(history);
          final owner = t
              .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
              .owner;
          await t.runAsync(() async {
            replies.complete({
              'messages': [row('first-reply', 'task-thread', 1)],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          for (var frame = 0; frame < 6; frame++) {
            await t.pump(const Duration(milliseconds: 16));
            expect(
              history,
              findsOneWidget,
              reason: 'Task properties have one mounted owner in frame $frame.',
            );
            expect(
              history.hitTestable(),
              findsOneWidget,
              reason:
                  'The painted task properties remain interactive in frame $frame.',
            );
            if (frame == 1) {
              await t.tapAt(pointer);
            }
          }
          await flush(t);
          expect(find.text('Created task'), findsOneWidget);
          expect(owner.discussion!.replies.single.id, 'first-reply');
          expect(w.client.user!.id, 'alice');
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
