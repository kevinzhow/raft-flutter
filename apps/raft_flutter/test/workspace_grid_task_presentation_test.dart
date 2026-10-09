import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_grid_view.dart';
import 'package:raft_flutter/features/workspace_task_host.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_task_parent_hydration_test.dart' show parentFixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K10b grid container] actual mode/resize retains hidden task owner and real drafts without invented channel tabs $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(1400, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await parentFixture(t);
        taskRoutes(api, modernTask);
        final bucket = Completer<Map>(), detail = Completer<Map>();
        final context = Completer<Map>(), replies = Completer<Map>();
        api.routes['GET /messages/channel/c1'] = (_) => {
          'messages': [row('accepted-main', 'c1', 1)],
        };
        api.routes['GET /tasks/channel/c1'] = (_) => bucket.future;
        api.routes['GET /tasks/channel/c1/number/8'] = (_) => detail.future;
        api.routes['GET /channels/c1/threads/task-parent'] = (_) => {
          'threadChannelId': 'task-thread',
        };
        api.routes['GET /messages/context/task-parent'] = (_) => context.future;
        api.routes['GET /messages/channel/task-thread'] = (_) => replies.future;
        w.setSection('chat');
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
        final classicEditor = find.descendant(
          of: find.byType(RaftComposer),
          matching: find.byType(TextField),
        );
        await t.enterText(classicEditor, 'Retained actual channel draft');
        final classic = t.widget<TextField>(classicEditor).controller!;
        classic.selection = const TextSelection.collapsed(offset: 4);
        final classicState = t.state(classicEditor);
        await t.tap(find.byKey(const Key('workspace-mode-toggle')));
        await flush(t);
        final grid = find.byType(WorkspaceGridView);
        expect(grid, findsOneWidget);
        final gridConversation = find.descendant(
          of: grid,
          matching: find.byType(ConversationPanel),
        );
        expect(
          t.widget<ConversationPanel>(gridConversation).hideHeader,
          isTrue,
        );
        expect(
          find.descendant(
            of: grid,
            matching: find.byKey(const Key('conversation-tabs')),
          ),
          findsNothing,
        );
        final gridState = t.state<WorkspaceGridViewState>(grid);
        final channelChild = gridState.sessions.controllers['c1']!;
        final editor = find.descendant(
          of: grid,
          matching: find.byType(TextField),
        );
        await t.enterText(editor, 'Retained independent grid draft');
        final gridEditor = t.widget<TextField>(editor).controller!;
        gridEditor.selection = const TextSelection.collapsed(offset: 5);
        final gridEditorState = t.state(editor);
        final mainRevision = w.navigationRevision;
        final clientGeneration = w.client.generation;
        w.navigation.navigateTask(
          w.location.withQuery({'task': 'c1:task-parent'}),
          kind: RaftNavigationKind.push,
        );
        w.notifyListeners();
        await flush(t);
        final taskRevision = w.navigation.taskRevision;
        expect(
          t.widget<WorkspaceTaskHost>(find.byType(WorkspaceTaskHost)).presented,
          isFalse,
        );
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(find.byKey(const ValueKey('task-modal-title')), findsNothing);
        bucket.complete({
          'tasks': [modernTask],
        });
        await flush(t);
        detail.complete({'task': modernTask});
        context.complete({
          'messages': [row('task-parent', 'c1', 2)],
        });
        replies.complete({
          'messages': [row('task-reply', 'task-thread', 1)],
        });
        await flush(t);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(w.location.task!.itemId, 'task-parent');
        expect(w.navigationRevision, mainRevision);
        expect(w.navigation.taskRevision, taskRevision);
        expect(
          api.calls.where((r) => r.path == '/channels/task-thread/read'),
          isEmpty,
        );
        expect(t.widget<TextField>(editor).controller, same(gridEditor));
        expect(gridEditor.text, 'Retained independent grid draft');
        expect(gridEditor.selection.baseOffset, 5);
        t.view.physicalSize = const Size(1023, 900);
        await flush(t);
        final surface = find.byType(SourceTaskSurface);
        expect(surface, findsOneWidget);
        final owner = t.widget<SourceTaskSurface>(surface).owner;
        final discussion = owner.discussion!;
        expect(owner.task['id'], modernTask['id']);
        final title = find
            .byKey(const ValueKey('task-modal-title'))
            .hitTestable();
        for (
          var frame = 0;
          frame < 40 && title.evaluate().length != 1;
          frame++
        ) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(title, findsOneWidget);
        final replyEditor = find.descendant(
          of: surface,
          matching: find.byType(TextField),
        );
        await t.enterText(replyEditor, 'Retained real task draft');
        t.view.physicalSize = const Size(1400, 900);
        await flush(t);
        expect(surface, findsNothing);
        expect(discussion.foreground, isFalse);
        expect(owner.current, isTrue);
        expect(w.location.task!.itemId, 'task-parent');
        expect(t.state(editor), same(gridEditorState));
        expect(gridState.sessions.controllers['c1'], same(channelChild));
        expect(gridEditor.text, 'Retained independent grid draft');
        expect(gridEditor.selection.baseOffset, 5);
        t.view.physicalSize = const Size(1023, 900);
        await flush(t);
        expect(t.widget<SourceTaskSurface>(surface).owner, same(owner));
        expect(owner.discussion, same(discussion));
        expect(
          t.widget<TextField>(replyEditor).controller!.text,
          'Retained real task draft',
        );
        expect(
          api.calls.where((r) => r.path == '/tasks/channel/c1/number/8'),
          hasLength(1),
        );
        expect(w.client.generation, clientGeneration);
        expect(w.navigationRevision, mainRevision);
        await t.tap(find.byTooltip('Close task'));
        await flush(t);
        expect(surface, findsNothing);
        expect(w.location.task, isNull);
        expect(owner.closed, isTrue);
        expect(
          t.state(classicEditor),
          isNot(same(classicState)),
        ); // changed grid draft intentionally hydrates classic
        expect(classic.text, 'Retained actual channel draft');
        expect(
          t.widget<TextField>(classicEditor).controller!.text,
          'Retained independent grid draft',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await flush(t);
      },
    );
    testWidgets(
      '[K10b grid container] hidden task retires on server authority change before late bucket acceptance $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(1400, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await parentFixture(t);
        taskRoutes(api, modernTask);
        final bucket = Completer<Map>();
        api.routes['GET /tasks/channel/c1'] = (_) => bucket.future;
        w.setSection('chat');
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
        await t.tap(find.byKey(const Key('workspace-mode-toggle')));
        await flush(t);
        w.navigation.navigateTask(
          w.location.withQuery({'task': 'c1:task-parent'}),
          kind: RaftNavigationKind.push,
        );
        w.notifyListeners();
        await flush(t);
        expect(find.byType(SourceTaskSurface), findsNothing);
        w.client.selectServer('other');
        w.notifyListeners();
        await flush(t);
        bucket.complete({
          'tasks': [modernTask],
        });
        await flush(t);
        t.view.physicalSize = const Size(390, 900);
        await flush(t);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(
          api.calls.where(
            (r) =>
                r.path.endsWith('/number/8') ||
                r.path == '/channels/task-thread/read',
          ),
          isEmpty,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await flush(t);
      },
    );
    for (final section in ['search', 'activity']) {
      testWidgets(
        '[K10b grid container] Source content-route early return retains global task presentation $section/$family/$dark',
        (t) async {
          // MainLayout1377–1391 returns content overlays before1394's guard.
          // This seeds that retained global identity; it does not claim a
          // Source grid task opener or a visible channel Tasks tab.
          t.view.physicalSize = const Size(1400, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await parentFixture(t);
          taskRoutes(api, modernTask);
          api.routes['GET /tasks/channel/c1'] = (_) => {
            'tasks': [modernTask],
          };
          w.setSection('chat');
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
          await t.tap(find.byKey(const Key('workspace-mode-toggle')));
          await flush(t);
          w.setSection(section);
          w.navigation.navigateTask(
            w.location.withQuery({'task': 'c1:task-parent'}),
            kind: RaftNavigationKind.replace,
          );
          w.notifyListeners();
          await flush(t);
          expect(find.byType(WorkspaceGridView), findsOneWidget);
          expect(
            t
                .widget<WorkspaceTaskHost>(find.byType(WorkspaceTaskHost))
                .presented,
            isTrue,
          );
          expect(find.byType(SourceTaskSurface), findsOneWidget);
          expect(w.location.task!.itemId, 'task-parent');
          await t.tap(find.byTooltip('Close task'));
          await flush(t);
          expect(find.byType(SourceTaskSurface), findsNothing);
          expect(w.location.task, isNull);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await flush(t);
        },
      );
    }
  }
}
