import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, child: child),
    ),
  ),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets('the plain card has no padding of its own (dark=$dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(raftTheme(dark: dark), const RaftCard(child: Text('hello'))),
      );
      final box = tester.getRect(find.byType(RaftCard));
      final text = tester.getRect(find.text('hello'));
      // The 1px hairline is the only inset.
      expect(text.left - box.left, 1);
      expect(text.top - box.top, 1);
    });

    testWidgets('an item pads 16 x 12 and taps (dark=$dark)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          raftTheme(dark: dark),
          RaftCard.item(onTap: () => taps++, child: const Text('row')),
        ),
      );
      final box = tester.getRect(find.byType(RaftCard));
      final text = tester.getRect(find.text('row'));
      expect(text.left - box.left, 17);
      expect(text.top - box.top, 13);
      await tester.tap(find.text('row'));
      expect(taps, 1);
    });

    testWidgets('a selected item fills info-soft (dark=$dark)', (tester) async {
      final theme = raftTheme(dark: dark);
      await tester.pumpWidget(
        host(theme, const RaftCard.item(selected: true, child: Text('row'))),
      );
      final ui = theme.extension<RaftTokens>()!.ui;
      final fill = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .whereType<Color>();
      expect(fill, contains(ui['info-soft']));
    });

    testWidgets('the option variant taps and pads 12 (dark=$dark)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          raftTheme(dark: dark),
          RaftCard(
            variant: RaftCardRecipeVariant.option,
            onTap: () => taps++,
            semanticLabel: 'Choose',
            child: const Text('option'),
          ),
        ),
      );
      await tester.tap(find.text('option'));
      expect(taps, 1);
      final box = tester.getRect(find.byType(RaftCard));
      final text = tester.getRect(find.text('option'));
      expect(text.left - box.left, greaterThanOrEqualTo(12));
    });
  }
}
