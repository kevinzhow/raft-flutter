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
      1304,
      1481,
      1422,
      1318,
      1579,
      1928,
      1889,
      1184,
      1020,
      1704,
      1632,
      1613,
      1809,
      1818,
      581,
      1282,
      429,
      889,
      1255,
      1573,
      995,
      229,
    ],
    [1777],
    [1304, 1318, 1323, 1345, 184, 177],
    [1303, 1567, 1013, 1779, 1835, 1007],
    [
      1304,
      1481,
      1318,
      1323,
      1889,
      277,
      1184,
      1704,
      1653,
      280,
      581,
      1823,
      1282,
      429,
      1573,
      995,
    ],
    [965, 1736, 1318, 1322, 1019, 602, 1651, 1663, 145, 144, 64],
    [
      965,
      1318,
      1323,
      615,
      1889,
      1754,
      1706,
      1588,
      1855,
      1345,
      1823,
      1269,
      862,
      425,
      1573,
      995,
    ],
    [1304, 1318, 1481, 970, 1019, 1589, 145, 144],
    [1304, 1318, 1481, 970, 1019, 1705, 1589, 602, 1690, 1694, 1733, 1573],
    [1303, 1407, 1655, 1664, 1817, 1012],
    [965, 1404, 971, 1318, 1036],
    [1304, 1481, 1317, 1337],
    [1400, 1893],
    [1736, 1826],
    [1337, 1826],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
  ];
}
