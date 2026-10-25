// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `select`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `chrome` axis of `select` (default `default`).
enum RaftSelectRecipeChrome {
  default_('default'),
  field('field');

  const RaftSelectRecipeChrome(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftSelectRecipe].
class RaftSelectRecipeStyle {
  const RaftSelectRecipeStyle({
    required this.trigger,
    required this.icon,
    required this.value,
    required this.positioner,
    required this.content,
    required this.list,
    required this.item,
    required this.itemLeading,
    required this.itemIndicator,
    required this.itemText,
    required this.label,
    required this.group,
    required this.groupLabel,
    required this.separator,
    required this.scrollArrow,
    required this.empty,
  });

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `icon`.
  final RaftSlotStyle icon;

  /// Slot `value`.
  final RaftSlotStyle value;

  /// Slot `positioner`.
  final RaftSlotStyle positioner;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `itemLeading`.
  final RaftSlotStyle itemLeading;

  /// Slot `itemIndicator`.
  final RaftSlotStyle itemIndicator;

  /// Slot `itemText`.
  final RaftSlotStyle itemText;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `group`.
  final RaftSlotStyle group;

  /// Slot `groupLabel`.
  final RaftSlotStyle groupLabel;

  /// Slot `separator`.
  final RaftSlotStyle separator;

  /// Slot `scrollArrow`.
  final RaftSlotStyle scrollArrow;

  /// Slot `empty`.
  final RaftSlotStyle empty;

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'icon': icon,
    'value': value,
    'positioner': positioner,
    'content': content,
    'list': list,
    'item': item,
    'itemLeading': itemLeading,
    'itemIndicator': itemIndicator,
    'itemText': itemText,
    'label': label,
    'group': group,
    'groupLabel': groupLabel,
    'separator': separator,
    'scrollArrow': scrollArrow,
    'empty': empty,
  };
}

