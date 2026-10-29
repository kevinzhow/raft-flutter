@Tags(['look-elegant', 'look-brutal'])
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

void main() {
  test('all legacy Input declarations remain source exact in both modes', () {
    for (final pack in [builtInElegantTheme, builtInBrutalTheme]) {
      for (final dark in [false, true]) {
        final t = RaftTokens.theme(pack: pack, dark: dark);
        for (final flags in [
          <String>{},
          {'hover'},
          {'focus', 'focus-visible'},
          {'disabled'},
        ]) {
          final states = RaftRecipeStates({...flags, if (dark) 'dark'});
          final source = RaftInputRecipe.resolve(
            theme: raftRecipeTheme(t),
            states: states,
            tokens: t.recipeSourceTokens,
          ).root;
          final bound = RaftInputRecipe.resolve(
            theme: raftRecipeTheme(t),
            states: states,
            tokens: t.recipeTokens,
          ).root;
          Map<String, Object?> values(RaftSlotStyle s) => {
            'self': {
              for (final e in s.properties.entries)
                if (!e.key.startsWith('border-') || !e.key.endsWith('-radius'))
                  e.key: e.value.toJson(),
            },
            'targets': {
              for (final target in s.targets.entries)
                target.key: {
                  for (final e in target.value.entries) e.key: e.value.toJson(),
                },
            },
          };
          expect(
            bound.borderRadius ?? BorderRadius.zero,
            source.borderRadius ?? BorderRadius.zero,
            reason: 'zero radius may be omitted in source CSS',
          );
          expect(
            values(bound),
            values(source),
            reason: '${pack.id} dark=$dark $flags',
          );
        }
      }
    }
  });
}
