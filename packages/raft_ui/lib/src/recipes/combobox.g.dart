// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `combobox` (`src/components/combobox/combobox.tsx`, index.mjs:6645).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('inputOwner', ['group', 'control'], null, true),
  ];

  static RaftComboboxRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftComboboxRecipeInputOwner? inputOwner,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, inputOwner?.css],
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
      list: s[10],
      item: s[11],
      itemIndicator: s[12],
      label: s[13],
      clear: s[14],
      empty: s[15],
      groupLabel: s[16],
      chips: s[17],
      chip: s[18],
      chipRemove: s[19],
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
      2868,
      2331,
      2335,
      1723,
      2672,
      3125,
      7,
      6,
      279,
      278,
      277,
      1543,
      1558,
      615,
      587,
      609,
      1498,
      1502,
      1501,
      1499,
      1500,
      1497,
      274,
      275,
    ],
    [2320, 1962, 2599, 2902, 2331, 2336, 2777, 1714, 2956, 2363, 876, 916],
    [
      2608,
      1644,
      2902,
      2331,
      2336,
      3110,
      1625,
      299,
      298,
      3024,
      2650,
      2227,
      2299,
      591,
      305,
      319,
    ],
    [
      1644,
      2597,
      2331,
      1723,
      2672,
      3125,
      294,
      298,
      284,
      357,
      356,
      8,
      363,
      359,
      358,
      878,
      916,
      830,
      2779,
      2792,
      1716,
      3053,
      1717,
      3024,
      2897,
      1698,
      1564,
      1543,
      1558,
      286,
      360,
      362,
      361,
    ],
    [1644, 2331, 1723, 889, 2779, 2794, 916, 830],
    [3168, 2672],
    [2328, 3183, 2672],
    [1978, 2380, 2606, 2679, 2672, 878, 916, 833, 2895],
    [1644, 2331, 2335, 2781, 2794],
    [1981, 2902, 877, 835],
    [2384, 2684, 2687, 2865],
    [
      1644,
      3168,
      2902,
      959,
      2868,
      2331,
      2335,
      1723,
      2679,
      2781,
      2792,
      3040,
      2672,
      3125,
      889,
      905,
      833,
      1716,
      3053,
      1717,
      2356,
      3024,
      2343,
      2227,
      1504,
      1469,
      1475,
      423,
      425,
      413,
      417,
    ],
    [2739, 2608, 1644, 2902, 2331, 2336, 3024, 300, 298, 305, 319],
    [2378, 1716, 2956, 1709, 3137, 2363, 3096, 3030],
    [
      2320,
      1963,
      2604,
      2331,
      2336,
      2739,
      2649,
      2672,
      3110,
      1625,
      1599,
      1598,
      1716,
      2956,
      1709,
      3137,
      3096,
      3024,
      2227,
      2299,
      591,
      305,
      319,
    ],
    [2781, 2798, 3007, 1716, 3053, 1717, 3029],
    [2781, 2794, 1716, 2956, 1709, 3137, 2363, 3096, 3030],
    [1644, 2591, 1650, 2331, 1721, 878, 916, 830, 2779, 2791],
    [2320, 2331, 1721, 876, 916, 792, 2778, 2790, 1716, 3073, 1709],
    [2320, 2331, 2336, 2672, 3125, 3029, 2299],
    [3168, 2672, 878, 916, 830, 2779, 2791, 1714, 3073, 2897, 1704],
    [
      3168,
      2597,
      1645,
      2849,
      877,
      863,
      2690,
      2894,
      2672,
      2820,
      1700,
      1703,
      1675,
      1684,
      1716,
      3053,
      1717,
      3024,
      2736,
    ],
    [
      2320,
      2868,
      2331,
      2335,
      1723,
      2672,
      3125,
      7,
      6,
      279,
      278,
      277,
      3053,
      1713,
      3087,
      3018,
      2240,
      604,
      1676,
      1689,
      273,
      276,
    ],
    [
      2320,
      1962,
      2599,
      2902,
      2331,
      2336,
      2777,
      2956,
      2363,
      2852,
      838,
      1716,
      1713,
      3091,
      3046,
    ],
    [
      2608,
      1644,
      2902,
      2331,
      2336,
      3110,
      1625,
      299,
      298,
      2852,
      3018,
      2650,
      2241,
      2295,
      442,
      457,
    ],
    [
      1644,
      2597,
      2331,
      1723,
      2672,
      3125,
      294,
      298,
      284,
      357,
      356,
      8,
      363,
      359,
      358,
      2848,
      876,
      912,
      830,
      2780,
      2792,
      1029,
      1013,
      3053,
      1715,
      3024,
      2876,
      1161,
      1126,
      1696,
      1697,
      1087,
      1090,
      286,
    ],
    [1644, 2331, 1723, 889, 2794, 911, 833, 2778, 2758, 2706],
    [1978, 2380, 2606, 2679, 2672, 2848, 833, 2895],
    [1644, 2331, 2335, 2781, 2794, 2722, 2746, 2761, 2703],
    [1981, 2902, 877, 2189, 834],
    [2384, 2684, 2687, 2865, 1644, 1646, 1720, 2778, 2791],
    [
      1644,
      3168,
      2902,
      959,
      2868,
      2331,
      2335,
      1723,
      2679,
      2792,
      3040,
      2672,
      2852,
      863,
      2779,
      3053,
      1715,
      3087,
      3018,
      3110,
      1626,
      2241,
      2295,
      1506,
      1508,
      1469,
      1474,
      423,
      425,
      414,
      418,
    ],
    [2739, 2608, 1644, 2902, 2331, 2336, 3013, 300, 298, 306, 320],
    [2378, 1713, 2958, 2363, 3087, 3028],
    [
      2320,
      1963,
      2604,
      2331,
      2336,
      2739,
      2649,
      2672,
      3110,
      1625,
      1599,
      1598,
      2852,
      2958,
      1713,
      3087,
      3018,
      2241,
      2295,
      306,
      320,
    ],
    [2781, 2798, 3007, 3053, 3018],
    [2781, 2794, 2958, 1713, 2363, 3087, 3028],
    [
      1644,
      2591,
      1650,
      2331,
      1721,
      2848,
      876,
      912,
      830,
      2779,
      2791,
      1029,
      1013,
      1161,
      1126,
      1696,
      1697,
      1087,
      1090,
    ],
    [2320, 2331, 1721, 2852, 801, 2778, 2790, 3073, 1713, 3024],
    [2320, 2331, 2336, 2672, 3125, 3018, 2295],
    [
      3168,
      2852,
      876,
      912,
      830,
      2779,
      2791,
      3053,
      3024,
      2672,
      3102,
      1626,
      2735,
      1676,
      1689,
    ],
    [
      3168,
      2597,
      1645,
      2849,
      877,
      863,
      2690,
      2894,
      2672,
      2820,
      1700,
      1703,
      1675,
      1684,
      3053,
      1715,
      3024,
      2735,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    [0, 1, 2, 3, 4, 20, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    [0, 1, 2, 3, 4, 21, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    [
      22,
      23,
      24,
      25,
      26,
      5,
      6,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
    ],
    [
      22,
      23,
      24,
      25,
      26,
      40,
      6,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
    ],
    [
      22,
      23,
      24,
      25,
      26,
      41,
      6,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
    ],
  ];
}
