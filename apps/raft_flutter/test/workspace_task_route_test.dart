import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '[K10b URL] cold modern real bucket, independent side and narrow Back $family/$dark/$width',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await pageFixture(t, section: 'tasks');
          taskRoutes(api, modernTask);
          final bucket = Completer<Map>();
          final lookup = Completer<Map>();
          final parent = Completer<Map>();
          final replies = Completer<Map>();
          api.routes['GET /tasks/channel/c1'] = (_) => bucket.future;
          api.routes['GET /channels/c1/threads/task-parent'] = (_) =>
              lookup.future;
          api.routes['GET /messages/context/task-parent'] = (_) =>
              parent.future;
          api.routes['GET /messages/channel/task-thread'] = (_) =>
              replies.future;
          w.threadParent = RaftMessage(row('old-parent', 'c1', 1));
          w.threadChannelId = 'old-side';
          w.threadLoading = false;
          w.drafts[w.draftScope()!] = 'Main draft survives';
          w.drafts[w.draftScope(thread: true)!] = 'Side draft survives';
          final origin = w.location.withQuery({
            'thread': 'c1:old-parent',
            'kept': 'yes',
          });
          w.navigation.navigate(origin, kind: RaftNavigationKind.replace);
          w.navigation.navigateTask(
            origin.withQuery({'task': 'c1:task-parent'}),
            kind: RaftNavigationKind.replace,
          );
          final mainRevision = w.navigationRevision;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: WorkspaceView(
                controller: w,
                appearance: RaftAppearance(light: family),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          );
          await flush(t);
          expect(find.byType(SourceTaskSurface), findsOneWidget);
          expect(find.byKey(const ValueKey('task-modal-title')), findsNothing);
          expect(find.text('Task #8'), findsNothing);
          expect(w.location.task!.itemId, 'task-parent');
          expect(w.navigationRevision, mainRevision);
          expect(w.threadChannelId, 'old-side');
          expect(
            api.calls.where((r) => r.path == '/tasks/channel/c1'),
            hasLength(1),
          );
          bucket.complete({
            'tasks': [modernTask],
          });
          lookup.complete({'threadChannelId': 'task-thread'});
          await flush(t);
          expect(
            find.byKey(const ValueKey('task-modal-title')),
            findsOneWidget,
          );
          expect(find.text('Task #8'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('task-properties-history')),
            findsOneWidget,
          );
          expect(w.threadChannelId, 'old-side');
          expect(w.navigationRevision, mainRevision);
          if (width < 768) {
            await t.tap(find.byTooltip('Close task'));
          } else {
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await flush(t);
          expect(find.byType(SourceTaskSurface), findsNothing);
          expect(w.location.query('task'), isNull);
          expect(w.location.thread!.itemId, 'old-parent');
          expect(w.location.query('kept'), 'yes');
          expect(w.navigationRevision, mainRevision);
          expect(w.drafts[w.draftScope()], 'Main draft survives');
          expect(w.drafts[w.draftScope(thread: true)], 'Side draft survives');
          parent.complete({
            'messages': [row('task-parent', 'c1', 2)],
          });
          replies.complete({
            'messages': [row('late-reply', 'task-thread', 3)],
          });
          await flush(t);
          expect(find.byType(SourceTaskSurface), findsNothing);
          expect(
            api.calls.where((r) => r.path == '/channels/task-thread/read'),
            isEmpty,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    }
    testWidgets(
      '[K10b URL] pending legacy preserves URI, hydrates only explicit legacy and never requests a thread $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await pageFixture(t, section: 'tasks');
        taskRoutes(api, modernTask);
        final bucket = Completer<Map>();
        api.routes['GET /tasks/channel/c1'] = (_) => bucket.future;
        w.navigation.navigateTask(
          w.location.withQuery({'legacyTask': 'c1:legacy-id'}),
          kind: RaftNavigationKind.replace,
        );
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await flush(t);
        expect(w.location.query('legacyTask'), 'c1:legacy-id');
        expect(find.byType(SourceTaskSurface), findsNothing);
        bucket.complete({
          'tasks': [
            modernTask,
            {...modernTask, 'id': 'legacy-id', 'isLegacy': true},
          ],
        });
        await flush(t);
        expect(find.byKey(const ValueKey('legacy-task-panel')), findsOneWidget);
        expect(find.text('Task #8 · LEGACY'), findsOneWidget);
        expect(
          api.calls.where(
            (r) =>
                r.path.contains('/history') ||
                r.path.contains('/threads/') ||
                r.path.contains('/messages/'),
          ),
          isEmpty,
        );
        await t.tap(find.byTooltip('Close task'));
        await flush(t);
        expect(w.location.query('legacyTask'), isNull);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '[K10b URL] role revocation retires real cold task and rejects late bucket $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await pageFixture(t, section: 'tasks');
        taskRoutes(api, modernTask);
        final bucket = Completer<Map>();
        api.routes['GET /tasks/channel/c1'] = (_) => bucket.future;
        w.navigation.navigateTask(
          w.location.withQuery({'task': 'c1:task-parent'}),
          kind: RaftNavigationKind.replace,
        );
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await flush(t);
        final retired = t
            .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
            .owner;
        w.server = RaftRecord({...w.server!.json, 'role': 'guest'});
        w.notifyListeners();
        await flush(t);
        expect(retired.closed, isTrue);
        expect(find.byType(SourceTaskSurface), findsNothing);
        bucket.complete({
          'tasks': [modernTask],
        });
        await flush(t);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(find.byKey(const ValueKey('task-modal-title')), findsNothing);
        expect(
          api.calls.where(
            (r) =>
                r.path.endsWith('/history') ||
                r.path == '/channels/task-thread/read',
          ),
          isEmpty,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(milliseconds: 300));
      },
    );
    for (final lateFails in [false, true]) {
      testWidgets(
        '[K10b URL] actual board activation then Back/new task rejects old ${lateFails ? 'error' : 'success'} without retiring main pending context $family/$dark',
        (t) async {
          t.view.physicalSize = const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await pageFixture(t, section: 'tasks');
          taskRoutes(api, modernTask);
          final second = {
            ...modernTask,
            'id': 'task-2',
            'taskNumber': 9,
            'title': 'Second real task',
            'messageId': 'task-parent-2',
            'threadChannelId': 'task-thread-2',
          };
          api.routes['GET /tasks/server'] = (_) => {
            'tasks': [modernTask, second],
            'next_cursor': null,
          };
          final oldDetail = Completer<Map>();
          api.routes['GET /tasks/channel/c1/number/8'] = (_) =>
              oldDetail.future;
          api.routes['GET /tasks/channel/c1/number/9'] = (_) => {
            'task': second,
          };
          api.routes['GET /tasks/task-2/history'] = (_) => {'events': []};
          api.routes['GET /messages/context/task-parent-2'] = (_) => {
            'messages': [row('task-parent-2', 'c1', 2)],
          };
          api.routes['GET /messages/channel/task-thread-2'] = (_) => {
            'messages': [],
          };
          final mainContext = Completer<Map>();
          api.routes['GET /messages/context/pending-main'] = (_) =>
              mainContext.future;
          final pending = w.jumpToMessage(
            'c1',
            'pending-main',
            navigate: false,
          );
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: WorkspaceView(
                controller: w,
                appearance: RaftAppearance(light: family),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          );
          await flush(t);
          final mainRevision = w.navigationRevision;
          final historyIndex = w.navigation.index;
          await t.tap(find.text('Scoped actual task'));
          await flush(t);
          expect(w.location.query('task'), 'c1:task-parent');
          expect(w.navigation.index, historyIndex + 1);
          expect(w.navigationRevision, mainRevision);
          final retired = t
              .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
              .owner;
          await t.tap(find.byTooltip('Close task'));
          await flush(t);
          expect(retired.closed, isTrue);
          expect(w.navigation.index, historyIndex);
          await t.tap(find.text('Second real task'));
          await flush(t);
          expect(w.location.query('task'), 'c1:task-parent-2');
          final current = t
              .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
              .owner;
          expect(current.task['id'], 'task-2');
          if (lateFails) {
            oldDetail.completeError(StateError('retired detail failure'));
          } else {
            oldDetail.complete({'task': modernTask});
          }
          mainContext.complete({
            'messages': [row('pending-main', 'c1', 4)],
          });
          await flush(t);
          await t.runAsync(() => pending);
          await flush(t);
          expect(current.task['id'], 'task-2');
          expect(w.messages.map((m) => m.id), contains('pending-main'));
          expect(w.navigationRevision, mainRevision);
          await t.tap(find.byTooltip('Close task'));
          await flush(t);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    }
  }
}
