import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/banner_action_slot.dart';
import 'package:raft_ui/src/recipes/recipe_runtime.dart';

void main() {
  testWidgets('internal action slot consumes supplied margins and both gaps', (
    tester,
  ) async {
    final style = RaftSlotStyle(
      const {
        'margin-top': CssNum(11, 'px'),
        'margin-right': CssNum(3, 'px'),
        'margin-bottom': CssNum(5, 'px'),
        'margin-left': CssNum(7, 'px'),
        'column-gap': CssNum(17, 'px'),
        'row-gap': CssNum(13, 'px'),
      },
      const {},
      const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RaftBannerActionSlot(
                  style: style,
                  children: [
                    for (var i = 0; i < 3; i++)
                      SizedBox(key: ValueKey(i), width: 40, height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(RaftBannerActionSlot));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(0))) - origin,
      const Offset(7, 11),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(1))) - origin,
      const Offset(64, 11),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(2))) - origin,
      const Offset(7, 44),
    );
    expect(tester.getSize(find.byType(RaftBannerActionSlot)).height, 69);
  });

  testWidgets('production Banner delegates once and paints one action Wrap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(raftThemePackId)),
        home: const Center(
          child: SizedBox(
            width: 300,
            child: RaftBanner(
              description: 'Source action slot',
              actions: [
                SizedBox(width: 40, height: 20),
                SizedBox(width: 40, height: 20),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RaftBannerActionSlot), findsOneWidget);
    expect(
      find.descendant(of: find.byType(RaftBanner), matching: find.byType(Wrap)),
      findsOneWidget,
    );
  });
}
