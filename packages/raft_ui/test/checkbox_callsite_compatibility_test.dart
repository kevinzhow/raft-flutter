import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/checkbox.g.dart';
import 'package:raft_ui/src/recipes/recipe_runtime.dart' show RaftRecipeTheme;
import 'package:raft_ui/test_themes.dart';

// 3b624f30 auth_page.dart:607-625 rendered the sign-up legal checkbox
// directly as Material, sized by the Elegant md recipe in both frozen looks.
// indicators.RaftCheckbox instead always delegated to RaftCheckboxControl.
// Preserve those distinct legacy call shapes inside the canonical family.
void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in raftThemeMatrix([false, true])) {
      testWidgets(
        'legal checkbox preserves its legacy call shape $id dark=$dark',
        (tester) async {
          addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
          final pack = packForThemeId(id);
          final tokens = RaftTokens.theme(pack: pack, dark: dark);
          final legalChanges = <bool>[];
          final ordinaryChanges = <bool>[];
          Widget host(bool enabled) => MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: raftTheme(pack: pack, dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  RaftAuthLegalCheckbox(
                    checked: false,
                    onChanged: enabled ? legalChanges.add : null,
                    onTerms: () {},
                    onPrivacy: () {},
                  ),
                  RaftCheckbox(
                    key: const ValueKey('ordinary-checkbox'),
                    value: false,
                    onChanged: enabled ? ordinaryChanges.add : null,
                  ),
                ],
              ),
            ),
          );

          final legalGraphic = find.descendant(
            of: find.byType(RaftAuthLegalCheckbox),
            matching: find.byType(RaftCheckbox),
          );
          for (final enabled in [true, false]) {
            await tester.pumpWidget(host(enabled));
            if (tokens.isRaftLook) {
              expect(find.byType(Checkbox), findsNothing);
              expect(tester.getSize(legalGraphic), const Size(20, 20));
            } else {
              final oldLegalSize = RaftCheckboxRecipe.resolve(
                theme: RaftRecipeTheme.elegant,
                size: RaftCheckboxRecipeSize.md,
                tokens: tokens.recipeTokens,
              ).root.width!;
              final material = find.descendant(
                of: find.byType(RaftAuthLegalCheckbox),
                matching: find.byType(Checkbox),
              );
              expect(find.byType(Checkbox), findsOneWidget);
              expect(tester.getSize(material), Size.square(oldLegalSize));
              final checkbox = tester.widget<Checkbox>(material);
              expect(
                checkbox.materialTapTargetSize,
                MaterialTapTargetSize.shrinkWrap,
              );
              expect(checkbox.visualDensity, VisualDensity.compact);
            }
            final ordinary = find.byKey(const ValueKey('ordinary-checkbox'));
            expect(tester.getSize(ordinary), const Size(20, 20));
            expect(
              find.descendant(of: ordinary, matching: find.byType(Checkbox)),
              findsNothing,
            );
            await tester.tap(legalGraphic, warnIfMissed: enabled);
            await tester.tap(ordinary, warnIfMissed: enabled);
            expect(legalChanges, [true]);
            expect(ordinaryChanges, [true]);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
