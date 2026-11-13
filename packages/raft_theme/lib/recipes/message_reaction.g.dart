// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageReaction`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageReactionRecipe].
class RaftMessageReactionRecipeStyle {
  const RaftMessageReactionRecipeStyle({
    required this.chip,
    required this.errorIndicator,
    required this.glyph,
    required this.count,
    required this.addButton,
    required this.quickRow,
    required this.quickButton,
    required this.pickerContent,
    required this.pickerStatic,
    required this.tooltip,
    required this.tooltipNames,
    required this.tooltipName,
    required this.tooltipNameText,
    required this.tooltipSeparator,
    required this.tooltipMeta,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'chip': chip,
    'errorIndicator': errorIndicator,
    'glyph': glyph,
    'count': count,
    'addButton': addButton,
    'quickRow': quickRow,
    'quickButton': quickButton,
    'pickerContent': pickerContent,
    'pickerStatic': pickerStatic,
    'tooltip': tooltip,
    'tooltipNames': tooltipNames,
    'tooltipName': tooltipName,
    'tooltipNameText': tooltipNameText,
    'tooltipSeparator': tooltipSeparator,
    'tooltipMeta': tooltipMeta,
  };
}

/// raft-ui recipe `messageReaction` (`dist/components/message-item/message-reaction.recipe.mjs`, index.mjs:12760).
///
/// Used by: MessageReactionAddButton, MessageReactionChip, MessageReactionCount, MessageReactionErrorIndicator, MessageReactionGlyph, MessageReactionPickerContent, MessageReactionPickerStatic, MessageReactionQuickButton, MessageReactionQuickRow, MessageReactionTooltipContent, MessageReactionTooltipMeta, MessageReactionTooltipName, MessageReactionTooltipNameText, MessageReactionTooltipNames, MessageReactionTooltipSeparator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageReactionRecipe {
  static const String recipeName = 'messageReaction';
  static const List<String> slotNames = [
    'chip',
    'errorIndicator',
    'glyph',
    'count',
    'addButton',
    'quickRow',
    'quickButton',
    'pickerContent',
    'pickerStatic',
    'tooltip',
    'tooltipNames',
    'tooltipName',
    'tooltipNameText',
    'tooltipSeparator',
    'tooltipMeta',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageReactionRecipeStyle resolve({
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
    return RaftMessageReactionRecipeStyle(
      chip: s[0],
      errorIndicator: s[1],
      glyph: s[2],
      count: s[3],
      addButton: s[4],
      quickRow: s[5],
      quickButton: s[6],
      pickerContent: s[7],
      pickerStatic: s[8],
      tooltip: s[9],
      tooltipNames: s[10],
      tooltipName: s[11],
      tooltipNameText: s[12],
      tooltipSeparator: s[13],
      tooltipMeta: s[14],
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
      1847,
      2116,
      1980,
      1864,
      2252,
      2729,
      2675,
      1658,
      1464,
      2461,
      2410,
      2587,
      2598,
      895,
      1794,
      699,
      1287,
      1760,
      2247,
      1439,
      404,
    ],
    [2539],
    [1847, 1864, 1869, 1892, 355, 348],
    [1846, 2241, 1454, 2556, 2616, 1449],
    [
      1847,
      2116,
      1864,
      1869,
      2675,
      474,
      1658,
      2461,
      2400,
      478,
      895,
      2603,
      1794,
      699,
      2247,
      1439,
    ],
    [1400, 2499, 1864, 1873, 1463, 915, 2260, 305, 2014, 304, 84],
    [
      1400,
      1864,
      1869,
      933,
      2675,
      2523,
      2461,
      2260,
      2636,
      1892,
      2603,
      2082,
      2077,
      1783,
      1237,
      695,
      2247,
      1439,
    ],
    [1847, 1864, 2116, 1407, 1463, 2261, 305, 2014, 304],
    [1847, 1864, 2116, 1407, 1463, 2462, 2261, 915, 2445, 2449, 2496, 2247],
    [1846, 1964, 2402, 2414, 2597, 1453],
    [1400, 1960, 1408, 1864, 1485],
    [1847, 2116, 1863, 1883],
    [1956, 2681],
    [2499, 2606],
    [1883, 2606],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
  ];
}
