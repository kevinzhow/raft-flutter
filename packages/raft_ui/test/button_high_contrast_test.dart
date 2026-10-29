import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('system high contrast danger colors $id/$dark', (t) async {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        Future<(Color?, Color?)> colors(bool highContrast) async {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
              home: MediaQuery(
                data: MediaQueryData(highContrast: highContrast),
                child: Scaffold(
                  body: Center(
                    child: RaftButton(
                      label: 'Delete',
                      tone: RaftButtonRecipeVariant.danger,
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          final decorations = t.widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(RaftButton),
              matching: find.byType(DecoratedBox),
            ),
          );
          final fill = decorations
              .map(
                (w) => switch (w.decoration) {
                  RaftLayeredDecoration d => d.base.color,
                  BoxDecoration d => d.color,
                  _ => null,
                },
              )
              .whereType<Color>()
              .first;
          return (
            fill,
            DefaultTextStyle.of(t.element(find.text('Delete'))).style.color,
          );
        }

        final ordinary = await colors(false);
        final high = await colors(true);
        final tokens = RaftTokens.of(t.element(find.text('Delete')));
        final expected =
            id == raftThemePackId || (id == brutalThemePackId && !dark)
            ? ordinary
            : (
                tokens.colors['button-danger-high-contrast'],
                tokens.colors['button-danger-high-contrast-foreground'],
              );
        expect(high, expected);
        expect(t.takeException(), isNull);
      });
    }
  }
}
