import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_theme/recipes.dart' as raft;
import 'package:raft_theme/recipes_legacy.dart' as legacy;
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';
import 'package:raft_ui/src/recipes/recipe_router.dart'
    show resolveAuthoredClasses, resolveRecipeClasses;

/// The recipe router (tool/recipes/gen_router.mjs): the Elegant and Brutal
/// looks resolve the frozen raft-ui 0.5.52 recipes exactly as before; the
/// Raft look and user packs resolve the current set.
Map<String, Object?> _props(RaftSlotStyle s) => {
  for (final e in s.properties.entries) e.key: e.value.toString(),
  for (final t in s.targets.entries)
    for (final e in t.value.entries) '${t.key}|${e.key}': e.value.toString(),
};

void main() {
  RaftTokens tokens(RaftThemePack pack, {bool dark = false}) =>
      RaftTokens.theme(pack: pack, dark: dark);

  group('pack -> recipe set', () {
    test('Elegant and Brutal are legacy, Raft and user packs are Raft', () {
      expect(tokens(builtInRaftTheme).recipeSet, RaftRecipeSet.raft);
      expect(tokens(builtInElegantTheme).recipeSet, RaftRecipeSet.legacy);
      expect(tokens(builtInBrutalTheme).recipeSet, RaftRecipeSet.legacy);
      final user = RaftThemePack.parse('''
{
  "format": "raft-theme/1",
  "id": "test-user",
  "name": {"en": "User"},
  "version": "1.0.0",
  "extends": "raft",
  "modes": {"light": {}, "dark": {}}
}
''');
      expect(tokens(user).recipeSet, RaftRecipeSet.raft);
      expect(
        tokens(builtInElegantTheme).recipeTokens.recipeSet,
        RaftRecipeSet.legacy,
      );
    });
  });

  group('legacy looks are the frozen set, by construction', () {
    for (final pack in [builtInElegantTheme, builtInBrutalTheme]) {
      for (final dark in [false, true]) {
        test('${pack.id} ${dark ? 'dark' : 'light'}', () {
          final t = tokens(pack, dark: dark);
          final rt = t.recipeTokens;
          final states = t.recipeStates();
          for (final theme in RaftRecipeTheme.values) {
            for (final variant in RaftButtonRecipeVariant.values) {
              final routed = RaftButtonRecipe.resolve(
                theme: theme,
                variant: variant,
                states: states,
                tokens: rt,
              ).root;
              final frozen = legacy.RaftButtonRecipe.resolve(
                theme: theme,
                variant: legacy.RaftButtonRecipeVariant.values.firstWhere(
                  (v) => v.css == variant.css,
                ),
                states: states,
                tokens: rt,
              ).root;
              expect(routed.classes, frozen.classes);
              expect(_props(routed), _props(frozen));
            }
            expect(
              _props(
                RaftBadgeRecipe.resolve(
                  theme: theme,
                  uppercase: true,
                  states: states,
                  tokens: rt,
                ).root,
              ),
              _props(
                legacy.RaftBadgeRecipe.resolve(
                  theme: theme,
                  uppercase: true,
                  states: states,
                  tokens: rt,
                ).root,
              ),
            );
          }
          // A slot only the frozen set has stays populated.
          expect(
            RaftAppRailRecipe.resolve(
              theme: RaftRecipeTheme.elegant,
              tokens: rt,
            ).itemAttentionMask.classes,
            legacy.RaftAppRailRecipe.resolve(
              theme: RaftRecipeTheme.elegant,
              tokens: rt,
            ).itemAttentionMask.classes,
          );
        });
      }
    }

    test('class lists resolve through the frozen utility table', () {
      final t = tokens(builtInBrutalTheme);
      final style = resolveRecipeClasses(
        const ['border', 'bg-layer-panel', 'shadow-raft-md'],
        t.recipeStates(),
        t.recipeTokens,
      );
      expect(style.classes, ['border', 'bg-layer-panel', 'shadow-raft-md']);
    });

    test('authored class lists use the frozen table in every look', () {
      for (final pack in [builtInRaftTheme, builtInElegantTheme]) {
        final t = tokens(pack);
        final style = resolveAuthoredClasses(
          const ['border', 'bg-layer-panel', 'shadow-raft-md'],
          t.recipeStates(),
          t.recipeTokens,
        );
        expect(style.classes, ['border', 'bg-layer-panel', 'shadow-raft-md']);
      }
    });
  });

  group('Raft look is the current set', () {
    for (final dark in [false, true]) {
      test(dark ? 'dark' : 'light', () {
        final t = tokens(builtInRaftTheme, dark: dark);
        final rt = t.recipeTokens;
        final states = t.recipeStates();
        final routed = RaftButtonRecipe.resolve(
          theme: RaftRecipeTheme.elegant,
          variant: RaftButtonRecipeVariant.primary,
          states: states,
          tokens: rt,
        ).root;
        final current = raft.RaftButtonRecipe.resolve(
          variant: raft.RaftButtonRecipeVariant.primary,
          states: states,
          tokens: rt,
        ).root;
        expect(routed.classes, current.classes);
        expect(_props(routed), _props(current));
        expect(routed.borderWidth, const EdgeInsets.all(1.5));
        // Its slots resolve every token against the Raft pack.
        routed.decoration(rt);
        routed.textStyle(rt);
      });
    }

    test('a legacy slot the current recipe dropped is empty', () {
      final t = tokens(builtInRaftTheme);
      final mask = RaftAppRailRecipe.resolve(
        theme: RaftRecipeTheme.elegant,
        tokens: t.recipeTokens,
      ).itemAttentionMask;
      expect(mask.properties, isEmpty);
    });

    test('a resolver that names no set keeps the frozen recipes', () {
      final frozen = RaftButtonRecipe.resolve(theme: RaftRecipeTheme.elegant);
      expect(frozen.root.fontSize, 14);
    });
  });
}
