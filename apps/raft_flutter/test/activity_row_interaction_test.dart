import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/resource_cards.dart';

import '../../../packages/raft_ui/test/control_transition_paint_test.dart'
    show pixel;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final density in [RaftDensity.desktop, RaftDensity.touch]) {
      testWidgets('$family/$dark $density activity row actions retain layout', (
        tester,
      ) async {
        var opened = 0, completed = 0;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('paint'),
            child: MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: RaftDensityScope(
                density: density,
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 280,
                      child: RaftConversationCard(
                        onOpen: () => opened++,
                        actions: RaftIconButton(
                          visualSize: 28,
                          minimumTargetSize: 28,
                          glyph: RaftGlyph.check,
                          tooltip: 'Mark conversation done',
                          onPressed: () => completed++,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text('An activity conversation'),
                            ),
                            const SizedBox(width: 8),
                            const RaftConversationTimestamp(
                              child: Text('in 3 days'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byType(RaftConversationCard);
        final stamp = find.byType(RaftConversationTimestamp);
        final action = find.byType(RaftIconButton);
        expect(tester.getSize(action), const Size(28, 28));
        final rect = tester.getRect(row), stampRect = tester.getRect(stamp);
        double timestampOpacity() => tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: stamp,
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity;
        expect(timestampOpacity(), density == RaftDensity.touch ? 0 : 1);
        await pixel(tester, const Offset(2, 2));
        if (density == RaftDensity.desktop) {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: rect.center);
          await tester.pumpAndSettle();
          expect(timestampOpacity(), 0);
          expect(tester.getRect(row), rect);
          expect(tester.getRect(stamp), stampRect);
          await pixel(tester, const Offset(2, 2));
          await mouse.moveTo(const Offset(1, 1));
          await tester.pumpAndSettle();
          expect(timestampOpacity(), 1);
          await mouse.removePointer();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(timestampOpacity(), 0);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(opened, 1);
          // The nested action's focus must retain the Source focus-within
          // visibility, and Enter there must not open the parent conversation.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(timestampOpacity(), 0);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(completed, 1);
          expect(opened, 1);
        } else {
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(completed, 1);
          expect(opened, 0);
          await tester.tap(find.text('An activity conversation'));
          await tester.pumpAndSettle();
          expect(opened, 1);
        }
        expect(tester.getRect(row), rect);
        expect(tester.getRect(stamp), stampRect);
        await pixel(tester, const Offset(2, 2));
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}
