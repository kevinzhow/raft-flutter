import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_task_actions.dart';

import 'close_dialogs_test.dart'
    show anyX, ignoreOverflow, registerNoScrimTests;
import 'support/close_registry_tasks_page.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';
import 'support/tasks_page_harness.dart';

/// The Tasks page's popovers, menus and dialogs (task v2, Web TasksPage): each
/// closes by what the registry lists at phone, foldable and desktop widths.
/// The page is mounted with the flag on and a few tasks of the viewer's own,
/// so every action of the selection bar is there.
Future<WorkspaceController> mount(WidgetTester t, Size size) async {
  ignoreOverflow();
  await t.pumpWidget(const SizedBox.shrink());
  final (w, _) = (await t.runAsync(
    () => tasksFixture(
      tasks: [
        pageTask('a1', claimedBy: meId),
        pageTask('a2', claimedBy: meId, activityAt: '2026-11-17T09:00:00.000Z'),
      ],
    ),
  ))!;
  addTearDown(w.dispose);
  await t.runAsync(() => TaskV2ConversationsFlag.of(w).ensure());
  await mountPage(t, w, size: size, platform: closePlatform(size));
  return w;
}

Future<void> tapVisible(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder.first);
  await t.pump();
  await t.tap(finder.first);
  await frames(t, 20);
}

/// Everything selected (Ctrl+A with nothing focused): the bar is up.
Future<void> selectEverything(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(LogicalKeyboardKey.keyA);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await frames(t, 20);
  expect(find.byKey(const Key('tasks-page-selection-bar')), findsOneWidget);
}

Offset corner(Size size) => Offset(size.width - 6, size.height - 6);

void main() {
  final harness = <String, OpenSurface>{
    'tasks-page-filter-popover': (t, size) async {
      await mount(t, size);
      await tapVisible(t, find.byKey(const Key('tasks-page-filter-status')));
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('task-selection-status-popover'))
            .evaluate()
            .isNotEmpty,
        scrim: Offset(size.width - 6, 120),
      );
    },
    'tasks-page-sort-menu': (t, size) async {
      await mount(t, size);
      await tapVisible(t, find.byKey(const Key('tasks-page-sort')));
      return SurfaceProbe(
        isOpen: () => find.text('Least recently updated').evaluate().isNotEmpty,
        scrim: corner(size),
      );
    },
    'tasks-page-more-menu': (t, size) async {
      await mount(t, size);
      await tapVisible(t, find.byKey(const Key('tasks-page-more')));
      return SurfaceProbe(
        isOpen: () => find.text('View as').evaluate().isNotEmpty,
        scrim: Offset(6, size.height - 6),
      );
    },
    'tasks-page-scope-select': (t, size) async {
      await mount(t, size);
      await tapVisible(t, find.byKey(const Key('tasks-page-scope-select')));
      return SurfaceProbe(
        isOpen: () => find.text('All').evaluate().isNotEmpty,
        scrim: corner(size),
      );
    },
    'tasks-batch-status-menu': (t, size) async {
      await mount(t, size);
      await selectEverything(t);
      await tapVisible(t, find.byKey(const Key('selection-bar-action-status')));
      return SurfaceProbe(
        isOpen: () => find.text('Done').evaluate().isNotEmpty,
        scrim: Offset(6, 120),
      );
    },
    'tasks-batch-assignee-picker': (t, size) async {
      await mount(t, size);
      await selectEverything(t);
      await tapVisible(
        t,
        find.byKey(const Key('selection-bar-action-assignee')),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('tasks-batch-assignee-popover'))
            .evaluate()
            .isNotEmpty,
        scrim: Offset(6, 120),
      );
    },
    'tasks-batch-delete-confirm': (t, size) async {
      await mount(t, size);
      await selectEverything(t);
      final delete = find.byKey(const Key('selection-bar-action-delete'));
      if (delete.evaluate().isNotEmpty) {
        await tapVisible(t, delete);
      } else {
        // Folded into More at this width.
        await tapVisible(t, find.byKey(const Key('selection-bar-more')));
        await tapVisible(t, find.text('Delete').last);
      }
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('task-delete-confirm'))
            .evaluate()
            .isNotEmpty,
        x: find.descendant(
          of: find.byKey(const ValueKey('task-delete-confirm')),
          matching: anyX,
        ),
        scrim: const Offset(6, 6),
      );
    },
    'tasks-page-new-task': (t, size) async {
      await mount(t, size);
      await tapVisible(t, find.byKey(const Key('tasks-page-new-task')));
      final dialog = find.byKey(const ValueKey('create-task-message-dialog'));
      return SurfaceProbe(
        isOpen: () => dialog.evaluate().isNotEmpty,
        x: find.descendant(of: dialog, matching: anyX),
        scrim: const Offset(6, 6),
        dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
      );
    },
  };
  registerCloseTests(tasksPageSurfaces, harness);
  registerNoScrimTests(tasksPageSurfaces, harness);
}
