// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `emptyState`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftEmptyStateRecipe].
class RaftEmptyStateRecipeStyle {
  const RaftEmptyStateRecipeStyle({
    required this.root,
    required this.content,
    required this.icon,
    required this.title,
    required this.description,
    required this.actions,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `icon`.
  final RaftSlotStyle icon;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'content': content,
    'icon': icon,
    'title': title,
    'description': description,
    'actions': actions,
  };
}

/// raft-ui recipe `emptyState` (`src/components/empty-state/empty-state.tsx`, index.mjs:12344).
///
/// Used by: EmptyState, EmptyStateActions, EmptyStateContent, EmptyStateDescription, EmptyStateIcon, EmptyStateTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftEmptyStateRecipe {
  static const String recipeName = 'emptyState';
  static const List<String> slotNames = [
    'root',
    'content',
    'icon',
    'title',
    'description',
    'actions',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftEmptyStateRecipeStyle resolve({
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
    return RaftEmptyStateRecipeStyle(
      root: s[0],
      content: s[1],
      icon: s[2],
      title: s[3],
      description: s[4],
      actions: s[5],
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
    [965, 1926, 1483, 967, 1319, 1324, 1662, 1668, 1814],
    [965, 1926, 1428, 1483, 967, 1319, 1023, 1814, 135, 136],
    [1433, 1305, 1319, 1324, 277, 1822, 285],
    [1432, 1926, 1424, 1814, 1806, 1016, 1831, 1008, 1825],
    [1518, 1926, 1814, 1838, 147, 148, 146, 1410, 1811, 1822],
    [1514],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
  ];
}
