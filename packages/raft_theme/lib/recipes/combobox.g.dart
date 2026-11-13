// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `combobox`.
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
  const RaftComboboxRecipeStyle({
    required this.trigger,
    required this.triggerCount,
    required this.triggerIndicator,
    required this.control,
    required this.inputGroup,
    required this.input,
    required this.positioner,
    required this.content,
    required this.header,
    required this.separator,
    required this.listFrame,
    required this.list,
    required this.item,
    required this.itemIndicator,
    required this.label,
    required this.clear,
    required this.empty,
    required this.groupLabel,
    required this.chips,
    required this.chip,
    required this.chipRemove,
  });

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

  /// Slot `listFrame`.
  final RaftSlotStyle listFrame;

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

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'triggerCount': triggerCount,
    'triggerIndicator': triggerIndicator,
    'control': control,
    'inputGroup': inputGroup,
    'input': input,
    'positioner': positioner,
    'content': content,
    'header': header,
    'separator': separator,
    'listFrame': listFrame,
    'list': list,
    'item': item,
    'itemIndicator': itemIndicator,
    'label': label,
    'clear': clear,
    'empty': empty,
    'groupLabel': groupLabel,
    'chips': chips,
    'chip': chip,
    'chipRemove': chipRemove,
  };
}

/// raft-ui recipe `combobox` (`dist/components/combobox/combobox.mjs`, index.mjs:8006).
///
/// Used by: ComboboxChip, ComboboxChipRemove, ComboboxChips, ComboboxClear, ComboboxContent, ComboboxControl, ComboboxEmpty, ComboboxGroupLabel, ComboboxHeader, ComboboxInput, ComboboxInputGroup, ComboboxItem, ComboboxItemIndicator, ComboboxLabel, ComboboxList, ComboboxPopup, ComboboxSeparator, ComboboxTrigger, ComboboxTriggerCount, ComboboxTriggerIndicator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComboboxRecipe {
  static const String recipeName = 'combobox';
  static const List<String> slotNames = [
    'trigger',
    'triggerCount',
    'triggerIndicator',
    'control',
    'inputGroup',
    'input',
    'positioner',
    'content',
    'header',
    'separator',
    'listFrame',
    'list',
    'item',
    'itemIndicator',
    'label',
    'clear',
    'empty',
    'groupLabel',
    'chips',
    'chip',
    'chipRemove',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('inputOwner', ['group', 'control'], null, true),
  ];

  static RaftComboboxRecipeStyle resolve({
    RaftComboboxRecipeInputOwner? inputOwner,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [inputOwner?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftComboboxRecipeStyle(
      trigger: s[0],
      triggerCount: s[1],
      triggerIndicator: s[2],
      control: s[3],
      inputGroup: s[4],
      input: s[5],
      positioner: s[6],
      content: s[7],
      header: s[8],
      separator: s[9],
      listFrame: s[10],
      list: s[11],
      item: s[12],
      itemIndicator: s[13],
      label: s[14],
      clear: s[15],
      empty: s[16],
      groupLabel: s[17],
      chips: s[18],
      chip: s[19],
      chipRemove: s[20],
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
      2483,
      1864,
      1868,
      2247,
      2675,
      4,
      3,
      318,
      317,
      316,
      1661,
      2042,
      1465,
      2463,
      963,
      933,
      2402,
      2591,
      1457,
      2603,
      1851,
      1855,
      1789,
      1231,
      1235,
      1234,
      1232,
      1439,
      1355,
      779,
      314,
      315,
    ],
    [1847, 2499, 1864, 1869, 1673, 2116, 2397, 1454, 2616, 1449],
    [
      2132,
      1400,
      2499,
      1864,
      1869,
      2664,
      1365,
      348,
      2471,
      2600,
      2229,
      351,
      357,
      366,
    ],
    [
      1400,
      2116,
      1864,
      1466,
      2247,
      344,
      348,
      6,
      385,
      5,
      270,
      388,
      386,
      2110,
      2454,
      941,
      952,
      911,
      2403,
      2412,
      1456,
      2585,
      2598,
      2677,
      1373,
      1376,
      1775,
      359,
      328,
      330,
      387,
    ],
    [
      1400,
      1864,
      942,
      1647,
      2042,
      1466,
      953,
      933,
      2403,
      2412,
      2587,
      2600,
      352,
      348,
      1398,
      1773,
      1774,
    ],
    [2725, 2247],
    [1862, 2746, 2247],
    [1673, 1911, 2128, 2252, 1979, 2247, 2462, 915, 2598, 2496, 2445, 2449],
    [1400, 1864, 1868, 2403, 1466, 2415, 2356, 2302],
    [1680, 2499, 940, 918],
    [2098],
    [1915, 2098, 1400, 1404, 2261, 2480],
    [
      1400,
      2725,
      2499,
      993,
      2483,
      1864,
      1868,
      2252,
      2613,
      2247,
      2675,
      2113,
      1467,
      2461,
      2402,
      2430,
      1456,
      2587,
      1453,
      2598,
      2733,
      933,
      1783,
      1237,
      1309,
      1185,
      1187,
      472,
      474,
      460,
      467,
    ],
    [2346, 2132, 1400, 2499, 1864, 1869, 2598, 352, 348, 357, 366],
    [1907, 1456, 2588, 1449, 2600],
    [
      1847,
      1864,
      1869,
      2346,
      2228,
      2247,
      2664,
      1365,
      1335,
      1334,
      1659,
      2116,
      2461,
      2401,
      1456,
      2591,
      1457,
      2603,
      1785,
      1798,
      697,
      1439,
      352,
      357,
      366,
    ],
    [2405, 2420, 2613, 2587, 2600],
    [2417, 2402, 2381, 2274, 2588, 1449, 2600],
    [
      1400,
      1408,
      1864,
      2110,
      1465,
      2454,
      941,
      952,
      911,
      2428,
      2360,
      2309,
      103,
      2677,
      1373,
      1376,
      1775,
    ],
    [
      1847,
      2116,
      1980,
      1864,
      2252,
      262,
      263,
      1676,
      1465,
      2461,
      895,
      2354,
      2298,
      2597,
      1457,
      2598,
    ],
    [
      1847,
      2499,
      1864,
      1869,
      2247,
      2675,
      2471,
      2600,
      1785,
      697,
      1421,
      1422,
      351,
      2533,
    ],
    [2725, 2247, 2116, 1401, 940, 933, 2260, 1456, 2587, 2598, 2311],
    [
      2725,
      2116,
      1401,
      2468,
      940,
      933,
      2260,
      2497,
      2247,
      2444,
      1446,
      1448,
      1435,
      1437,
      1456,
      2585,
      1455,
      2598,
      2311,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    [0, 1, 2, 3, 4, 21, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    [0, 1, 2, 3, 4, 22, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
  ];
}
