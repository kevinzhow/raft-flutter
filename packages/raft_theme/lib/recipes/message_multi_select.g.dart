// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageMultiSelect`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageMultiSelectRecipe].
class RaftMessageMultiSelectRecipeStyle {
  const RaftMessageMultiSelectRecipeStyle({
    required this.root,
    required this.checkbox,
    required this.toolbar,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `checkbox`.
  final RaftSlotStyle checkbox;

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'checkbox': checkbox,
    'toolbar': toolbar,
  };
}

/// raft-ui recipe `messageMultiSelect` (`src/components/message-item/message-multi-select.recipe.ts`, index.mjs:10070).
///
/// Used by: MessageMultiSelect, MessageMultiSelectCheckbox, MessageMultiSelectToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageMultiSelectRecipe {
  static const String recipeName = 'messageMultiSelect';
  static const List<String> slotNames = ['root', 'checkbox', 'toolbar'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageMultiSelectRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageMultiSelectRecipeStyle(
      root: s[0],
      checkbox: s[1],
      toolbar: s[2],
    );
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(
    Map<String, String?> props, {
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [for (final a in axes) props[a.name]],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1644, 2583, 2597, 1645, 1646],
    [2622, 2871, 2845, 1450, 1518, 2276, 2279],
    [1644, 2331, 1722, 927, 916, 836, 2779, 2761, 2715],
    [1644, 2331, 1722, 2847, 879, 912, 830, 2780, 2795, 2899, 1029],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [0, 1, 3],
  ];
}
