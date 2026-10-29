import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  // Web db5e399f Sidebar.tsx:824-825 applies bg-fill-pressed only when
  // !selected && menuOpen. Opening a context menu does not select the row.
  for (final dark in [false, true]) {
    for (final kind in RaftConversationNavKind.values) {
      testWidgets('$dark/$kind menu highlight stays separate from selection', (
        tester,
      ) async {
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
        final theme = raftTheme(dark: dark);
        final tokens = theme.extension<RaftTokens>()!;
        var menuOpen = false;
        var selected = false;
        var activations = 0;
        late StateSetter update;
        const row = ValueKey('menu-owner');
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 300,
                      child: RaftNavItem(
                        key: row,
                        label: 'Menu owner',
                        glyph: RaftGlyph.user,
                        conversationKind: kind,
                        selected: selected,
                        menuOpen: menuOpen,
                        onTap: () => activations++,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        BoxDecoration face() =>
            tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byKey(row),
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        RaftControl control() => tester.widget<RaftControl>(
          find.descendant(
            of: find.byKey(row),
            matching: find.byType(RaftControl),
          ),
        );
        final originalBounds = tester.getRect(find.byKey(row));
        final originalText = tester.widget<Text>(find.text('Menu owner')).style;
        expect(face().color, Colors.transparent);
        update(() => menuOpen = true);
        await tester.pumpAndSettle();
        expect(face().color, tokens.colors['fill-pressed']);
        expect(control().selected, isFalse);
        expect(face().border!.top.color, Colors.transparent);
        expect(face().boxShadow, isEmpty);
        expect(
          tester.widget<Text>(find.text('Menu owner')).style,
          originalText,
        );
        expect(tester.getRect(find.byKey(row)), originalBounds);
        expect(activations, 0);

        update(() => selected = true);
        await tester.pumpAndSettle();
        expect(face().color, tokens.colors['layer-sidebar-item-active']);
        expect(control().selected, isTrue);
        update(() => menuOpen = false);
        await tester.pumpAndSettle();
        expect(face().color, tokens.colors['layer-sidebar-item-active']);
        update(() => selected = false);
        await tester.pumpAndSettle();
        expect(face().color, Colors.transparent);
        await tester.tap(find.byKey(row));
        await tester.pumpAndSettle();
        expect(activations, 1);
      });
    }
    for (final id in [elegantThemePackId, brutalThemePackId]) {
      test('$id/$dark frozen menu paint retains its original layer', () {
        final tokens = raftTheme(
          pack: packForThemeId(id),
          dark: dark,
        ).extension<RaftTokens>()!;
        expect(tokens.isRaftLook, isFalse);
        final recipe = RaftMountedConversationControlRecipe(
          tokens,
          menuOpen: true,
        );
        expect(recipe.background, tokens.colors['layer-sidebar-item-active']);
      });
    }
  }
}
