// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageMultiSelect`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageMultiSelectRecipe].
class RaftMessageMultiSelectRecipeStyle {
  const RaftMessageMultiSelectRecipeStyle({
    required this.root,
    required this.checkbox,
    required this.toolbar,
    required this.toolbarActions,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `checkbox`.
  final RaftSlotStyle checkbox;

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  /// Slot `toolbarActions`.
  final RaftSlotStyle toolbarActions;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'checkbox': checkbox,
    'toolbar': toolbar,
    'toolbarActions': toolbarActions,
  };
}

/// raft-ui recipe `messageMultiSelect` (`dist/components/message-item/message-multi-select.recipe.mjs`, index.mjs:12674).
///
/// Used by: MessageMultiSelect, MessageMultiSelectCheckbox, MessageMultiSelectToolbar, MessageMultiSelectToolbarActions.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageMultiSelectRecipe {
  static const String recipeName = 'messageMultiSelect';
  static const List<String> slotNames = [
    'root',
    'checkbox',
    'toolbar',
    'toolbarActions',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageMultiSelectRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageMultiSelectRecipeStyle(
      root: s[0],
      checkbox: s[1],
      toolbar: s[2],
      toolbarActions: s[3],
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
    [1400, 2098, 2116, 1401, 1404],
    [2489, 1165, 1246, 1791, 1792, 2147, 2471],
    [
      1400,
      1864,
      1466,
      2462,
      2414,
      2355,
      2299,
      13,
      18,
      15,
      16,
      10,
      12,
      14,
      2312,
      915,
      2445,
      2449,
      2496,
    ],
    [1400, 2116, 1401, 1408, 1864, 1870, 1464],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
