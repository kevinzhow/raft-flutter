// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `comment`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftCommentRecipe].
class RaftCommentRecipeStyle {
  const RaftCommentRecipeStyle({
    required this.margin,
    required this.marginItem,
    required this.card,
    required this.cardTrigger,
    required this.cardQuote,
    required this.cardMeta,
    required this.entry,
    required this.entryHeader,
    required this.entryAuthor,
    required this.entryTime,
    required this.entryBody,
    required this.marker,
  });

  /// Slot `margin`.
  final RaftSlotStyle margin;

  /// Slot `marginItem`.
  final RaftSlotStyle marginItem;

  /// Slot `card`.
  final RaftSlotStyle card;

  /// Slot `cardTrigger`.
  final RaftSlotStyle cardTrigger;

  /// Slot `cardQuote`.
  final RaftSlotStyle cardQuote;

  /// Slot `cardMeta`.
  final RaftSlotStyle cardMeta;

  /// Slot `entry`.
  final RaftSlotStyle entry;

  /// Slot `entryHeader`.
  final RaftSlotStyle entryHeader;

  /// Slot `entryAuthor`.
  final RaftSlotStyle entryAuthor;

  /// Slot `entryTime`.
  final RaftSlotStyle entryTime;

  /// Slot `entryBody`.
  final RaftSlotStyle entryBody;

  /// Slot `marker`.
  final RaftSlotStyle marker;

  Map<String, RaftSlotStyle> get slots => {
    'margin': margin,
    'marginItem': marginItem,
    'card': card,
    'cardTrigger': cardTrigger,
    'cardQuote': cardQuote,
    'cardMeta': cardMeta,
    'entry': entry,
    'entryHeader': entryHeader,
    'entryAuthor': entryAuthor,
    'entryTime': entryTime,
    'entryBody': entryBody,
    'marker': marker,
  };
}

/// raft-ui recipe `comment` (`dist/components/comment/comment.recipe.mjs`, index.mjs:26598).
///
/// Used by: CommentCard, CommentCardMeta, CommentCardQuote, CommentCardTrigger, CommentEntry, CommentEntryAuthor, CommentEntryBody, CommentEntryHeader, CommentEntryTime, CommentMargin, CommentMarginItem, CommentMarker.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCommentRecipe {
  static const String recipeName = 'comment';
  static const List<String> slotNames = [
    'margin',
    'marginItem',
    'card',
    'cardTrigger',
    'cardQuote',
    'cardMeta',
    'entry',
    'entryHeader',
    'entryAuthor',
    'entryTime',
    'entryBody',
    'marker',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('clamp', ['true', 'false'], null, true),
  ];

  static RaftCommentRecipeStyle resolve({
    bool? clamp,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [clamp?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftCommentRecipeStyle(
      margin: s[0],
      marginItem: s[1],
      card: s[2],
      cardTrigger: s[3],
      cardQuote: s[4],
      cardMeta: s[5],
      entry: s[6],
      entryHeader: s[7],
      entryAuthor: s[8],
      entryTime: s[9],
      entryBody: s[10],
      marker: s[11],
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
    [2433, 2116],
    [691, 1858, 2640, 1150, 1148, 1149, 2138, 1147],
    [
      2433,
      1400,
      2116,
      1404,
      1466,
      2462,
      939,
      953,
      2264,
      911,
      2598,
      2497,
      2247,
      1129,
      1130,
      1135,
      1144,
    ],
    [691, 169, 2747, 997, 2462, 940, 933, 2260, 1786, 697, 2247, 1439],
    [2539],
    [
      1400,
      2116,
      1864,
      1464,
      1456,
      2588,
      2600,
      477,
      474,
      666,
      662,
      661,
      671,
      673,
      664,
      674,
      668,
      672,
      670,
      669,
    ],
    [1400, 2116, 1404, 1464, 637],
    [1400, 2116, 1864, 1465, 86],
    [2116, 2681, 2622, 1449, 2598],
    [2499, 2729, 1454, 2616, 2556, 2600],
    [2734, 2485, 2587, 2598, 2486],
    [
      2433,
      1847,
      1658,
      2499,
      1864,
      1464,
      762,
      2729,
      2461,
      939,
      953,
      2412,
      2374,
      2292,
      1454,
      2616,
      1449,
      2556,
      2598,
      911,
      997,
      1794,
      699,
      1129,
      1130,
      1127,
      1137,
      1136,
      1278,
      1279,
      1275,
      1283,
      1282,
      2247,
      1439,
      723,
      710,
      716,
    ],
    [2734, 2485, 2587, 2598, 2486, 1901],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 11],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
