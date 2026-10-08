// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `conversationPanelEmptyState`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftConversationPanelEmptyStateRecipe].
class RaftConversationPanelEmptyStateRecipeStyle {
  const RaftConversationPanelEmptyStateRecipeStyle({required this.root, required this.brand, required this.brandMark});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `brand`.
  final RaftSlotStyle brand;
  /// Slot `brandMark`.
  final RaftSlotStyle brandMark;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'brand': brand, 'brandMark': brandMark};
}

/// raft-ui recipe `conversationPanelEmptyState` (`src/components/conversation-panel/conversation-panel-empty-state.tsx`, index.mjs:4608).
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

  static RaftConversationPanelEmptyStateRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftConversationPanelEmptyStateRecipeStyle(root: s[0], brand: s[1], brandMark: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 1978, 2560, 2574, 1621, 1622, 2312, 2317, 1700, 2970, 1687, 3004, 1684, 2959, 3096],
    [2174, 2867, 2818, 2668],
    [2775, 1620, 2885, 2312, 2317, 2656, 2822, 299, 322, 295, 321],
    [1620, 1978, 2560, 2574, 1621, 1622, 2312, 2317, 1700, 2970, 1687, 3017, 1688, 3055, 2981],
    [2867, 2818, 2668, 862, 832, 2862, 2791, 2801, 1133],
    [2775, 1620, 2885, 2312, 2317, 2656, 2822, 299, 322, 295, 321, 833, 2862, 2791, 2801, 1133, 718, 688, 710, 731, 720, 695, 703, 966],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 4, 5],
  ];
}
