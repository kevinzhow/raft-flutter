@Tags(['look-brutal', 'look-elegant'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/recipe_runtime.dart' show RaftRecipeTheme;

/// Recipe selection is derived from a geometry token, never from a theme name.
///
/// The generated recipes were produced from two CSS themes, so their resolver
/// takes a two-valued enum. Which one a look gets must follow the contract, or
/// Brutal keeps painting Elegant's radii and strokes.
void main() {
  group('raftRecipeTheme', () {
    RaftRecipeTheme themeFor(String id) =>
        raftRecipeTheme(RaftTokens.theme(pack: packForThemeId(id)));

    test('Raft and Elegant keep the elegant recipe set', () {
      // Raft rendered this way before the helper derived anything, so this half
      // is a regression guard: if it flips, every recipe-driven screen changes.
      expect(themeFor(raftThemePackId), RaftRecipeTheme.elegant);
      expect(themeFor(elegantThemePackId), RaftRecipeTheme.elegant);
    });

    test('Brutal gets the brutal recipe set', () {
      // Square corners and 2px rules; it used to get `elegant` here, which is
      // why recipe-driven screens could never match the Brutal baseline.
      expect(themeFor(brutalThemePackId), RaftRecipeTheme.brutal);
    });

    test('the choice follows radius.control, not the theme id', () {
      // A theme is not special-cased by name: any pack whose control radius is
      // zero takes the brutal set, and any pack that rounds takes the elegant
      // one. Proved by building packs that are not the built-ins.
      final squared = RaftThemePack.parse('''
{
  "format": "raft-theme/1",
  "id": "test-squared",
  "name": {"en": "Squared"},
  "version": "1.0.0",
  "extends": "raft",
  "modes": {
    "light": {"geometry": {"radius.control": 0}},
    "dark": {"geometry": {"radius.control": 0}}
  }
}
''');
      final rounded = RaftThemePack.parse('''
{
  "format": "raft-theme/1",
  "id": "test-rounded",
  "name": {"en": "Rounded"},
  "version": "1.0.0",
  "extends": "raft",
  "modes": {
    "light": {"geometry": {"radius.control": 4}},
    "dark": {"geometry": {"radius.control": 4}}
  }
}
''');
      expect(
        raftRecipeTheme(RaftTokens.theme(pack: squared)),
        RaftRecipeTheme.brutal,
      );
      expect(
        raftRecipeTheme(RaftTokens.theme(pack: rounded)),
        RaftRecipeTheme.elegant,
      );
    });

    test('a token-less token set falls back to the elegant set', () {
      // Tests and previews build RaftTokens without a pack; the fallback must
      // match what the app painted historically.
      expect(raftRecipeTheme(RaftTokens.theme()), RaftRecipeTheme.elegant);
    });
  });
}
