import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_ui/raft_ui.dart';

import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, mountPage;
import 'workspace_activity_activation_test.dart' show channelRow, message;

void main() {
  for (final origin in ['tasks', 'legacy-task', 'activity-task-chip']) {
    testWidgets(
      '$origin preserves task content and discussion draft across widths',
      (t) async {
        final activity = origin == 'activity-task-chip',
            legacy = origin == 'legacy-task';
        final (w, api) = await pageFixture(
          t,
          section: activity ? 'activity' : 'tasks',
        );
        final task = {
          ...modernTask,
          if (legacy) 'isLegacy': true,
          if (activity) 'messageId': 'first-channel',
        };
        taskRoutes(api, task);
        api.routes['GET /tasks/channel/c1'] = (r) => {
          'tasks':
              r.queryParameters['status'] == null ||
                  r.queryParameters['status'] == task['status']
              ? [task]
              : [],
        };
        api.routes['GET /announcements/active'] = (_) => {'announcements': []};
        api.routes['GET /messages/channel/c1'] = (_) => {
          'messages': activity ? [message('first-channel', 'c1')] : [],
        };
        if (activity) {
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [channelRow],
          };
          api.routes['GET /messages/context/first-channel'] = (_) => {
            'messages': [message('first-channel', 'c1')],
          };
        }
        await mountPage(t, w, false, width: 1440);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.pump();
        });
        if (activity) {
          await t.tap(find.byKey(const ValueKey('activity-channel-c1')));
          await flush(t);
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('message-first-channel')),
            findsOneWidget,
            reason: 'loaded Activity channel before opening its task',
          );
          await t.tap(find.byKey(const ValueKey('message-task-first-channel')));
        } else {
          await t.tap(find.text('Scoped actual task'));
        }
        await flush(t);
        await t.pumpAndSettle();
        final surface = find.byType(SourceTaskSurface);
        expect(surface, findsOneWidget);
        expect(
          find.descendant(
            of: surface,
            matching: find.text('Scoped actual task'),
          ),
          findsOneWidget,
        );
        final anchor = (w.location.task ?? w.location.legacyTask).toString();
        final editor = find.descendant(
          of: find.descendant(of: surface, matching: find.byType(RaftComposer)),
          matching: find.byType(TextField),
        );
        if (!legacy) {
          expect(editor, findsOneWidget);
          await t.enterText(editor, 'Preserve this task discussion draft');
          await flush(t);
          expect(
            t.widget<TextField>(editor).controller!.text,
            'Preserve this task discussion draft',
            reason: 'the draft must exist before resizing',
          );
        }
        for (final size in [
          const Size(390, 844),
          const Size(1440, 900),
          const Size(767, 900),
        ]) {
          t.view.physicalSize = size;
          await t.pumpAndSettle();
          await flush(t);
          await t.pumpAndSettle();
          expect((w.location.task ?? w.location.legacyTask).toString(), anchor);
          expect(surface, findsOneWidget);
          expect(
            find.descendant(
              of: surface,
              matching: find.text('Scoped actual task'),
            ),
            findsOneWidget,
          );
          if (!legacy) {
            expect(
              t.widget<TextField>(editor).controller!.text,
              'Preserve this task discussion draft',
              reason: 'discussion draft at $size',
            );
          }
          expect(t.takeException(), isNull);
        }
        if (origin == 'tasks') {
          await t.binding.handlePopRoute();
        } else {
          await t.tap(find.byTooltip('Close Task'));
        }
        await flush(t);
        await t.pumpAndSettle();
        expect(surface, findsNothing);
        if (activity) {
          // The current phone Back contract returns to the Activity list.
          // Exact cross-layout history parity is tracked separately; the
          // accepted conversation data must remain available on reopening.
          expect(w.messageDomain.visibleIds['c1'], contains('first-channel'));
          expect(
            find.byKey(const ValueKey('activity-channel-c1')),
            findsOneWidget,
          );
          await t.tap(find.byKey(const ValueKey('activity-channel-c1')));
          await flush(t);
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('message-task-first-channel')));
        } else {
          expect(find.text('Scoped actual task'), findsOneWidget);
          await t.tap(find.text('Scoped actual task'));
        }
        await flush(t);
        await t.pumpAndSettle();
        expect(surface, findsOneWidget);
        if (!legacy) {
          expect(
            t.widget<TextField>(editor).controller!.text,
            'Preserve this task discussion draft',
          );
        }
      },
    );
  }
}
