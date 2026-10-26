import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';
import 'package:raft_ui/test_themes.dart';

import 'agent_surface_cascade_test.dart' as cascade;

// The generic Card keeps its 1px used border. The migrated agent dialog uses
// Web DialogSurface instead: one 1px seam ring and 20px inner padding.
// The dark float shadow also contains its own separate 1px layer.
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

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} Card and agent dialog use their source box',
      (tester) async {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = const Size(1170, 2532);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await cascade.loadFonts(tester);
        final theme = raftTheme(dark: dark);
        final t = theme.extension<RaftTokens>()!;
        final resolver = RaftRecipeTokens(t);
        final specified = RaftCardRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(),
          tokens: resolver,
        ).root;
        final specifiedWidth = 1.0; // raft-ui 0.7.0 Card: 1px hairline
        final usedWidth = 1.0;
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
                        child: RaftCard(
                          padding: EdgeInsets.all(24),
                          child: SizedBox(key: probeKey, width: 10, height: 10),
                        ),
                      ),
                    ),
            ),
          );
          await tester.pumpAndSettle();
          final root = agentCard
              ? find
                    .descendant(
                      of: find.byType(RaftDialogSurface),
                      matching: find.byType(RaftRecipeBox),
                    )
                    .first
              : find.byType(RaftRecipeBox).first;
          final box = tester.widget<RaftRecipeBox>(root);
          expect(
            box.style.borderWidth,
            agentCard ? EdgeInsets.zero : EdgeInsets.all(usedWidth),
          );
          if (agentCard) {
            final rings = box.style
                .cssShadows(t.recipeTokens)
                .where(
                  (s) =>
                      !s.inset &&
                      s.blur == 0 &&
                      s.spread == 1 &&
                      s.color == t.colors['line-seam'],
                );
            expect(rings.length, 1);
            expect(box.style.padding, const EdgeInsets.all(20));
          }
          expect(tester.getSize(root).width, 358);
          expect(
            tester.getTopLeft(find.byKey(probeKey)).dx -
                tester.getTopLeft(root).dx,
            agentCard ? 20 : 24 + usedWidth,
          );
          // The retained specified style is never mutated by component paint.
          expect(specified.borderWidth, EdgeInsets.all(specifiedWidth));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
