// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageReaction`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageReactionRecipe].
class RaftMessageReactionRecipeStyle {
  const RaftMessageReactionRecipeStyle({required this.chip, required this.errorIndicator, required this.glyph, required this.count, required this.addButton, required this.quickRow, required this.quickButton, required this.pickerContent, required this.pickerStatic, required this.tooltip, required this.tooltipNames, required this.tooltipName, required this.tooltipNameText, required this.tooltipSeparator, required this.tooltipMeta});

  /// Slot `chip`.
  final RaftSlotStyle chip;
  /// Slot `errorIndicator`.
  final RaftSlotStyle errorIndicator;
  /// Slot `glyph`.
  final RaftSlotStyle glyph;
  /// Slot `count`.
  final RaftSlotStyle count;
  /// Slot `addButton`.
  final RaftSlotStyle addButton;
  /// Slot `quickRow`.
  final RaftSlotStyle quickRow;
  /// Slot `quickButton`.
  final RaftSlotStyle quickButton;
  /// Slot `pickerContent`.
  final RaftSlotStyle pickerContent;
  /// Slot `pickerStatic`.
  final RaftSlotStyle pickerStatic;
  /// Slot `tooltip`.
  final RaftSlotStyle tooltip;
  /// Slot `tooltipNames`.
  final RaftSlotStyle tooltipNames;
  /// Slot `tooltipName`.
  final RaftSlotStyle tooltipName;
  /// Slot `tooltipNameText`.
  final RaftSlotStyle tooltipNameText;
  /// Slot `tooltipSeparator`.
  final RaftSlotStyle tooltipSeparator;
  /// Slot `tooltipMeta`.
  final RaftSlotStyle tooltipMeta;

  Map<String, RaftSlotStyle> get slots => {'chip': chip, 'errorIndicator': errorIndicator, 'glyph': glyph, 'count': count, 'addButton': addButton, 'quickRow': quickRow, 'quickButton': quickButton, 'pickerContent': pickerContent, 'pickerStatic': pickerStatic, 'tooltip': tooltip, 'tooltipNames': tooltipNames, 'tooltipName': tooltipName, 'tooltipNameText': tooltipNameText, 'tooltipSeparator': tooltipSeparator, 'tooltipMeta': tooltipMeta};
}

/// raft-ui recipe `messageReaction` (`src/components/message-item/message-reaction.recipe.ts`, index.mjs:9502).
///
/// Used by: MessageReactionAddButton, MessageReactionChip, MessageReactionCount, MessageReactionErrorIndicator, MessageReactionGlyph, MessageReactionPickerContent, MessageReactionPickerStatic, MessageReactionQuickButton, MessageReactionQuickRow, MessageReactionTooltipContent, MessageReactionTooltipMeta, MessageReactionTooltipName, MessageReactionTooltipNameText, MessageReactionTooltipNames, MessageReactionTooltipSeparator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageReactionRecipe {
  static const String recipeName = 'messageReaction';
  static const List<String> slotNames = ['chip', 'errorIndicator', 'glyph', 'count', 'addButton', 'quickRow', 'quickButton', 'pickerContent', 'pickerStatic', 'tooltip', 'tooltipNames', 'tooltipName', 'tooltipNameText', 'tooltipSeparator', 'tooltipMeta'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageReactionRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageReactionRecipeStyle(chip: s[0], errorIndicator: s[1], glyph: s[2], count: s[3], addButton: s[4], quickRow: s[5], quickButton: s[6], pickerContent: s[7], pickerStatic: s[8], tooltip: s[9], tooltipNames: s[10], tooltipName: s[11], tooltipNameText: s[12], tooltipSeparator: s[13], tooltipMeta: s[14]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2301, 2574, 2484, 2312, 2656, 3131, 3084, 1961, 1696, 2822, 2750, 3032, 1684, 2344, 766, 2956, 2195, 1544, 1549, 2156, 2158],
    [2907],
    [2301, 2312, 2317, 2344, 308, 302],
    [2300, 2641, 1689, 2911],
    [2301, 2574, 2312, 2317, 3084, 427, 1961, 2822, 2750, 439, 766, 2956, 2195, 583],
    [1620, 2867, 2312, 1967, 1696, 856, 2751, 257, 256],
    [1620, 2312, 2317, 850, 3084, 2884, 2822, 2667, 2202, 584],
    [2301, 2312, 1695, 2750, 2762, 257, 256, 2819, 866, 876, 856, 2844],
    [2301, 2312, 1695, 2750, 2762, 2819, 866, 876, 856, 2844],
    [2300, 2471, 866, 900, 856, 2751, 2763, 3032, 1684, 2956],
    [1620, 2468, 1626, 2312, 1713],
    [2301, 2574, 2311, 2335],
    [2465, 3092],
    [2867, 2991],
    [2335, 2992],
    [2301, 2574, 2484, 2312, 2656, 3131, 3084, 1961, 2815, 1697, 2751, 2920, 1688, 2331, 3050, 800, 2981, 2220, 983, 1100, 1542, 1554, 1547, 1053, 1057, 1054, 2157, 2159],
    [2301, 2574, 2312, 2317, 3084, 427, 1961, 2815, 2750, 795, 2978, 439, 2213, 586],
    [1620, 2867, 2312, 1967, 1696, 828, 2751, 257, 256],
    [1620, 2312, 2317, 850, 3084, 2884, 2822, 2667, 2220, 1481, 588],
    [2301, 2312, 2574, 1625, 1695, 2750, 2762, 257, 256],
    [2301, 2312, 2574, 1625, 2818, 828, 2669, 2861, 2649],
    [2300, 2471, 2751, 2763, 3032],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], [15, 1, 2, 3, 16, 17, 18, 19, 20, 21, 10, 11, 12, 13, 14],
  ];
}
