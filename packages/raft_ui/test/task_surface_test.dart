import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/task_surface_previews.dart';

Widget host(Widget child, RaftFamily family, bool dark) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(body: child),
);

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'Task preview history has actual expanded semantics and Escape closes $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final semantics = t.ensureSemantics();
        await t.pumpWidget(host(taskModalPreview(), family, dark));
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
        await t.tap(find.text('Reopen preview'));
        await t.pump();
        expect(find.byKey(const ValueKey('task-thread-modal')), findsOneWidget);
        expect(find.text('Created task'), findsNothing);
        expect(t.takeException(), isNull);
        semantics.dispose();
      },
    );
    testWidgets(
      'Legacy preview is bounded metadata with no property writes $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(1280, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(host(legacyTaskPreview(), family, dark));
        expect(
          t.getSize(find.byKey(const ValueKey('legacy-task-panel'))),
          const Size(760, 658.32),
        );
        expect(find.text('Task #8 · LEGACY'), findsOneWidget);
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
