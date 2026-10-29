// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `conversationPanelEmptyState` (`src/components/conversation-panel/conversation-panel-empty-state.tsx`, index.mjs:3646).
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
      965,
      1198,
      1468,
      1484,
      966,
      967,
      1319,
      1324,
      1816,
      1023,
      1663,
      1677,
      1016,
      1833,
      1008,
      1529,
      1827,
    ],
    [1740, 1431, 1305, 1714, 1592, 1824],
    [1682, 965, 1319, 1324, 174, 193, 1758, 1584, 1714, 182, 186],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
