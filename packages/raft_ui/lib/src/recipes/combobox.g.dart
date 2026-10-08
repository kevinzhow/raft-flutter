// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `combobox`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `inputOwner` axis of `combobox`.
enum RaftComboboxRecipeInputOwner {
  group('group'),
  control('control');

  const RaftComboboxRecipeInputOwner(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftComboboxRecipe].
class RaftComboboxRecipeStyle {
  const RaftComboboxRecipeStyle({required this.trigger, required this.triggerCount, required this.triggerIndicator, required this.control, required this.inputGroup, required this.input, required this.positioner, required this.content, required this.header, required this.separator, required this.list, required this.item, required this.itemIndicator, required this.label, required this.clear, required this.empty, required this.groupLabel, required this.chips, required this.chip, required this.chipRemove});

  /// Slot `trigger`.
  final RaftSlotStyle trigger;
  /// Slot `triggerCount`.
  final RaftSlotStyle triggerCount;
  /// Slot `triggerIndicator`.
  final RaftSlotStyle triggerIndicator;
  /// Slot `control`.
  final RaftSlotStyle control;
  /// Slot `inputGroup`.
  final RaftSlotStyle inputGroup;
  /// Slot `input`.
  final RaftSlotStyle input;
  /// Slot `positioner`.
  final RaftSlotStyle positioner;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `separator`.
  final RaftSlotStyle separator;
  /// Slot `list`.
  final RaftSlotStyle list;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `itemIndicator`.
  final RaftSlotStyle itemIndicator;
  /// Slot `label`.
  final RaftSlotStyle label;
  /// Slot `clear`.
  final RaftSlotStyle clear;
  /// Slot `empty`.
  final RaftSlotStyle empty;
  /// Slot `groupLabel`.
  final RaftSlotStyle groupLabel;
  /// Slot `chips`.
  final RaftSlotStyle chips;
  /// Slot `chip`.
  final RaftSlotStyle chip;
  /// Slot `chipRemove`.
  final RaftSlotStyle chipRemove;

  Map<String, RaftSlotStyle> get slots => {'trigger': trigger, 'triggerCount': triggerCount, 'triggerIndicator': triggerIndicator, 'control': control, 'inputGroup': inputGroup, 'input': input, 'positioner': positioner, 'content': content, 'header': header, 'separator': separator, 'list': list, 'item': item, 'itemIndicator': itemIndicator, 'label': label, 'clear': clear, 'empty': empty, 'groupLabel': groupLabel, 'chips': chips, 'chip': chip, 'chipRemove': chipRemove};
}

/// raft-ui recipe `combobox` (`src/components/combobox/combobox.tsx`, index.mjs:6627).
///
/// Used by: ComboboxChip, ComboboxChipRemove, ComboboxChips, ComboboxClear, ComboboxContent, ComboboxControl, ComboboxEmpty, ComboboxGroupLabel, ComboboxHeader, ComboboxInput, ComboboxInputGroup, ComboboxItem, ComboboxItemIndicator, ComboboxLabel, ComboboxList, ComboboxPopup, ComboboxSeparator, ComboboxTrigger, ComboboxTriggerCount, ComboboxTriggerIndicator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComboboxRecipe {
  static const String recipeName = 'combobox';
  static const List<String> slotNames = ['trigger', 'triggerCount', 'triggerIndicator', 'control', 'inputGroup', 'input', 'positioner', 'content', 'header', 'separator', 'list', 'item', 'itemIndicator', 'label', 'clear', 'empty', 'groupLabel', 'chips', 'chip', 'chipRemove'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('inputOwner', ['group', 'control'], null, true),
  ];

