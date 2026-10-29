@Tags(['look-elegant'])
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/task_surface_previews.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(Widget child, bool dark) => MaterialApp(
  theme: raftTheme(pack: packForThemeId(elegantThemePackId), dark: dark),
  home: Scaffold(body: child),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final legacy in [false, true]) {
      testWidgets(
        'Task page uses shared header, semantics and keyboard Back ${dark ? 'dark' : 'light'}/$legacy',
        (t) async {
          t.view.physicalSize = const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final semantics = t.ensureSemantics();
          await t.pumpWidget(
            host(legacy ? legacyTaskPagePreview() : taskPagePreview(), dark),
          );
          // Web's phone TaskModalBar (`px-4 py-2`, 28px `size-7` Back) rather
          // than the shared 56px page header; the touch area is still 48.
          expect(find.byType(RaftMobilePageHeader), findsNothing);
          final back = find.byKey(const ValueKey('task-back'));
          expect(t.getSize(back), const Size.square(28));
          expect(t.getCenter(back).dx, (legacy ? 20 : 16) + 14);
          expect(
            t.getSize(
              find.ancestor(
                of: back,
                matching: find.byType(RaftTouchTargetExpander),
              ),
            ),
            const Size.square(28),
          );
          // The extended touch area is the semantics rect of the Back button.
          SemanticsNode? node;
          void visit(SemanticsNode n) {
            if (n.label == 'Close Task') node = n;
            n.visitChildren((c) {
              visit(c);
              return true;
            });
          }

          // ignore: deprecated_member_use
          visit(t.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
          expect(node!.getSemanticsData().flagsCollection.isButton, isTrue);
          expect(node!.rect.size, const Size.square(48));
          expect(find.byType(RaftModalBackdrop), findsNothing);
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.pump();
          expect(find.text('Reopen Preview'), findsOneWidget);
          // The 28px Back keeps a >= 44px touch area (4px below its edge).
          await t.tap(find.text('Reopen Preview'));
          await t.pump();
          await t.tapAt(t.getCenter(back) + const Offset(0, 18));
          await t.pump();
          expect(find.text('Reopen Preview'), findsOneWidget);
          expect(t.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
    testWidgets(
      'Task preview history has actual expanded semantics and Escape closes ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final semantics = t.ensureSemantics();
        await t.pumpWidget(host(taskModalPreview(), dark));
        final history = find.byKey(const ValueKey('task-properties-history'));
        expect(find.text('Created task'), findsNothing);
        expect(
          t.getSemantics(history).flagsCollection.isExpanded,
          Tristate.isFalse,
        );
        await t.tap(history);
        await t.pump();
        expect(find.text('Created task'), findsOneWidget);
        expect(
          t.getSemantics(history).flagsCollection.isExpanded,
          Tristate.isTrue,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byKey(const ValueKey('task-thread-modal')), findsNothing);
        await t.tap(find.text('Reopen Preview'));
        await t.pump();
        expect(find.byKey(const ValueKey('task-thread-modal')), findsOneWidget);
        expect(find.text('Created task'), findsNothing);
        expect(t.takeException(), isNull);
        semantics.dispose();
      },
    );
    testWidgets(
      'Legacy dock preview switches desktop close to narrow back ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(1280, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(host(legacyDockedTaskPreview(), dark));
        expect(
          t.getRect(find.byKey(const ValueKey('legacy-task-panel'))),
          const Rect.fromLTWH(900, 0, 380, 844),
        );
        expect(find.byKey(const ValueKey('task-close')), findsOneWidget);
        expect(find.byKey(const ValueKey('task-back')), findsNothing);
        t.view.physicalSize = const Size(390, 844);
        await t.pump();
        expect(
          t.getRect(find.byKey(const ValueKey('legacy-task-panel'))),
          const Rect.fromLTWH(0, 0, 390, 844),
        );
        expect(find.byKey(const ValueKey('task-close')), findsNothing);
        await t.tap(find.byKey(const ValueKey('task-back')));
        await t.pump();
        expect(find.byKey(const ValueKey('legacy-task-panel')), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      'Legacy preview is bounded metadata with no property writes ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(1280, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(host(legacyTaskPreview(), dark));
        expect(
          t.getSize(find.byKey(const ValueKey('legacy-task-panel'))),
          const Size(760, 658.32),
        );
        expect(find.text('Task #8 · Legacy'), findsOneWidget);
        expect(find.textContaining('posting is disabled.'), findsOneWidget);
        expect(find.byType(RaftInlineBadgeEditor), findsNothing);
        expect(
          find.byKey(const ValueKey('task-properties-history')),
          findsNothing,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byKey(const ValueKey('legacy-task-panel')), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
}
