// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `conversationPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftConversationPanelRecipe].
class RaftConversationPanelRecipeStyle {
  const RaftConversationPanelRecipeStyle({required this.root, required this.content, required this.tabs, required this.footer});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `tabs`.
  final RaftSlotStyle tabs;
  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'content': content, 'tabs': tabs, 'footer': footer};
}

/// raft-ui recipe `conversationPanel` (`src/components/conversation-panel/conversation-panel.recipe.ts`, index.mjs:4499).
///
/// Used by: ConversationPanelContent, ConversationPanelFooter, ConversationPanelRoot, ConversationPanelTabs, ProfilePanelBody.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftConversationPanelRecipe {
  static const String recipeName = 'conversationPanel';
  static const List<String> slotNames = ['root', 'content', 'tabs', 'footer'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftConversationPanelRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftConversationPanelRecipeStyle(root: s[0], content: s[1], tabs: s[2], footer: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 1978, 2560, 2574, 1621, 1622, 856, 1691, 2956],
    [1620, 2560, 2574, 1621, 1622, 856],
    [2867, 875, 876, 856, 112, 111, 109, 110, 108, 106, 248, 251, 245, 247, 246, 244],
    [913, 876, 856],
    [1620, 1978, 2560, 2574, 1621, 1622, 2775, 820, 1691, 2987],
    [1620, 2560, 2574, 1621, 1622, 2775, 2655, 825, 993, 1741, 1742, 1743, 1072],
    [2867, 874, 825, 2395, 1002, 1117, 2398, 2399, 107, 252, 249, 250, 243, 2390],
    [],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 5, 6, 7],
  ];
}
