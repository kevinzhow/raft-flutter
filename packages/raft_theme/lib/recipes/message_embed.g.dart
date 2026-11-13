// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageEmbed`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `messageEmbed`.
enum RaftMessageEmbedRecipeSize {
  item('item'),
  content('content');

  const RaftMessageEmbedRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

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

/// raft-ui recipe `messageEmbed` (`dist/components/message-embed/message-embed.recipe.mjs`, index.mjs:7002).
///
/// Used by: AppLinkCard, AppLinkCardPlaceholder, MessageEmbed, MessageEmbedContent, MessageEmbedFooter, MessageEmbedHeader, MessageReplies.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageEmbedRecipe {
  static const String recipeName = 'messageEmbed';
  static const List<String> slotNames = ['root', 'header', 'content', 'footer'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['item', 'content'], null, true),
  ];

  static RaftMessageEmbedRecipeStyle resolve({
    RaftMessageEmbedRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css],
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
    [
      1503,
      937,
      2116,
      2613,
      2462,
      939,
      953,
      911,
      2247,
      1439,
      1036,
      1034,
      2171,
      2170,
      2173,
      2172,
    ],
    [2116, 2403, 2417],
    [2116],
    [
      1503,
      937,
      2116,
      2613,
      2462,
      939,
      953,
      911,
      2247,
      1439,
      1036,
      1034,
      2171,
      2170,
      2173,
      2172,
      2725,
      1968,
      1941,
    ],
    [
      1503,
      937,
      2116,
      2613,
      2462,
      939,
      953,
      911,
      2247,
      1439,
      1036,
      1034,
      2171,
      2170,
      2173,
      2172,
      2725,
      1971,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 1],
    [3, 1, 2, 1],
    [4, 1, 2, 1],
  ];
}
