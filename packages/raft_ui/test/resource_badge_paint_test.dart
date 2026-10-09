import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'control_transition_paint_test.dart' show pixel;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark resource badge paints its source shape', (
      tester,
    ) async {
      const outside = Color(0xffff8000);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: const ValueKey('paint'),
              child: const ColoredBox(
                color: outside,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: RaftResourceBadge(
                    label: 'Unread',
                    variant: RaftBadgeRecipeVariant.accent,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(RaftResourceBadge));
      expect(rect.height, family == RaftFamily.brutal ? 20 : 18);
      final corner = await pixel(tester, rect.topLeft);
      if (family == RaftFamily.elegant) {
        expect(
          corner,
          outside,
          reason: 'CSS rounded-full leaves the corner clear.',
        );
      } else {
        expect(
          corner,
          isNot(outside),
          reason: 'Brutal badges retain their square border.',
        );
      }
      expect(
        await pixel(tester, Offset(rect.center.dx, rect.top + 1)),
        isNot(outside),
        reason: 'The capsule still paints its top center.',
      );
      expect(find.text('Unread'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
