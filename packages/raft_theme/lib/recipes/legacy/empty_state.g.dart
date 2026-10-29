// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `emptyState`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `emptyState` (`src/components/empty-state/empty-state.tsx`, index.mjs:14827).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftEmptyStateRecipeStyle resolve({
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
    [1644, 3168, 2597, 1646, 2331, 2336, 2785, 2793, 3007],
    [1644, 3168, 2509, 2597, 1646, 2331, 1723, 3007, 228, 229],
    [2516, 2320, 2331, 2336, 425, 3018, 433],
    [2514, 3168, 2505, 3007, 2992, 1712, 3041, 1717, 3030],
    [2629, 3168, 2493, 3007, 3053, 2364, 3042, 255, 256, 254, 3030],
    [2627],
    [2516, 2320, 2331, 2336, 425, 2848, 801, 2694, 3021, 430, 1015, 1159],
    [2514, 3168, 2505, 3007, 2992, 1712, 3053, 1713, 3013, 1185],
    [2629, 3168, 2493, 3007, 3053, 2364, 3042, 255, 256, 254, 3018],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [0, 1, 6, 7, 8, 5],
  ];
}