/// raft-ui recipe `select` (`src/components/select/select.tsx`, index.mjs:7218).
///
/// Used by: SelectContent, SelectGroup, SelectGroupLabel, SelectIcon, SelectItem, SelectItemIndicator, SelectItemLeading, SelectItemText, SelectLabel, SelectList, SelectPopup, SelectScrollDownArrow, SelectScrollUpArrow, SelectSeparator, SelectTrigger, SelectValue, Step, Steps, useComposerSuggestions.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSelectRecipe {
  static const String recipeName = 'select';
  static const List<String> slotNames = [
    'trigger',
    'icon',
    'value',
    'positioner',
    'content',
    'list',
    'item',
    'itemLeading',
    'itemIndicator',
    'itemText',
    'label',
    'group',
    'groupLabel',
    'separator',
    'scrollArrow',
    'empty',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('chrome', ['default', 'field'], 'default', false),
  ];

  static RaftSelectRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftSelectRecipeChrome? chrome,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, chrome?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSelectRecipeStyle(
      trigger: s[0],
      icon: s[1],
      value: s[2],
      positioner: s[3],
      content: s[4],
      list: s[5],
      item: s[6],
      itemLeading: s[7],
      itemIndicator: s[8],
      itemText: s[9],
      label: s[10],
      group: s[11],
      groupLabel: s[12],
      separator: s[13],
      scrollArrow: s[14],
      empty: s[15],
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
      1524,
      1532,
      1527,
      1528,
      1530,
      7,
      6,
      281,
      280,
      366,
      364,
      365,
      3168,
      1543,
      1558,
      615,
      587,
      609,
      368,
      330,
    ],
    [2608, 1644, 2902, 2331, 2336, 2654, 3128, 300, 298, 306, 320],
    [1644, 2597, 1645, 3133, 3040],
    [2328, 3183, 2672],
    [2804, 2380, 2679, 2672, 3139, 2596, 878, 916, 833, 2896],
    [2384, 2684, 2687, 2866],
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
      3040,
      2672,
      3125,
      889,
      905,
      833,
      2792,
      3073,
      1709,
      2356,
      3024,
      2343,
      9,
      2247,
      1507,
      1586,
      1587,
      1352,
      1469,
      1475,
      294,
      298,
      283,
      285,
    ],
    [1644, 2902, 2331, 2336, 423, 425, 2917, 3024, 294, 298, 284, 285],
    [2739, 2608, 1644, 2902, 2331, 2336, 3024, 299, 298, 307, 321],
    [2597, 1645, 3133],
    [2378, 1716, 2956, 1717, 3137, 2363, 3096, 3024],
    [1644, 1646],
    [2781, 2794, 1716, 2956, 1717, 3137, 2363, 3096, 3030],
    [1981, 2902, 877, 835],
    [
      586,
      2323,
      3179,
      1644,
      1965,
      3168,
      959,
      2331,
      2336,
      2672,
      3125,
      1212,
      1210,
      423,
      425,
      916,
      833,
      3024,
      1211,
      1209,
    ],
    [2781, 2798, 3007, 1716, 3053, 1717, 3029],
    [
      2320,
      2868,
      2331,
      2335,
      1723,
      2672,
      3125,
      1524,
      1532,
      1527,
      1528,
      1530,
      7,
      6,
      281,
      280,
      366,
      364,
      365,
      3168,
      1543,
      1558,
      615,
      587,
      609,
      368,
      330,
      1978,
      2781,
      2794,
      3012,
      1711,
      4,
      11,
    ],
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
      3040,
      2672,
      3125,
      889,
      905,
      833,
      2792,
      3024,
      2343,
      2247,
      1507,
      1586,
      1587,
      1352,
      1469,
      1475,
      294,
      298,
      283,
      285,
      3012,
      1711,
      10,
    ],
    [
      2320,
      2868,
      2331,
      2335,
      1723,
      2672,
      3125,
      1524,
      1532,
      1527,
      1528,
      1530,
      7,
      6,
      281,
      280,
      366,
      364,
      365,
      3053,
      1713,
      3087,
      3018,
      2240,
      604,
      1676,
      1689,
      5,
      12,
    ],
    [2804, 2380, 2607, 2679, 2672, 2848, 833, 2895],
    [2384, 2684, 2687, 2866, 1644, 1646, 1720, 2777, 2791],
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
      3040,
      2672,
      2852,
      863,
      2779,
      2792,
      2962,
      1715,
      2354,
      3087,
      3018,
      3110,
      1626,
      2241,
      2295,
      1506,
      1508,
      1585,
      1588,
      1469,
      1474,
      294,
      298,
      284,
      286,
    ],
    [1644, 2902, 2331, 2336, 423, 425, 2915, 3018, 294, 298, 284, 286],
    [2739, 2608, 1644, 2902, 2331, 2336, 3013, 299, 298, 306, 320],
    [2378, 1713, 2958, 2363, 3087, 3013],
    [1644, 1646, 1720],
    [2794, 2779, 2958, 1713, 2363, 3087, 3028],
    [1981, 2902, 877, 2189, 834],
    [
      586,
      2323,
      3179,
      1644,
      1965,
      3168,
      959,
      2331,
      2336,
      2672,
      3125,
      1212,
      1210,
      423,
      425,
      833,
      3021,
      2298,
    ],
    [2781, 2798, 3007, 3053, 3018],
    [
      2320,
      2868,
      2331,
      2335,
      1723,
      2672,
      3125,
      1524,
      1532,
      1527,
      1528,
      1530,
      7,
      6,
      281,
      280,
      366,
      364,
      365,
      3087,
      3018,
      2240,
      604,
      1676,
      1689,
      1978,
      2781,
      2794,
      3012,
      1711,
      4,
      11,
    ],
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
      3040,
      2672,
      2852,
      863,
      2779,
      2792,
      3087,
      3018,
      3110,
      1626,
      2241,
      2295,
      1506,
      1508,
      1585,
      1588,
      1469,
      1474,
      294,
      298,
      284,
      286,
      3012,
      1711,
      10,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [16, 1, 2, 3, 4, 5, 17, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [18, 1, 2, 3, 19, 20, 21, 22, 23, 9, 24, 25, 26, 27, 28, 29],
    [30, 1, 2, 3, 19, 20, 31, 22, 23, 9, 24, 25, 26, 27, 28, 29],
  ];
}
