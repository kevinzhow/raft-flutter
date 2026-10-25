// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `input`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftInputRecipe].
class RaftInputRecipeStyle {
  const RaftInputRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `input` (`src/components/input/input.recipe.ts`, index.mjs:6289).
///
/// Used by: ComboboxInput, ComposerInput, Input.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInputRecipe {
  static const String recipeName = 'input';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static const List<RaftRecipePackBinding> _packBindings = [
    RaftRecipePackBinding(
      'root',
      'border-top-left-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-top-right-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-bottom-left-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-bottom-right-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
  ];

  static RaftInputRecipeStyle resolve({
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
      bindings: _packBindings,
    );
    return RaftInputRecipeStyle(root: s[0]);
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
      bindings: _packBindings,
    );
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [
      3168,
      2781,
      2794,
      1712,
      3012,
      1711,
      2672,
      878,
      916,
      830,
      2897,
      1704,
      1523,
      1522,
      1535,
      1533,
      1534,
    ],
    [
      3168,
      1712,
      3012,
      1711,
      2672,
      2848,
      876,
      910,
      830,
      1013,
      1143,
      1161,
      1130,
      2781,
      2794,
      3013,
      3102,
      1629,
      1637,
      1187,
      2735,
      2894,
      2283,
      1699,
      1091,
      1676,
      1689,
      1083,
      1086,
      1524,
      1532,
      1527,
      1529,
      1531,
      1608,
      1606,
      1605,
      1617,
      1613,
      1609,
      1525,
      1526,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
  ];
}
