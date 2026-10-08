import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(Widget child, RaftFamily family) => MaterialApp(
  theme: raftTheme(family),
  home: Scaffold(
    body: RaftDensityScope(
      density: RaftDensity.desktop,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

void main() {
  testWidgets(
    'NavItem admits exact glyph while preserving legacy icon callers',
    (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 220,
            child: RaftNavItem(
              label: 'Account',
              glyph: RaftGlyph.user,
              glyphSize: 15,
              onTap: () => tapped++,
            ),
          ),
          RaftFamily.elegant,
        ),
      );
      expect(tester.widget<RaftIcon>(find.byType(RaftIcon)).size, 15);
      await tester.tap(find.text('Account'));
      expect(tapped, 1);
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 220,
            child: RaftNavItem(
              label: 'Settings',
              icon: Icons.settings,
              onTap: () => tapped++,
            ),
          ),
          RaftFamily.elegant,
        ),
      );
      expect(find.byType(RaftSymbol), findsOneWidget);
      await tester.tap(find.text('Settings'));
      expect(tapped, 2);
    },
  );
  for (final family in RaftFamily.values) {
    testWidgets(
      '$family Saved action consumes original pressed override and callback',
      (tester) async {
        var removed = 0;
        await tester.pumpWidget(
          host(RaftSavedActionButton(onPressed: () => removed++), family),
        );
        final tokens = raftTheme(family).extension<RaftTokens>()!;
        final recipe = RaftControlRecipe(
          tokens,
          kind: RaftControlKind.savedAction,
          selected: true,
        );
        expect(
          recipe.background,
          tokens.colors['accent-soft']!.withValues(alpha: .3),
        );
        expect(
          recipe.foreground,
          tokens.colors[family == RaftFamily.brutal
              ? 'color-brutal-orange'
              : 'accent-strong'],
        );
        expect(
          tester.getSize(find.byType(RaftSavedActionButton)),
          family == RaftFamily.brutal ? const Size(28, 28) : const Size(32, 32),
        );
        expect(
          tester.widget<RaftIcon>(find.byType(RaftIcon)).glyph,
          RaftGlyph.bookmarkFilled,
        );
        await tester.tap(find.byType(RaftSavedActionButton));
        expect(removed, 1);
      },
    );
  }
}
