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
    testWidgets('$family/$dark overflow menu follows painted trigger', (
      tester,
    ) async {
      var chosen = 0, underlying = 0;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('paint'),
          child: MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  RaftPanelHeaderBar(
                    title: 'Agent',
                    actions: [
                      RaftOverflowMenuButton(
                        tooltip: 'More actions',
                        entries: [
                          RaftMenuEntry(
                            label: 'Direct message',
                            leading: const RaftDirectMessageIcon(size: 14),
                            onPressed: () => chosen++,
                          ),
                          RaftMenuEntry(
                            label: 'Stop Agent',
                            glyph: RaftGlyph.square,
                            onPressed: () => chosen++,
                          ),
                          RaftMenuEntry(
                            label: 'Restart / Reset',
                            glyph: RaftGlyph.rotateCcw,
                            onPressed: () => chosen++,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 220),
                  RaftButton(
                    label: 'Underlying action',
                    onPressed: () => underlying++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.byType(CompositedTransformTarget);
      final idle = tester.getRect(target);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: idle.center);
      await mouse.down(idle.center);
      await mouse.up();
      await tester.pumpAndSettle();
      final hovered = tester.getRect(target);
      expect(hovered.top, idle.top - (family == RaftFamily.brutal ? 1 : 0));
      final popup = find.byType(RaftMenuPanel);
      FocusNode firstItemFocus() => tester
          .widget<FocusableActionDetector>(
            find.descendant(
              of: find.byType(RaftMenuItem).first,
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!;
      expect(firstItemFocus().hasFocus, false);
      expect(tester.getRect(popup).top, hovered.bottom + 4);
      expect(tester.getRect(popup).right, hovered.right);
      await pixel(tester, const Offset(2, 2));
      await mouse.moveTo(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(tester.getRect(target), idle);
      expect(tester.getRect(popup).top, idle.bottom + 4);
      await pixel(tester, const Offset(2, 2));
      await mouse.removePointer();
      await tester.tap(find.text('Underlying action'));
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      expect(underlying, 0, reason: 'Dismissal must consume the outside tap.');
      await tester.tap(find.text('Underlying action'));
      await tester.pumpAndSettle();
      expect(underlying, 1);
      await tester.tap(find.byType(RaftOverflowMenuButton));
      await tester.pumpAndSettle();
      expect(tester.getRect(popup).top, idle.bottom + 4);
      await pixel(tester, const Offset(2, 2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget, reason: 'Escape returns focus to trigger.');
      expect(firstItemFocus().hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, 1);
      expect(popup, findsNothing);
      await tester.tap(find.byType(RaftOverflowMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Direct message'));
      await tester.pumpAndSettle();
      expect(chosen, 2);
      expect(popup, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
