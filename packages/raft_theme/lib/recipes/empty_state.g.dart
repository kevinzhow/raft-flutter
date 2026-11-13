// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `emptyState`.
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

/// raft-ui recipe `emptyState` (`dist/components/empty-state/empty-state.mjs`, index.mjs:18230).
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
    [1400, 2725, 2116, 1404, 1864, 1869, 2407, 2068, 2416, 2590],
    [1400, 2725, 1984, 2116, 1404, 1864, 1466, 2590, 294, 295],
    [1991, 1847, 1864, 1869, 474, 2600, 483],
    [1989, 2725, 1980, 2590, 2583, 1456, 2609, 1449, 2603],
    [2156, 2725, 2590, 2617, 307, 306, 310, 308, 309, 1965, 2587, 2600],
    [2150],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
  ];
}
