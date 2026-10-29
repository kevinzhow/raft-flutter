// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `messageMultiSelect` (`src/components/message-item/message-multi-select.recipe.ts`, index.mjs:7790).
///
/// Used by: MessageMultiSelect, MessageMultiSelectCheckbox, MessageMultiSelectToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageMultiSelectRecipe {
  static const String recipeName = 'messageMultiSelect';
  static const List<String> slotNames = ['root', 'checkbox', 'toolbar'];
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
    [965, 1468, 1484, 966, 967],
    [1731, 820, 866, 1279, 1280, 1513, 1716],
    [965, 1319, 1023, 1709, 1659, 1671, 602, 1694, 1698, 1737],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
