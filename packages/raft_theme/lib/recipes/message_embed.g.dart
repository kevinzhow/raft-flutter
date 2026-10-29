// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageEmbed`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageEmbedRecipe].
class RaftMessageEmbedRecipeStyle {
  const RaftMessageEmbedRecipeStyle({
    required this.root,
    required this.header,
    required this.content,
    required this.footer,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'content': content,
    'footer': footer,
  };
}

/// raft-ui recipe `messageEmbed` (`src/components/message-embed/message-embed.recipe.ts`, index.mjs:8017).
///
/// Used by: MessageEmbed, MessageEmbedContent, MessageEmbedFooter, MessageEmbedHeader, MessageReplies.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageEmbedRecipe {
  static const String recipeName = 'messageEmbed';
  static const List<String> slotNames = ['root', 'header', 'content', 'footer'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageEmbedRecipeStyle resolve({
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
    return RaftMessageEmbedRecipeStyle(
      root: s[0],
      header: s[1],
      content: s[2],
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
    [1050, 618, 1484, 1836, 1709, 620, 633, 596, 1577, 996],
    [1484, 1660, 1671],
    [1484],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 1],
  ];
}
