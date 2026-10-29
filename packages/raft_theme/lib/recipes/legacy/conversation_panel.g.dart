// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `conversationPanel`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `conversationPanel` (`src/components/conversation-panel/conversation-panel.recipe.ts`, index.mjs:4514).
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

  static RaftConversationPanelRecipeStyle resolve({
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
    [1644, 1980, 2583, 2597, 1645, 1646, 868, 1716, 2994],
    [1644, 2583, 2597, 1645, 1646, 868],
    [
      2902,
      891,
      892,
      868,
      112,
      111,
      109,
      110,
      108,
      107,
      244,
      247,
      243,
      242,
      241,
    ],
    [927, 892, 868],
    [1644, 1980, 2583, 2597, 1645, 1646, 2804, 825, 1716, 3024],
    [
      1644,
      2583,
      2597,
      1645,
      1646,
      2804,
      2678,
      830,
      1013,
      1766,
      1767,
      1768,
      1092,
    ],
    [2902, 890, 830, 2417, 1022, 1137, 2420, 2421, 248, 245, 246, 2409],
    [],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 5, 6, 7],
  ];
}
