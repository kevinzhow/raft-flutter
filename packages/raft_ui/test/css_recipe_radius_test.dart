import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import 'control_transition_paint_test.dart' show pixel;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final directDecoration in [false, true]) {
      testWidgets(
        '[K09a] $family/$dark CSS rounded-full uses actual size (direct=$directDecoration)',
        (tester) async {
          final theme = raftTheme(family, dark: dark),
              t = raftTheme(family, dark: dark).extension<RaftTokens>()!;
          final rt = t.recipeTokens;
          final root = directDecoration
              ? RaftAvatarRecipe.resolve(
                  theme: t.recipeTheme,
                  type_: RaftAvatarRecipeType.human,
                  size: RaftAvatarRecipeSize.xl,
                  tokens: rt,
                ).root
              : RaftBadgeRecipe.resolve(
                  theme: t.recipeTheme,
                  states: t.recipeStates(),
                  tokens: rt,
                ).root;
          // Preserve the generated Source radius; isolate geometry from colors.
          BoxDecoration black(BoxDecoration d) => d.copyWith(
            color: Colors.black,
            border: Border.all(color: Colors.black),
            boxShadow: [],
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: const ValueKey('paint'),
                  child: Container(
                    width: 100,
                    height: 40,
                    color: Colors.white,
                    alignment: Alignment.topLeft,
                    child: directDecoration
                        ? Container(
                            width: 80,
                            height: 20,
                            decoration: black(root.decoration(rt)),
                            clipBehavior: Clip.antiAlias,
                            child: const SizedBox(),
                          )
                        : RaftRecipeBox(
                            style: root,
                            tokens: rt,
                            width: 80,
                            height: 20,
                            decorationOverride: black,
                            child: const SizedBox(),
                          ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            await pixel(tester, const Offset(1, 1)),
            family == RaftFamily.brutal ? Colors.black : Colors.white,
          );
          expect(await pixel(tester, const Offset(40, 10)), Colors.black);
          final decoration = black(root.decoration(rt));
          expect(
            decoration.hitTest(
              const Size(80, 20),
              const Offset(1, 1),
              textDirection: TextDirection.ltr,
            ),
            family == RaftFamily.brutal,
          );
          expect(
            decoration.hitTest(
              const Size(80, 20),
              const Offset(40, 10),
              textDirection: TextDirection.ltr,
            ),
            true,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test(
    'CSS overlap preserves unequal corners and finite unchanged geometry',
    () {
      final r = raftCssRadiusForBox(
        const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
        const Rect.fromLTWH(0, 0, 20, 100),
        TextDirection.ltr,
      );
      expect(r.topLeft, const Radius.circular(15));
      expect(r.topRight, const Radius.circular(5));
      expect(r.bottomLeft, const Radius.circular(2.5));
      expect(r.bottomRight, const Radius.circular(2.5));
      expect(
        raftCssRadiusForBox(
          BorderRadius.circular(4),
          const Rect.fromLTWH(0, 0, 80, 20),
          TextDirection.ltr,
        ),
        BorderRadius.circular(4),
      );
    },
  );
}
