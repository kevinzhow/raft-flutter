// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageReaction`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `messageReaction` (`src/components/message-item/message-reaction.recipe.ts`, index.mjs:9540).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageReactionRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
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
      2320,
      2597,
      2505,
      2331,
      2679,
      3172,
      3125,
      1963,
      1721,
      2852,
      2778,
      3073,
      1709,
      2363,
      772,
      2994,
      2214,
      1568,
      1573,
      2167,
      2169,
    ],
    [2942],
    [2320, 2331, 2336, 2363, 304, 298],
    [2319, 2664, 1714, 2946],
    [
      2320,
      2597,
      2331,
      2336,
      3125,
      425,
      1963,
      2852,
      2778,
      437,
      772,
      2994,
      2214,
      589,
    ],
    [1644, 2902, 2331, 1969, 1721, 868, 2779, 253, 252],
    [1644, 2331, 2336, 863, 3125, 2919, 2852, 2690, 2221, 590],
    [2320, 2331, 1720, 2778, 2791, 253, 252, 2849, 878, 892, 868, 2878],
    [2320, 2331, 1720, 2778, 2791, 2849, 878, 892, 868, 2878],
    [2319, 2492, 878, 916, 868, 2779, 2792, 3073, 1709, 2994],
    [1644, 2489, 1650, 2331, 1738],
    [2320, 2597, 2330, 2354],
    [2486, 3133],
    [2902, 3028],
    [2354, 3029],
    [
      2320,
      2597,
      2505,
      2331,
      2679,
      3172,
      3125,
      1963,
      2845,
      1722,
      2779,
      2958,
      1713,
      2350,
      3091,
      806,
      3018,
      2239,
      1003,
      1120,
      1566,
      1578,
      1571,
      1073,
      1077,
      1074,
      2168,
      2170,
    ],
    [
      2320,
      2597,
      2331,
      2336,
      3125,
      425,
      1963,
      2845,
      2778,
      801,
      3015,
      437,
      2232,
      592,
    ],
    [1644, 2902, 2331, 1969, 1721, 833, 2779, 253, 252],
    [1644, 2331, 2336, 863, 3125, 2919, 2852, 2690, 2239, 1505, 594],
    [2320, 2331, 2597, 1649, 1720, 2778, 2791, 253, 252],
    [2320, 2331, 2597, 1649, 2848, 833, 2692, 2895, 2672],
    [2319, 2492, 2779, 2792, 3073],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [15, 1, 2, 3, 16, 17, 18, 19, 20, 21, 10, 11, 12, 13, 14],
  ];
}
