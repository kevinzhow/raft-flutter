// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `conversationPanelEmptyState`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftConversationPanelEmptyStateRecipe].
class RaftConversationPanelEmptyStateRecipeStyle {
  const RaftConversationPanelEmptyStateRecipeStyle({
    required this.root,
    required this.brand,
    required this.brandMark,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `brand`.
  final RaftSlotStyle brand;

  /// Slot `brandMark`.
  final RaftSlotStyle brandMark;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'brand': brand,
    'brandMark': brandMark,
  };
}

/// raft-ui recipe `conversationPanelEmptyState` (`src/components/conversation-panel/conversation-panel-empty-state.tsx`, index.mjs:4620).
///
/// Used by: ConversationPanelEmptyState, ConversationPanelEmptyStateBrand, ConversationPanelEmptyStateBrandMark.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftConversationPanelEmptyStateRecipe {
  static const String recipeName = 'conversationPanelEmptyState';
  static const List<String> slotNames = ['root', 'brand', 'brandMark'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftConversationPanelEmptyStateRecipeStyle resolve({
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
    return RaftConversationPanelEmptyStateRecipeStyle(
      root: s[0],
      brand: s[1],
      brandMark: s[2],
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
    [
      1644,
      1980,
      2583,
      2597,
      1645,
      1646,
      2331,
      2336,
      1725,
      3007,
      1712,
      3041,
      1709,
      2996,
      3137,
    ],
    [2189, 2902, 2848, 2691],
    [2804, 1644, 2920, 2331, 2336, 2679, 2852, 295, 318, 291, 317],
    [
      1644,
      1980,
      2583,
      2597,
      1645,
      1646,
      2331,
      2336,
      1725,
      3007,
      1712,
      3053,
      1713,
      3096,
      3018,
    ],
    [2902, 2848, 2691, 874, 837, 2896, 2821, 2831, 1152],
    [
      2804,
      1644,
      2920,
      2331,
      2336,
      2679,
      2852,
      295,
      318,
      291,
      317,
      838,
      2896,
      2821,
      2831,
      1152,
      724,
      694,
      716,
      737,
      726,
      701,
      709,
      986,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 4, 5],
  ];
}
