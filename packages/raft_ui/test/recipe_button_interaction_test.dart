import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'control_transition_paint_test.dart' show pixel;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark dialog recipe button accepts all inputs', (
      tester,
    ) async {
      var activated = 0, disabled = false;
      late StateSetter update;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('paint'),
          child: MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return RaftRecipeButton(
                      tooltip: 'Close',
                      glyph: RaftGlyph.x,
                      glyphSize: 20,
                      size: RaftButtonRecipeSize.iconMd,
                      variant: RaftButtonRecipeVariant.outline,
                      disabled: disabled,
                      onPressed: () => activated++,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(RaftRecipeButton);
      final idle = tester.getRect(button);
      expect(idle.size, const Size(32, 32));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(activated, 1, reason: 'A dialog button must activate with Enter.');
      final node = tester.getSemantics(button);
      expect(
        node,
        matchesSemantics(
          label: 'Close',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(tester.getRect(button), idle);
      await pixel(tester, const Offset(2, 2));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(activated, 2);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: SemanticsAction.tap,
        ),
      );
      await tester.pumpAndSettle();
      expect(activated, 3);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: idle.center);
      await mouse.down(idle.center);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(activated, 4);
      await pixel(tester, const Offset(2, 2));
      await mouse.removePointer();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(activated, 5);
      update(() => disabled = true);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(activated, 5, reason: 'Disabled controls reject every input.');
      expect(tester.getRect(button), idle);
      expect(
        tester.getSemantics(button),
        matchesSemantics(label: 'Close', isButton: true, hasEnabledState: true),
      );
      await pixel(tester, const Offset(2, 2));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
