// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `emptyState`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftEmptyStateRecipe].
class RaftEmptyStateRecipeStyle {
  const RaftEmptyStateRecipeStyle({required this.root, required this.content, required this.icon, required this.title, required this.description, required this.actions});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'content': content, 'icon': icon, 'title': title, 'description': description, 'actions': actions};
}

/// raft-ui recipe `emptyState` (`src/components/empty-state/empty-state.tsx`, index.mjs:14605).
///
/// Used by: EmptyState, EmptyStateActions, EmptyStateContent, EmptyStateDescription, EmptyStateIcon, EmptyStateTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftEmptyStateRecipe {
  static const String recipeName = 'emptyState';
  static const List<String> slotNames = ['root', 'content', 'icon', 'title', 'description', 'actions'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftEmptyStateRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftEmptyStateRecipeStyle(root: s[0], content: s[1], icon: s[2], title: s[3], description: s[4], actions: s[5]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 3127, 2574, 1622, 2312, 2317, 2757, 2764, 2970],
    [1620, 3127, 2488, 2574, 1622, 2312, 1698, 2970, 230, 231],
    [2495, 2301, 2312, 2317, 427, 2981, 435],
    [2493, 3127, 2484, 2970, 2954, 1687, 3004, 1692, 2993],
    [2607, 3127, 2472, 2970, 3017, 2345, 3005, 259, 260, 258, 2993],
    [2604],
    [2495, 2301, 2312, 2317, 427, 2818, 795, 2671, 2984, 432, 995, 1140],
    [2493, 3127, 2484, 2970, 2954, 1687, 3017, 1688, 2976, 1166],
    [2607, 3127, 2472, 2970, 3017, 2345, 3005, 259, 260, 258, 2981],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5], [0, 1, 6, 7, 8, 5],
  ];
}
