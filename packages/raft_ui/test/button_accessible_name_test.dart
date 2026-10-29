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
      testWidgets('$id/$dark icon tooltip supplies its accessible name', (
        t,
      ) async {
        final semantics = t.ensureSemantics();
        var dismissed = 0;
        try {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
              home: Scaffold(
                body: Center(
                  child: RaftButton(
                    label: '',
                    glyph: RaftGlyph.x,
                    uiVariant: RaftButtonVariant.ghost,
                    uiSize: RaftButtonSize.iconXs,
                    tooltip: 'Dismiss warning',
                    onPressed: () => dismissed++,
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final named = find.bySemanticsLabel('Dismiss warning');
          expect(named, findsOneWidget);
          expect(t.getSemantics(named).label, 'Dismiss warning');
          await t.tap(named);
          expect(dismissed, 1);
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          semantics.dispose();
        }
      });
    }
  }

  for (final explicit in [false, true]) {
    testWidgets(
      'tooltip preserves the ${explicit ? 'explicit' : 'visible'} name',
      (t) async {
        final semantics = t.ensureSemantics();
        try {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(),
              home: Scaffold(
                body: RaftButton(
                  label: explicit ? '' : 'Save',
                  glyph: RaftGlyph.check,
                  tooltip: 'Extra information',
                  semanticLabel: explicit ? 'Apply changes' : null,
                  onPressed: () {},
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            find.bySemanticsLabel(explicit ? 'Apply changes' : 'Save'),
            findsOneWidget,
          );
          expect(find.bySemanticsLabel('Extra information'), findsNothing);
        } finally {
          await t.pumpWidget(const SizedBox());
          semantics.dispose();
        }
      },
    );
  }
}
