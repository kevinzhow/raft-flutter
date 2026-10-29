// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageReaction`.
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

/// raft-ui recipe `messageReaction` (`src/components/message-item/message-reaction.recipe.ts`, index.mjs:7466).
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
      1305,
      1484,
      1424,
      1319,
      1583,
      1933,
      1893,
      1185,
      1021,
      1708,
      1636,
      1617,
      1813,
      1822,
      581,
      1283,
      429,
      889,
      1256,
      1577,
      996,
      229,
    ],
    [1781],
    [1305, 1319, 1324, 1346, 184, 177],
    [1304, 1571, 1014, 1783, 1839, 1008],
    [
      1305,
      1484,
      1319,
      1324,
      1893,
      277,
      1185,
      1708,
      1657,
      280,
      581,
      1827,
      1283,
      429,
      1577,
      996,
    ],
    [965, 1740, 1319, 1323, 1020, 602, 1655, 1667, 145, 144, 64],
    [
      965,
      1319,
      1324,
      615,
      1893,
      1758,
      1710,
      1592,
      1859,
      1346,
      1827,
      1270,
      862,
      425,
      1577,
      996,
    ],
    [1305, 1319, 1484, 970, 1020, 1593, 145, 144],
    [1305, 1319, 1484, 970, 1020, 1709, 1593, 602, 1694, 1698, 1737, 1577],
    [1304, 1409, 1659, 1668, 1821, 1013],
    [965, 1406, 971, 1319, 1037],
    [1305, 1484, 1318, 1338],
    [1402, 1897],
    [1740, 1830],
    [1338, 1830],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
  ];
}