  static RaftComboboxRecipeStyle resolve({required RaftRecipeTheme theme, RaftComboboxRecipeInputOwner? inputOwner, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, inputOwner?.css], states, tokens);
    return RaftComboboxRecipeStyle(trigger: s[0], triggerCount: s[1], triggerIndicator: s[2], control: s[3], inputGroup: s[4], input: s[5], positioner: s[6], content: s[7], header: s[8], separator: s[9], list: s[10], item: s[11], itemIndicator: s[12], label: s[13], clear: s[14], empty: s[15], groupLabel: s[16], chips: s[17], chip: s[18], chipRemove: s[19]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2301, 2834, 2312, 2316, 1698, 2649, 3084, 7, 6, 283, 282, 281, 1519, 1534, 609, 581, 603, 1474, 1478, 1477, 1475, 1476, 1473, 278, 279],
    [2301, 1960, 2576, 2867, 2312, 2317, 2749, 1689, 2918, 2344, 864, 900],
    [2585, 1620, 2867, 2312, 2317, 3069, 1601, 303, 302, 2987, 2627, 2208, 2280, 585, 309, 323],
    [1620, 2574, 2312, 1698, 2649, 3084, 298, 302, 288, 360, 359, 8, 366, 362, 361, 866, 900, 825, 2751, 2763, 1691, 3017, 1692, 2987, 2863, 1673, 1540, 1541, 1533, 1670, 290, 363, 365, 364],
    [1620, 2312, 1698, 873, 2751, 2765, 900, 825],
    [3127, 2649],
    [2309, 3142, 2649],
    [1976, 2361, 2583, 2656, 2649, 866, 900, 828, 2861],
    [1620, 2312, 2316, 2753, 2765],
    [1979, 2867, 865, 830],
    [2365, 2661, 2664, 2831],
    [1620, 3127, 2867, 939, 2834, 2312, 2316, 1698, 2656, 2753, 2763, 3003, 2649, 3084, 873, 889, 828, 1691, 3017, 1692, 2337, 2987, 2324, 2208, 1480, 1447, 1453, 425, 427, 415, 419],
    [2716, 2585, 1620, 2867, 2312, 2317, 2987, 304, 302, 309, 323],
    [2359, 1691, 2918, 1684, 3096, 2344, 3055, 2993],
    [2301, 1961, 2581, 2312, 2317, 2716, 2626, 2649, 3069, 1601, 1575, 1574, 1691, 2918, 1684, 3096, 3055, 2987, 2208, 2280, 585, 309, 323],
    [2753, 2769, 2970, 1691, 3017, 1692, 2992],
    [2753, 2765, 1691, 2918, 1684, 3096, 2344, 3055, 2993],
    [1620, 2568, 1626, 2312, 1696, 866, 900, 825, 2751, 2762],
    [2301, 2312, 1696, 864, 900, 786, 2750, 2761, 1691, 3032, 1684],
    [2301, 2312, 2317, 2649, 3084, 2992, 2280],
    [3127, 2649, 866, 900, 825, 2751, 2762, 1689, 3032, 2863, 1679],
    [3127, 2574, 1621, 2819, 865, 850, 2667, 2860, 2649, 2790, 1675, 1678, 1651, 1660, 1691, 3017, 1692, 2987, 2713],
    [2301, 2834, 2312, 2316, 1698, 2649, 3084, 7, 6, 283, 282, 281, 3017, 1688, 3046, 2981, 2221, 598, 1652, 1665, 277, 280],
    [2301, 1960, 2576, 2867, 2312, 2317, 2749, 2918, 2344, 2822, 833, 1691, 1688, 3050, 3010],
    [2585, 1620, 2867, 2312, 2317, 3069, 1601, 303, 302, 2822, 2981, 2627, 2222, 2276, 444, 459],
    [1620, 2574, 2312, 1698, 2649, 3084, 298, 302, 288, 360, 359, 8, 366, 362, 361, 2818, 864, 896, 825, 2752, 2763, 1009, 993, 3017, 1690, 2987, 2842, 1142, 1106, 1671, 1672, 1067, 1070, 290],
    [1620, 2312, 1698, 873, 2765, 895, 828, 2750, 2733, 2683],
    [1976, 2361, 2583, 2656, 2649, 2818, 828, 2861],
    [1620, 2312, 2316, 2753, 2765, 2699, 2720, 2736, 2680],
    [1979, 2867, 865, 2174, 829],
    [2365, 2661, 2664, 2831, 1620, 1622, 1695, 2750, 2762],
    [1620, 3127, 2867, 939, 2834, 2312, 2316, 1698, 2656, 2763, 3003, 2649, 2822, 850, 2751, 3017, 1690, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1447, 1452, 425, 427, 416, 420],
    [2716, 2585, 1620, 2867, 2312, 2317, 2976, 304, 302, 310, 324],
    [2359, 1688, 2920, 2344, 3046, 2991],
    [2301, 1961, 2581, 2312, 2317, 2716, 2626, 2649, 3069, 1601, 1575, 1574, 2822, 2920, 1688, 3046, 2981, 2222, 2276, 310, 324],
    [2753, 2769, 2970, 3017, 2981],
    [2753, 2765, 2920, 1688, 2344, 3046, 2991],
    [1620, 2568, 1626, 2312, 1696, 2818, 864, 896, 825, 2751, 2762, 1009, 993, 1142, 1106, 1671, 1672, 1067, 1070],
    [2301, 2312, 1696, 2822, 795, 2750, 2761, 3032, 1688, 2987],
    [2301, 2312, 2317, 2649, 3084, 2981, 2276],
    [3127, 2822, 864, 896, 825, 2751, 2762, 3017, 2987, 2649, 3061, 1602, 2712, 1652, 1665],
    [3127, 2574, 1621, 2819, 865, 850, 2667, 2860, 2649, 2790, 1675, 1678, 1651, 1660, 3017, 1690, 2987, 2712],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19], [0, 1, 2, 3, 4, 20, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19], [0, 1, 2, 3, 4, 21, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19], [22, 23, 24, 25, 26, 5, 6, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39], [22, 23, 24, 25, 26, 40, 6, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39], [22, 23, 24, 25, 26, 41, 6, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39],
  ];
}
