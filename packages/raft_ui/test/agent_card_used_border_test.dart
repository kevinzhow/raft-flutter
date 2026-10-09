import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import 'agent_surface_cascade_test.dart' as cascade;

// Actual Source DialogCard and CreateAgent No Computer Card both specify
// border-[0.5px] in Elegant. Chromium's measured normal-zoom DPR3 used box is
// 1 CSS pixel; source recipes themselves must remain specified at 0.5px.
void main() {
  test('Source normal-zoom used borders preserve specified recipe values', () {
    for (final (specified, used) in [
      (0.0, 0.0),
      (0.2, 1.0),
      (0.5, 1.0),
      (0.9, 1.0),
      (1.0, 1.0),
      (1.5, 1.0),
      (2.0, 2.0),
    ]) {
      final style = RaftSlotStyle(
        {
          for (final side in ['top', 'right', 'bottom', 'left']) ...{
            'border-$side-style': const CssKeyword('solid'),
            'border-$side-width': CssNum(specified, 'px'),
          },
        },
        const {},
        const [],
      );
      expect(style.withCssUsedBorderWidths().borderWidth, EdgeInsets.all(used));
      expect(style.borderWidth, EdgeInsets.all(specified));
    }
  });

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark actual Card consumers use the measured Source box',
      (tester) async {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = const Size(1170, 2532);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await cascade.loadFonts(tester);
        final theme = raftTheme(family, dark: dark);
        final t = theme.extension<RaftTokens>()!;
        final resolver = RaftRecipeTokens(t);
        final specified = RaftCardRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(),
          tokens: resolver,
        ).root;
        final specifiedWidth = t.brutal ? 2.0 : 0.5;
        final usedWidth = t.brutal ? 2.0 : 1.0;
        expect(specified.borderWidth, EdgeInsets.all(specifiedWidth));

        const probeKey = ValueKey('card-child');
        for (final agentCard in [false, true]) {
          await tester.pumpWidget(
            cascade.host(
              theme,
              agentCard
                  ? RaftAgentDialogCard(
                      title: 'Create Agent',
                      onClose: () {},
                      children: const [
                        SizedBox(key: probeKey, width: 10, height: 10),
                      ],
                    )
                  : const Center(
                      child: SizedBox(
                        width: 358,
                        child: RaftRecipeCard(
                          padding: EdgeInsets.all(24),
                          child: SizedBox(key: probeKey, width: 10, height: 10),
                        ),
                      ),
                    ),
            ),
          );
          await tester.pumpAndSettle();
          final root = find.byType(RaftRecipeBox).first;
          final box = tester.widget<RaftRecipeBox>(root);
          expect(box.style.borderWidth, EdgeInsets.all(usedWidth));
          expect(tester.getSize(root).width, 358);
          expect(
            tester.getTopLeft(find.byKey(probeKey)).dx -
                tester.getTopLeft(root).dx,
            24 + usedWidth,
          );
          // The retained specified style is never mutated by component paint.
          expect(specified.borderWidth, EdgeInsets.all(specifiedWidth));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
