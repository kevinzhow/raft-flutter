// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `conversationPanelEmptyState`.
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

/// raft-ui recipe `conversationPanelEmptyState` (`dist/components/conversation-panel/conversation-panel-empty-state.mjs`, index.mjs:5335).
///
/// Used by: ConversationPanelEmptyState, ConversationPanelEmptyStateBrand, ConversationPanelEmptyStateBrandMark.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftConversationPanelEmptyStateRecipe {
  static const String recipeName = 'conversationPanelEmptyState';
  static const List<String> slotNames = ['root', 'brand', 'brandMark'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftConversationPanelEmptyStateRecipeStyle resolve({
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
      1400,
      1678,
      2098,
      2116,
      1401,
      1404,
      1864,
      1869,
      2590,
      1466,
      2396,
      2423,
      1456,
      2609,
      1449,
      2165,
      2603,
    ],
    [2499, 1988, 1847, 2468, 2260, 2600],
    [2433, 1400, 1864, 1869, 345, 365, 2523, 2253, 2468, 354, 357],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
