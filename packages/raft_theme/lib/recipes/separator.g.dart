// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `separator`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSeparatorRecipe].
class RaftSeparatorRecipeStyle {
  const RaftSeparatorRecipeStyle({
    required this.root,
    required this.labeledRoot,
    required this.labeledLine,
    required this.labeledContent,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `labeledRoot`.
  final RaftSlotStyle labeledRoot;

  /// Slot `labeledLine`.
  final RaftSlotStyle labeledLine;

  /// Slot `labeledContent`.
  final RaftSlotStyle labeledContent;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'labeledRoot': labeledRoot,
    'labeledLine': labeledLine,
    'labeledContent': labeledContent,
  };
}

/// raft-ui recipe `separator` (`dist/components/separator/separator.mjs`, index.mjs:19702).
///
/// Used by: Separator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSeparatorRecipe {
  static const String recipeName = 'separator';
  static const List<String> slotNames = [
    'root',
    'labeledRoot',
    'labeledLine',
    'labeledContent',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSeparatorRecipeStyle resolve({
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
    return RaftSeparatorRecipeStyle(
      root: s[0],
      labeledRoot: s[1],
      labeledLine: s[2],
      labeledContent: s[3],
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
    [2499, 1054, 1057, 918, 1052, 1058],
    [1489, 1496, 1864, 1468, 2419],
    [2725, 2499, 1680, 918],
    [2116, 1456, 2597, 1457, 2600],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
