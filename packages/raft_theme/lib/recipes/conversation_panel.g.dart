// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `conversationPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftConversationPanelRecipe].
class RaftConversationPanelRecipeStyle {
  const RaftConversationPanelRecipeStyle({
    required this.root,
    required this.content,
    required this.tabs,
    required this.footer,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `tabs`.
  final RaftSlotStyle tabs;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'content': content,
    'tabs': tabs,
    'footer': footer,
  };
}

/// raft-ui recipe `conversationPanel` (`dist/components/conversation-panel/conversation-panel.recipe.mjs`, index.mjs:5263).
///
/// Used by: ConversationPanelContent, ConversationPanelFooter, ConversationPanelRoot, ConversationPanelTabs, ProfilePanelBody.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftConversationPanelRecipe {
  static const String recipeName = 'conversationPanel';
  static const List<String> slotNames = ['root', 'content', 'tabs', 'footer'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftConversationPanelRecipeStyle resolve({
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
    return RaftConversationPanelRecipeStyle(
      root: s[0],
      content: s[1],
      tabs: s[2],
      footer: s[3],
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
    [1400, 1678, 2098, 2116, 1401, 1404, 910, 1456, 2598],
    [1400, 2098, 2116, 1401, 1404, 910],
    [2499, 942, 954, 910, 144, 143, 1930, 2011, 142, 2010],
    [2378, 910],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
