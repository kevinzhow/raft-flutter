// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `kbd`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftKbdRecipe].
class RaftKbdRecipeStyle {
  const RaftKbdRecipeStyle({required this.root, required this.group});

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `group`.
  final RaftSlotStyle group;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'group': group};
}

/// raft-ui recipe `kbd` (`src/components/kbd/kbd.tsx`, index.mjs:3699).
///
/// Used by: Kbd, KbdGroup.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftKbdRecipe {
  static const String recipeName = 'kbd';
  static const List<String> slotNames = ['root', 'group'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftKbdRecipeStyle resolve({
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
    return RaftKbdRecipeStyle(root: s[0], group: s[1]);
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
    [
      1626,
      1304,
      1923,
      1736,
      1318,
      1323,
      1020,
      1928,
      1723,
      275,
      263,
      1485,
      1701,
      1652,
      1013,
      1835,
      1014,
      1820,
      1308,
      1310,
      1292,
      1291,
    ],
    [1304, 1318, 1020],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1],
  ];
}
