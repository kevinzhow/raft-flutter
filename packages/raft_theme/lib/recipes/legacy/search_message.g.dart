// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `searchMessage`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `searchMessage` (`src/components/search/search-message.recipe.ts`, index.mjs:20620).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('nested', ['false', 'true'], 'false', false),
    RaftRecipeAxis('selected', ['false', 'true'], 'false', false),
  ];

  static RaftSearchMessageRecipeStyle resolve({
    required RaftRecipeTheme theme,
    bool? nested,
    bool? selected,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, nested?.toString(), selected?.toString()],
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
      3168,
      3040,
      3125,
      878,
      896,
      868,
      2695,
      2260,
      2288,
      598,
      610,
      1338,
      1346,
      1278,
      1273,
      1276,
      1284,
      1285,
      1274,
      1281,
      1279,
      1282,
      1290,
      1288,
      1293,
      1292,
      1663,
      1672,
      1671,
      1666,
    ],
    [1644, 1650, 2331, 1723, 3073, 2512],
    [2597, 2374, 3053, 2364, 3001],
    [1709, 2998],
    [2320, 2331, 1721, 1709, 2996],
    [2320, 2331, 1721, 1709, 2994],
    [1714, 2996],
    [2776, 838, 1709, 2994],
    [
      3168,
      3040,
      1932,
      2847,
      879,
      912,
      830,
      2690,
      2899,
      3103,
      1626,
      2204,
      1339,
      1286,
      1272,
      1277,
      1275,
      1271,
      1283,
      1287,
      1280,
      1282,
      1291,
      1289,
      2672,
      1029,
      1036,
      1035,
      1037,
      1038,
      1040,
      1039,
      1041,
      1676,
      1689,
      1083,
      1086,
      1084,
    ],
    [1644, 1650, 2331, 1723, 3073, 2781, 2761, 2704, 1774, 1775],
    [
      2597,
      2374,
      3053,
      877,
      863,
      2781,
      2756,
      2707,
      3125,
      1626,
      1776,
      1772,
      1771,
      1775,
      1773,
      2355,
      3088,
      3018,
    ],
    [1713, 3019],
    [2320, 2331, 1721, 1713, 3019],
    [2320, 2331, 1721, 1713, 3018],
    [1716, 2946, 3019],
    [2776, 841, 3046, 582, 1018],
    [
      3168,
      3040,
      1932,
      2847,
      879,
      912,
      830,
      2690,
      2899,
      3103,
      1626,
      2204,
      1339,
      1286,
      1272,
      1277,
      1275,
      1271,
      1283,
      1287,
      1280,
      1282,
      1291,
      1289,
      2672,
      1029,
      1036,
      1035,
      1037,
      1038,
      1040,
      1039,
      1041,
      1676,
      1689,
      1083,
      1086,
      1084,
      2821,
      2834,
      2832,
      2833,
      1150,
    ],
    [
      3168,
      3040,
      1932,
      2847,
      879,
      912,
      830,
      2690,
      2899,
      3103,
      1626,
      2204,
      1339,
      1286,
      1272,
      1277,
      1275,
      1271,
      1283,
      1287,
      1280,
      1282,
      1291,
      1289,
      2672,
      1029,
      1036,
      1035,
      1037,
      1038,
      1040,
      1039,
      1041,
      1676,
      1682,
      1689,
      1083,
      1086,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 9, 10, 11, 12, 13, 14, 15],
    [16, 9, 10, 11, 12, 13, 14, 15],
    [17, 9, 10, 11, 12, 13, 14, 15],
    [17, 9, 10, 11, 12, 13, 14, 15],
  ];
}
