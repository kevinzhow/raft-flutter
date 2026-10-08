// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `tooltip`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTooltipRecipe].
class RaftTooltipRecipeStyle {
  const RaftTooltipRecipeStyle({required this.trigger, required this.positioner, required this.content, required this.body, required this.bodyIcon, required this.bodyText, required this.arrow});

  /// Slot `trigger`.
  final RaftSlotStyle trigger;
  /// Slot `positioner`.
  final RaftSlotStyle positioner;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `body`.
  final RaftSlotStyle body;
  /// Slot `bodyIcon`.
  final RaftSlotStyle bodyIcon;
  /// Slot `bodyText`.
  final RaftSlotStyle bodyText;
  /// Slot `arrow`.
  final RaftSlotStyle arrow;

  Map<String, RaftSlotStyle> get slots => {'trigger': trigger, 'positioner': positioner, 'content': content, 'body': body, 'bodyIcon': bodyIcon, 'bodyText': bodyText, 'arrow': arrow};
}

/// raft-ui recipe `tooltip` (`src/components/tooltip/tooltip.tsx`, index.mjs:1392).
///
/// Used by: FloatButton, MessageReactionTooltipContent, TooltipContent, TooltipTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTooltipRecipe {
  static const String recipeName = 'tooltip';
  static const List<String> slotNames = ['trigger', 'positioner', 'content', 'body', 'bodyIcon', 'bodyText', 'arrow'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('hasLeadingIcon', ['true', 'false'], null, true),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTooltipRecipeStyle resolve({bool? hasLeadingIcon, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [hasLeadingIcon?.toString(), theme.name], states, tokens);
    return RaftTooltipRecipeStyle(trigger: s[0], positioner: s[1], content: s[2], body: s[3], bodyIcon: s[4], bodyText: s[5], arrow: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2834],
    [2309, 3142, 2716, 2649],
    [2716, 2775, 2300, 2479, 2574, 2752, 2762, 2639, 2649, 3078, 1602, 1611, 1568, 1566, 1466, 1464, 1497, 2593, 2102, 2101, 866, 900, 831, 1691, 1684, 2987, 2863, 40, 38, 45, 43],
    [862, 2574, 2924, 2334, 3130, 3136, 42, 47, 383, 381, 382, 384, 385, 44, 380, 41],
    [2867, 293, 304, 302],
    [2574, 1621],
    [2716, 2657, 1347, 1334, 1333, 1343, 1341, 1345, 1346, 1340, 1338, 1336, 1337, 2174],
    [2716, 2775, 2300, 2479, 2574, 2752, 2762, 2639, 2649, 3078, 1602, 1611, 1568, 1566, 1466, 1464, 1497, 2593, 2102, 2101, 2818, 822, 3002, 997, 1163, 1691, 2924, 1688, 3046, 2861, 39, 46, 43, 946, 947],
    [2716, 1620, 2657, 1347, 1334, 1333, 1343, 1341, 1345, 1346, 1340, 1338, 1336, 1337, 1061],
    [2574, 2924, 2334, 3130, 3136, 42, 47, 383, 381, 382, 384, 385, 44, 380, 41, 1620, 2312, 1706],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [0, 1, 7, 3, 4, 5, 8], [0, 1, 2, 9, 4, 5, 6], [0, 1, 7, 9, 4, 5, 8], [0, 1, 2, 3, 4, 5, 6], [0, 1, 7, 3, 4, 5, 8],
  ];
}
