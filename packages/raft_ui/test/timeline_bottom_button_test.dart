import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark actual timeline position and input', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: const Key('timeline'),
                width: 390,
                height: 360,
                child: Stack(
                  children: [
                    RaftTimelineBottomButton(
                      label: '3 new messages',
                      onPressed: () => taps++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final timeline = tester.getRect(find.byKey(const Key('timeline')));
      final button = tester.getRect(find.byType(RaftRecipeButton));
      expect(button.center.dx, timeline.center.dx);
      expect(button.bottom, timeline.bottom - 12);
      await tester.tap(find.text('3 new messages'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
