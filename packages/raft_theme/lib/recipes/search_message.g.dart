// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `searchMessage`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchMessageRecipe].
class RaftSearchMessageRecipeStyle {
  const RaftSearchMessageRecipeStyle({
    required this.message,
    required this.messageHeader,
    required this.messageBody,
    required this.messageMeta,
    required this.messageThreadMeta,
    required this.messageSender,
    required this.messageTimestamp,
    required this.messageMatch,
  });

  /// Slot `message`.
  final RaftSlotStyle message;

  /// Slot `messageHeader`.
  final RaftSlotStyle messageHeader;

  /// Slot `messageBody`.
  final RaftSlotStyle messageBody;

  /// Slot `messageMeta`.
  final RaftSlotStyle messageMeta;

  /// Slot `messageThreadMeta`.
  final RaftSlotStyle messageThreadMeta;

  /// Slot `messageSender`.
  final RaftSlotStyle messageSender;

  /// Slot `messageTimestamp`.
  final RaftSlotStyle messageTimestamp;

  /// Slot `messageMatch`.
  final RaftSlotStyle messageMatch;

  Map<String, RaftSlotStyle> get slots => {
    'message': message,
    'messageHeader': messageHeader,
    'messageBody': messageBody,
    'messageMeta': messageMeta,
    'messageThreadMeta': messageThreadMeta,
    'messageSender': messageSender,
    'messageTimestamp': messageTimestamp,
    'messageMatch': messageMatch,
  };
}

/// raft-ui recipe `searchMessage` (`src/components/search/search-message.recipe.ts`, index.mjs:16577).
///
/// Used by: SearchMessageResult, SearchMessageResultBody, SearchMessageResultHeader, SearchMessageResultMatch, SearchMessageResultMeta, SearchMessageResultSender, SearchMessageResultThreadMeta, SearchMessageResultTimestamp, SearchThreadMessageResult.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchMessageRecipe {
  static const String recipeName = 'searchMessage';
  static const List<String> slotNames = [
    'message',
    'messageHeader',
    'messageBody',
    'messageMeta',
    'messageThreadMeta',
    'messageSender',
    'messageTimestamp',
    'messageMatch',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSearchMessageRecipeStyle resolve({
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
    return RaftSearchMessageRecipeStyle(
      message: s[0],
      messageHeader: s[1],
      messageBody: s[2],
      messageMeta: s[3],
      messageThreadMeta: s[4],
      messageSender: s[5],
      messageTimestamp: s[6],
      messageMatch: s[7],
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
      1929,
      1836,
      1893,
      1682,
      618,
      1714,
      621,
      615,
      1662,
      1673,
      1822,
      1738,
      1543,
      1550,
      1549,
      1547,
      1546,
      1545,
      1272,
      427,
      927,
      929,
      921,
      738,
      743,
      1577,
      979,
      980,
    ],
    [965, 1319, 1484, 969, 1022, 1014, 1839, 1824],
    [1484, 1353, 1510, 1016, 1813, 1827],
    [1484, 1897],
    [1305, 1319, 1021, 1740, 278],
    [1305, 1319, 1566, 1740, 1022, 1933, 1016, 1813, 1008, 1822],
    [1499, 1740, 1933],
    [418, 1009, 1716, 575, 1665, 650, 1844, 1310, 1313, 1695, 1699],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
