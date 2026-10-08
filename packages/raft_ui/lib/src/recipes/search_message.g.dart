// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `searchMessage`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchMessageRecipe].
class RaftSearchMessageRecipeStyle {
  const RaftSearchMessageRecipeStyle({required this.message, required this.messageHeader, required this.messageBody, required this.messageMeta, required this.messageThreadMeta, required this.messageSender, required this.messageTimestamp, required this.messageMatch});

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

  Map<String, RaftSlotStyle> get slots => {'message': message, 'messageHeader': messageHeader, 'messageBody': messageBody, 'messageMeta': messageMeta, 'messageThreadMeta': messageThreadMeta, 'messageSender': messageSender, 'messageTimestamp': messageTimestamp, 'messageMatch': messageMatch};
}

/// raft-ui recipe `searchMessage` (`src/components/search/search-message.recipe.ts`, index.mjs:20471).
///
/// Used by: SearchMessageResult, SearchMessageResultBody, SearchMessageResultHeader, SearchMessageResultMatch, SearchMessageResultMeta, SearchMessageResultSender, SearchMessageResultThreadMeta, SearchMessageResultTimestamp, SearchThreadMessageResult.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchMessageRecipe {
  static const String recipeName = 'searchMessage';
  static const List<String> slotNames = ['message', 'messageHeader', 'messageBody', 'messageMeta', 'messageThreadMeta', 'messageSender', 'messageTimestamp', 'messageMatch'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('nested', ['false', 'true'], 'false', false),
    RaftRecipeAxis('selected', ['false', 'true'], 'false', false),
  ];

  static RaftSearchMessageRecipeStyle resolve({required RaftRecipeTheme theme, bool? nested, bool? selected, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, nested?.toString(), selected?.toString()], states, tokens);
    return RaftSearchMessageRecipeStyle(message: s[0], messageHeader: s[1], messageBody: s[2], messageMeta: s[3], messageThreadMeta: s[4], messageSender: s[5], messageTimestamp: s[6], messageMatch: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [3127, 3003, 3084, 866, 880, 856, 2672, 2241, 2269, 592, 604, 1316, 1324, 1256, 1251, 1254, 1262, 1263, 1252, 1259, 1257, 1260, 1268, 1266, 1271, 1270, 1639, 1648, 1647, 1642],
    [1620, 1626, 2312, 1698, 3032, 2491],
    [2574, 2355, 3017, 2345, 2964],
    [1684, 2961],
    [2301, 2312, 1696, 1684, 2959],
    [2301, 2312, 1696, 1684, 2956],
    [1689, 2959],
    [2748, 833, 1684, 2956],
    [3127, 3003, 1931, 2817, 867, 896, 825, 2667, 2865, 3062, 1602, 2185, 1317, 1264, 1250, 1255, 1253, 1249, 1261, 1265, 1258, 1260, 1269, 1267, 2649, 1009, 1016, 1015, 1017, 1018, 1020, 1019, 1021, 1652, 1665, 1063, 1066, 1064],
    [1620, 1626, 2312, 1698, 3032, 2753, 2736, 2681, 1749, 1750],
    [2574, 2355, 3017, 865, 850, 2753, 2731, 2684, 3084, 1602, 1751, 1747, 1746, 1750, 1748, 2336, 3047, 2981],
    [1688, 2982],
    [2301, 2312, 1696, 1688, 2982],
    [2301, 2312, 1696, 1688, 2981],
    [1691, 2911, 2982],
    [2748, 836, 3010, 577, 998],
    [3127, 3003, 1931, 2817, 867, 896, 825, 2667, 2865, 3062, 1602, 2185, 1317, 1264, 1250, 1255, 1253, 1249, 1261, 1265, 1258, 1260, 1269, 1267, 2649, 1009, 1016, 1015, 1017, 1018, 1020, 1019, 1021, 1652, 1665, 1063, 1066, 1064, 2791, 2804, 2802, 2803, 1131],
    [3127, 3003, 1931, 2817, 867, 896, 825, 2667, 2865, 3062, 1602, 2185, 1317, 1264, 1250, 1255, 1253, 1249, 1261, 1265, 1258, 1260, 1269, 1267, 2649, 1009, 1016, 1015, 1017, 1018, 1020, 1019, 1021, 1652, 1658, 1665, 1063, 1066],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7], [0, 1, 2, 3, 4, 5, 6, 7], [0, 1, 2, 3, 4, 5, 6, 7], [0, 1, 2, 3, 4, 5, 6, 7], [8, 9, 10, 11, 12, 13, 14, 15], [16, 9, 10, 11, 12, 13, 14, 15], [17, 9, 10, 11, 12, 13, 14, 15], [17, 9, 10, 11, 12, 13, 14, 15],
  ];
}
