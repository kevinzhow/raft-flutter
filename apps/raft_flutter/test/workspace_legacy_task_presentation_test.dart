import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_task_parent_hydration_test.dart' show parentFixture;
import 'parity/parity_harness.dart' show loadParityFonts;

final legacyTask = <String, dynamic>{
  ...modernTask,
  'id': 'legacy-215',
  'taskNumber': 215,
  'title': 'Read-only task fixture',
  'isLegacy': true,
  'messageId': null,
  'threadChannelId': null,
};

void main() {
  // Real product fonts matter at the supported320px minimum. Ahem substitutes
  // 12px square glyphs and falsely wraps the short Task# legacy subtitle.
  setUpAll(loadParityFonts);
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 800.0, 1280.0]) {
      for (final tasksRoute in [false, true]) {
        testWidgets(
          '[K10b legacy presentation] Source ${tasksRoute ? '/tasks modal' : 'channel side'} real card and Close $family/$dark/$width',
          (t) async {
            // MainLayout1407–1417 + LegacyTaskPanel70–166; mounted Source
            // legacy-task-source-v1 records the real opener and bounds.
            t.view.physicalSize = Size(width, 900);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final (w, api) = await parentFixture(t);
            w.section = tasksRoute ? 'tasks' : 'chat';
            taskRoutes(api, legacyTask);
            api.routes['GET /tasks/channel/c1'] = (r) => {
              'tasks':
                  r.queryParameters['status'] == null ||
                      r.queryParameters['status'] == 'todo'
                  ? [legacyTask]
                  : [],
            };
            w.ledger.ingest([
              row('accepted-main', 'c1', 1),
            ], expectedGeneration: w.ledger.generation);
            w.drafts[w.draftScope()!] = 'Existing accepted main draft';
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
            final workspaceState = t.state(find.byType(WorkspaceView));
            final adaptiveState = t.state(find.byType(RaftAdaptiveWorkspace));
            if (!tasksRoute) {
              final tabs = find.byKey(const Key('conversation-tabs'));
              await t.tap(
                find.descendant(of: tabs, matching: find.text('Tasks')),
              );
              await flush(t);
            }
            final revision = w.navigationRevision;
            await t.tap(find.text('Read-only task fixture'));
            await flush(t);
            final panel = find.byKey(const ValueKey('legacy-task-panel'));
            expect(panel, findsOneWidget);
            final rect = t.getRect(panel);
            if (tasksRoute && width >= 768) {
              expect(rect.size, const Size(760, 702));
              expect(rect.left, (width - 760) / 2);
              expect(rect.top, 99);
            } else if (!tasksRoute && width >= 1024) {
              expect(rect, Rect.fromLTWH(width - 380, 0, 380, 900));
            } else {
              final left = width < 768
                  ? 0.0
                  : (family == RaftFamily.brutal ? 304.0 : 296.0);
              final height = tasksRoute && family == RaftFamily.brutal
                  ? 847.0
                  : 900.0;
              expect(rect, Rect.fromLTWH(left, 0, width - left, height));
            }
            expect(
              find.descendant(
                of: panel,
                matching: find.byType(RaftInlineBadgeEditor),
              ),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('task-properties-history')),
              findsNothing,
            );
            expect(
              t
                  .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
                  .owner
                  .discussion,
              isNull,
            );
            final docked = !tasksRoute && width >= 1024;
            expect(
              t
                  .widget<RaftAdaptiveWorkspace>(
                    find.byType(RaftAdaptiveWorkspace),
                  )
                  .trailingExtent,
              docked ? 380 : 0,
            );
            expect(t.state(find.byType(WorkspaceView)), same(workspaceState));
            expect(
              t.state(find.byType(RaftAdaptiveWorkspace)),
              same(adaptiveState),
            );
            final closeKey = tasksRoute && width >= 768 || docked
                ? 'task-close'
                : 'task-back';
            expect(find.byKey(ValueKey(closeKey)), findsOneWidget);
            final index = w.navigation.index;
            await t.tap(find.byKey(ValueKey(closeKey)));
            await flush(t);
            expect(panel, findsNothing);
            expect(w.location.legacyTask, isNull);
            expect(
              w.navigation.index,
              index,
              reason:
                  'Source back chevron closes its legacy slot; no browser Back.',
            );
            expect(w.navigationRevision, revision);
            expect(w.channel!.id, 'c1');
            expect(w.drafts[w.draftScope()], 'Existing accepted main draft');
            expect(
              t.state(find.byType(RaftAdaptiveWorkspace)),
              same(adaptiveState),
            );
            expect(
              api.calls.where(
                (r) =>
                    r.path.contains('/threads/') ||
                    r.path.endsWith('/history') ||
                    r.path.startsWith('/messages/context/'),
              ),
              isEmpty,
            );
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox.shrink());
            await t.pump(const Duration(milliseconds: 300));
          },
        );
      }
    }
    testWidgets(
      '[K10b legacy presentation] real drag/Escape, reopen and viewport transitions preserve accepted editor $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(1280, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await parentFixture(t);
        w.section = 'chat';
        taskRoutes(api, legacyTask);
        api.routes['GET /tasks/channel/c1'] = (r) => {
          'tasks':
              r.queryParameters['status'] == null ||
                  r.queryParameters['status'] == 'todo'
              ? [legacyTask]
              : [],
        };
        w.ledger.ingest([
          row('accepted-main', 'c1', 1),
        ], expectedGeneration: w.ledger.generation);
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
        final composer = find.descendant(
          of: find.byType(ConversationPanel),
          matching: find.byType(RaftComposer),
        );
        final editor = find.descendant(
          of: composer,
          matching: find.byType(TextField),
        );
        await t.enterText(editor, 'Actual legacy panel draft');
        final editorController = t.widget<TextField>(editor).controller!;
        editorController.selection = const TextSelection.collapsed(offset: 7);
        final composerState = t.state(composer);
        final adaptiveState = t.state(find.byType(RaftAdaptiveWorkspace));
        await t.tap(
          find.descendant(
            of: find.byKey(const Key('conversation-tabs')),
            matching: find.text('Tasks'),
          ),
        );
        await flush(t);
        await t.tap(find.text('Read-only task fixture'));
        await flush(t);
        final surface = find.byType(SourceTaskSurface);
        var owner = t.widget<SourceTaskSurface>(surface).owner;
        final handle = find.byKey(const Key('legacy-task-resize-handle'));
        await t.drag(handle, const Offset(-60, 0));
        await flush(t);
        expect(
          t.getSize(find.byKey(const ValueKey('legacy-task-panel'))).width,
          440,
        );
        final prefs = (await t.runAsync(SharedPreferences.getInstance))!;
        expect(prefs.getDouble('slock:legacyTaskPanelWidth'), 440);
        final historyIndex = w.navigation.index;
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await flush(t);
        expect(surface, findsNothing);
        expect(owner.closed, isTrue);
        expect(w.navigation.index, historyIndex);
        await t.tap(find.text('Read-only task fixture'));
        await flush(t);
        owner = t.widget<SourceTaskSurface>(surface).owner;
        for (final width in [800.0, 390.0, 1280.0]) {
          t.view.physicalSize = Size(width, 900);
          await flush(t);
          expect(t.widget<SourceTaskSurface>(surface).owner, same(owner));
          expect(
            t.state(find.byType(RaftAdaptiveWorkspace)),
            same(adaptiveState),
          );
          final rect = t.getRect(
            find.byKey(const ValueKey('legacy-task-panel')),
          );
          expect(
            rect.width,
            width == 1280
                ? 440
                : width == 390
                ? 390
                : family == RaftFamily.brutal
                ? 496
                : 504,
          );
          expect(
            find.byKey(const ValueKey('task-back')),
            width < 1024 ? findsOneWidget : findsNothing,
          );
          expect(handle, width >= 1024 ? findsOneWidget : findsNothing);
          expect(editorController.text, 'Actual legacy panel draft');
          expect(editorController.selection.baseOffset, 7);
        }
        await t.tap(find.byKey(const ValueKey('task-close')));
        await flush(t);
        expect(owner.closed, isTrue);
        await t.tap(
          find.descendant(
            of: find.byKey(const Key('conversation-tabs')),
            matching: find.text('Chat'),
          ),
        );
        await flush(t);
        expect(t.state(composer), same(composerState));
        expect(t.widget<TextField>(editor).controller, same(editorController));
        expect(editorController.text, 'Actual legacy panel draft');
        expect(editorController.selection.baseOffset, 7);
        await t.tap(
          find.descendant(
            of: find.byKey(const Key('conversation-tabs')),
            matching: find.text('Tasks'),
          ),
        );
        await flush(t);
        await t.tap(find.text('Read-only task fixture'));
        await flush(t);
        expect(
          t.getSize(find.byKey(const ValueKey('legacy-task-panel'))).width,
          440,
        );
        await t.drag(handle, const Offset(-1000, 0));
        await flush(t);
        expect(
          t.takeException(),
          isNull,
          reason: 'Legacy dock at Source maximum560',
        );
        expect(
          t.getSize(find.byKey(const ValueKey('legacy-task-panel'))).width,
          560,
        );
        await t.drag(handle, const Offset(1000, 0));
        await flush(t);
        expect(
          t.takeException(),
          isNull,
          reason: 'Legacy dock at Source minimum320',
        );
        expect(
          t.getSize(find.byKey(const ValueKey('legacy-task-panel'))).width,
          320,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await flush(t);
        expect(surface, findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(milliseconds: 300));
      },
    );
    for (final change in ['close', 'server', 'principal', 'permission']) {
      testWidgets(
        '[K10b legacy presentation] pending bucket cannot publish after $change $family/$dark',
        (t) async {
          t.view.physicalSize = const Size(1280, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await parentFixture(t);
          taskRoutes(api, legacyTask);
          final held = Completer<Map>();
          var reads = 0;
          api.routes['GET /tasks/channel/c1'] = (_) =>
              ++reads == 1 ? held.future : {'tasks': []};
          w.navigation.navigateTask(
            w.location.withQuery({'legacyTask': 'c1:legacy-215'}),
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
          expect(find.byKey(const ValueKey('legacy-task-panel')), findsNothing);
          expect(
            t
                .widget<RaftAdaptiveWorkspace>(
                  find.byType(RaftAdaptiveWorkspace),
                )
                .trailingExtent,
            0,
          );
          switch (change) {
            case 'close':
              w.navigation.navigateTask(
                w.location.withQuery({'legacyTask': null}),
                kind: RaftNavigationKind.replace,
              );
            case 'server':
              w.client.selectServer('other');
            case 'principal':
              w.client.user = RaftRecord({'id': 'other-user'});
            case 'permission':
              w.server = RaftRecord({...w.server!.json, 'role': 'guest'});
          }
          w.notifyListeners();
          await flush(t);
          held.complete({
            'tasks': [legacyTask],
          });
          await flush(t);
          expect(find.byKey(const ValueKey('legacy-task-panel')), findsNothing);
          expect(
            t
                .widget<RaftAdaptiveWorkspace>(
                  find.byType(RaftAdaptiveWorkspace),
                )
                .trailingExtent,
            0,
          );
          expect(
            api.calls.where(
              (r) =>
                  r.path.contains('/threads/') || r.path.endsWith('/history'),
            ),
            isEmpty,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    }
    testWidgets(
      '[K10b legacy presentation] accepted dock retires immediately on role denial $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(1280, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await parentFixture(t);
        w.section = 'chat';
        taskRoutes(api, legacyTask);
        api.routes['GET /tasks/channel/c1'] = (_) => {
          'tasks': [legacyTask],
        };
        w.navigation.navigateTask(
          w.location.withQuery({'legacyTask': 'c1:legacy-215'}),
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
        final owner = t
            .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
            .owner;
        expect(find.byKey(const ValueKey('legacy-task-panel')), findsOneWidget);
        w.server = RaftRecord({...w.server!.json, 'role': 'guest'});
        w.notifyListeners();
        await flush(t);
        expect(owner.closed, isTrue);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(
          find.byKey(const Key('legacy-task-resize-handle')),
          findsNothing,
        );
        expect(
          t
              .widget<RaftAdaptiveWorkspace>(find.byType(RaftAdaptiveWorkspace))
              .trailingExtent,
          0,
        );
        expect(
          api.calls.where(
            (r) => r.path.endsWith('/history') || r.path.contains('/threads/'),
          ),
          isEmpty,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(milliseconds: 300));
      },
    );
    testWidgets(
      '[K10b legacy presentation] higher-priority profile hides dock and preserves owner on return $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(1280, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await parentFixture(t);
        w.section = 'chat';
        taskRoutes(api, legacyTask);
        api.routes['GET /tasks/channel/c1'] = (_) => {
          'tasks': [legacyTask],
        };
        w.navigation.navigateTask(
          w.location.withQuery({'legacyTask': 'c1:legacy-215'}),
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
        final owner = t
            .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
            .owner;
        final revision = w.navigation.taskRevision;
        w.navigation.navigate(
          w.location.withQuery({'profile': 'human:alice'}),
          kind: RaftNavigationKind.replace,
        );
        w.notifyListeners();
        await flush(t);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(owner.closed, isFalse);
        expect(w.navigation.taskRevision, revision);
        expect(
          t
              .widget<RaftAdaptiveWorkspace>(find.byType(RaftAdaptiveWorkspace))
              .trailingExtent,
          0,
        );
        w.navigation.navigate(
          w.location.withQuery({'profile': null}),
          kind: RaftNavigationKind.replace,
        );
        w.notifyListeners();
        await flush(t);
        expect(
          t.widget<SourceTaskSurface>(find.byType(SourceTaskSurface)).owner,
          same(owner),
        );
        expect(
          t
              .widget<RaftAdaptiveWorkspace>(find.byType(RaftAdaptiveWorkspace))
              .trailingExtent,
          380,
        );
        expect(
          api.calls.where((r) => r.path == '/tasks/channel/c1'),
          hasLength(1),
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(milliseconds: 300));
      },
    );
    for (final saved in ['450', '9999']) {
      testWidgets(
        '[K10b legacy presentation] cold accepted dock reads persisted width $saved $family/$dark',
        (t) async {
          t.view.physicalSize = const Size(1280, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await parentFixture(t);
          w.section = 'chat';
          taskRoutes(api, legacyTask);
          final prefs = (await t.runAsync(SharedPreferences.getInstance))!;
          await t.runAsync(
            () => prefs.setString('slock:legacyTaskPanelWidth', saved),
          );
          // App start preloads the preferences, so the dock's first frame
          // already knows the saved width.
          await t.runAsync(DevicePreferences.load);
          final held = Completer<Map>();
          api.routes['GET /tasks/channel/c1'] = (_) => held.future;
          w.navigation.navigateTask(
            w.location.withQuery({'legacyTask': 'c1:legacy-215'}),
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
          expect(find.byKey(const ValueKey('legacy-task-panel')), findsNothing);
          held.complete({
            'tasks': [legacyTask],
          });
          // The dock is final from the frame it first exists: its width never
          // passes through the 380 default on the way to the saved width.
          final widths = <double>{};
          for (var i = 0; i < 30; i++) {
            await t.runAsync(() => Future<void>.delayed(Duration.zero));
            await t.pump(const Duration(milliseconds: 16));
            final panel = find.byKey(const ValueKey('legacy-task-panel'));
            if (panel.evaluate().isNotEmpty) widths.add(t.getSize(panel).width);
          }
          expect(widths, {saved == '450' ? 450.0 : 380.0});
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    }
  }
}
