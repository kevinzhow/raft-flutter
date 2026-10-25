import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

void main() {
  test('generated Input reads control radius without changing its padding', () {
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': 'raft-theme/1',
        'id': 'test-recipe-input',
        'name': {'en': 'Recipe input'},
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          for (final mode in ['light', 'dark'])
            mode: {
              'geometry': {'radius.control': 39, 'radius.field': 23},
            },
        },
      }),
    );
    for (final dark in [false, true]) {
      final t = RaftTokens.theme(pack: pack, dark: dark);
      for (final flags in [
        <String>{},
        {'hover'},
        {'focus'},
        {'disabled'},
      ]) {
        final style = RaftInputRecipe.resolve(
          theme: raftRecipeTheme(t),
          states: RaftRecipeStates({...flags, if (dark) 'dark'}),
          tokens: t.recipeTokens,
        ).root;
        expect(style.borderRadius, BorderRadius.circular(39));
        expect(
          style.padding.left,
          12,
          reason: 'a different property stays intact',
        );
      }
    }
  });
}
