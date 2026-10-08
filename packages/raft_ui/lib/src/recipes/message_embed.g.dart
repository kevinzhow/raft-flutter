// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageEmbed`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageEmbedRecipe].
class RaftMessageEmbedRecipeStyle {
  const RaftMessageEmbedRecipeStyle({required this.root, required this.header, required this.content, required this.footer});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'content': content, 'footer': footer};
}

/// raft-ui recipe `messageEmbed` (`src/components/message-embed/message-embed.recipe.ts`, index.mjs:10298).
///
/// Used by: MessageEmbed, MessageEmbedContent, MessageEmbedFooter, MessageEmbedHeader, MessageReplies.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageEmbedRecipe {
  static const String recipeName = 'messageEmbed';
  static const List<String> slotNames = ['root', 'header', 'content', 'footer'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageEmbedRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageEmbedRecipeStyle(root: s[0], header: s[1], content: s[2], footer: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1726, 862, 2574, 3003, 864, 879, 856],
    [2574, 873, 877, 856, 2752, 2763],
    [2574, 856],
    [2574, 911, 877, 856, 2753, 2763],
    [1726, 862, 2574, 3003, 821, 2865, 3065, 1602, 2186, 2269, 2817, 867, 896, 2675, 1009, 1638, 1627, 1641],
    [2574, 2753, 2763, 2894],
    [2574, 2655, 2809, 867, 896, 825, 3084, 1602, 1906, 1009, 1138],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 5, 6, 5],
  ];
}
