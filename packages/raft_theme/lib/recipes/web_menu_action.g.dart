// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `webMenuAction`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftWebMenuActionRecipe].
class RaftWebMenuActionRecipeStyle {
  const RaftWebMenuActionRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `webMenuAction` (`Web src/components/ui/MenuItem.tsx sha256:3cd601e7b3a45d7ec37cd5d88acedc4ee339d981789fa87ed791530cbbb14597`, index.mjs:1).
///
/// Used by: MenuItem.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftWebMenuActionRecipe {
  static const String recipeName = 'webMenuAction';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftWebMenuActionRecipeStyle resolve({
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
    return RaftWebMenuActionRecipeStyle(root: s[0]);
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
      965,
      1479,
      1926,
      1319,
      1024,
      1708,
      1657,
      1667,
      1834,
      386,
      390,
      1016,
      1811,
      1013,
      1820,
      1575,
      1891,
      953,
      952,
      177,
      157,
      928,
      938,
      917,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
