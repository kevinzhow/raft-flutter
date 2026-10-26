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
      1924,
      1832,
      1889,
      1678,
      618,
      1710,
      621,
      615,
      1658,
      1669,
      1818,
      1734,
      1539,
      1546,
      1545,
      1543,
      1542,
      1541,
      1271,
      427,
      927,
      929,
      921,
      738,
      743,
      1573,
      979,
      980,
    ],
    [965, 1318, 1481, 969, 1021, 1013, 1835, 1820],
    [1481, 1352, 1506, 1015, 1809, 1823],
    [1481, 1893],
    [1304, 1318, 1020, 1736, 278],
    [1304, 1318, 1562, 1736, 1021, 1928, 1015, 1809, 1007, 1818],
    [1495, 1736, 1928],
    [418, 1008, 1712, 575, 1661, 650, 1840, 1309, 1312, 1691, 1695],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
