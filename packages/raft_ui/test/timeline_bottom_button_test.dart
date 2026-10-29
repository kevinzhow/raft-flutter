import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} actual timeline position and input',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const Key('timeline'),
                  width: 390,
                  height: 360,
                  child: Stack(
                    children: [
                      RaftTimelineBottomButton(
                        label: '3 New Messages',
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
        await tester.tap(find.text('3 New Messages'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
