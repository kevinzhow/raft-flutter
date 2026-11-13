// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `listRowSkeleton`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftListRowSkeletonRecipe].
class RaftListRowSkeletonRecipeStyle {
  const RaftListRowSkeletonRecipeStyle({
    required this.row,
    required this.avatar,
    required this.icon,
    required this.bar,
    required this.titleBar,
    required this.descriptionBar,
    required this.metaBar,
  });

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `avatar`.
  final RaftSlotStyle avatar;

  /// Slot `icon`.
  final RaftSlotStyle icon;

  /// Slot `bar`.
  final RaftSlotStyle bar;

  /// Slot `titleBar`.
  final RaftSlotStyle titleBar;

  /// Slot `descriptionBar`.
  final RaftSlotStyle descriptionBar;

  /// Slot `metaBar`.
  final RaftSlotStyle metaBar;

  Map<String, RaftSlotStyle> get slots => {
    'row': row,
    'avatar': avatar,
    'icon': icon,
    'bar': bar,
    'titleBar': titleBar,
    'descriptionBar': descriptionBar,
    'metaBar': metaBar,
  };
}

/// raft-ui recipe `listRowSkeleton` (`dist/components/list-row/list-row-skeleton.mjs`, index.mjs:25856).
///
/// Used by: ListRowSkeleton.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftListRowSkeletonRecipe {
  static const String recipeName = 'listRowSkeleton';
  static const List<String> slotNames = [
    'row',
    'avatar',
    'icon',
    'bar',
    'titleBar',
    'descriptionBar',
    'metaBar',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftListRowSkeletonRecipeStyle resolve({
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
    return RaftListRowSkeletonRecipeStyle(
      row: s[0],
      avatar: s[1],
      icon: s[2],
      bar: s[3],
      titleBar: s[4],
      descriptionBar: s[5],
      metaBar: s[6],
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
    [559, 558, 2217, 2216, 2222, 2221],
    [2529, 2499],
    [2519, 2499],
    [1846, 1664, 1980, 761],
    [2690],
    [2689],
    [2710],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
