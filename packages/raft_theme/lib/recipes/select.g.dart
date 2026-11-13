// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `select`.
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
    required this.fitFrame,
    required this.sizer,
    required this.sizerLabel,
    required this.sizerPlaceholder,
    required this.positioner,
    required this.content,
    required this.listFrame,
    required this.list,
    required this.item,
    required this.actionItem,
    required this.itemLeading,
    required this.itemIndicator,
    required this.itemText,
    required this.itemDescription,
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

  /// Slot `fitFrame`.
  final RaftSlotStyle fitFrame;

  /// Slot `sizer`.
  final RaftSlotStyle sizer;

  /// Slot `sizerLabel`.
  final RaftSlotStyle sizerLabel;

  /// Slot `sizerPlaceholder`.
  final RaftSlotStyle sizerPlaceholder;

  /// Slot `positioner`.
  final RaftSlotStyle positioner;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `listFrame`.
  final RaftSlotStyle listFrame;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `actionItem`.
  final RaftSlotStyle actionItem;

  /// Slot `itemLeading`.
  final RaftSlotStyle itemLeading;

  /// Slot `itemIndicator`.
  final RaftSlotStyle itemIndicator;

  /// Slot `itemText`.
  final RaftSlotStyle itemText;

  /// Slot `itemDescription`.
  final RaftSlotStyle itemDescription;

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
    'fitFrame': fitFrame,
    'sizer': sizer,
    'sizerLabel': sizerLabel,
    'sizerPlaceholder': sizerPlaceholder,
    'positioner': positioner,
    'content': content,
    'listFrame': listFrame,
    'list': list,
    'item': item,
    'actionItem': actionItem,
    'itemLeading': itemLeading,
    'itemIndicator': itemIndicator,
    'itemText': itemText,
    'itemDescription': itemDescription,
    'label': label,
    'group': group,
    'groupLabel': groupLabel,
    'separator': separator,
    'scrollArrow': scrollArrow,
    'empty': empty,
  };
}

/// raft-ui recipe `select` (`dist/components/select/select.mjs`, index.mjs:8491).
///
/// Used by: SelectActionItem, SelectContent, SelectGroup, SelectGroupLabel, SelectIcon, SelectItem, SelectItemDescription, SelectItemIndicator, SelectItemLeading, SelectItemText, SelectLabel, SelectList, SelectPopup, SelectScrollDownArrow, SelectScrollUpArrow, SelectSeparator, SelectTrigger, SelectValue.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSelectRecipe {
  static const String recipeName = 'select';
  static const List<String> slotNames = [
    'trigger',
    'icon',
    'value',
    'fitFrame',
    'sizer',
    'sizerLabel',
    'sizerPlaceholder',
    'positioner',
    'content',
    'listFrame',
    'list',
    'item',
    'actionItem',
    'itemLeading',
    'itemIndicator',
    'itemText',
    'itemDescription',
    'label',
    'group',
    'groupLabel',
    'separator',
    'scrollArrow',
    'empty',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('chrome', ['default', 'field'], 'default', false),
    RaftRecipeAxis('fit', ['true', 'false'], null, true),
  ];

  static RaftSelectRecipeStyle resolve({
    RaftSelectRecipeChrome? chrome,
    bool? fit,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [chrome?.css, fit?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSelectRecipeStyle(
      trigger: s[0],
      icon: s[1],
      value: s[2],
      fitFrame: s[3],
      sizer: s[4],
      sizerLabel: s[5],
      sizerPlaceholder: s[6],
      positioner: s[7],
      content: s[8],
      listFrame: s[9],
      list: s[10],
      item: s[11],
      actionItem: s[12],
      itemLeading: s[13],
      itemIndicator: s[14],
      itemText: s[15],
      itemDescription: s[16],
      label: s[17],
      group: s[18],
      groupLabel: s[19],
      separator: s[20],
      scrollArrow: s[21],
      empty: s[22],
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
      1255,
      4,
      3,
      320,
      319,
      391,
      1674,
      2725,
      1466,
      2454,
      2360,
      2301,
      941,
      952,
      1788,
      2622,
      1457,
      2598,
      1271,
      1272,
      1182,
      1354,
      1172,
      1341,
      1252,
      1256,
      1253,
      1254,
      389,
      390,
    ],
    [2132, 1400, 2499, 1864, 1869, 2678, 348, 2600, 2229, 352, 357, 366],
    [1400, 2116, 1401, 2681, 2613],
    [1489, 2116, 1401, 1494],
    [988, 2476, 1400, 1644, 1404, 2252, 2346, 1861, 2483],
    [2729, 1457],
    [2729, 1453],
    [1862, 2746, 2247],
    [
      2433,
      1911,
      2129,
      2252,
      1979,
      2247,
      2462,
      915,
      2261,
      2598,
      2496,
      2445,
      2449,
    ],
    [177, 2098],
    [1915, 2098, 2481, 1400, 1404, 2399],
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
      1408,
      1480,
      1485,
      2461,
      2402,
      2430,
      2587,
      1453,
      2598,
      933,
      1783,
      1237,
      1309,
      1306,
      1185,
      1187,
      344,
      348,
      360,
      327,
      330,
    ],
    [
      1400,
      2725,
      2499,
      993,
      2483,
      1864,
      1467,
      2252,
      2613,
      2247,
      2675,
      2113,
      2461,
      2402,
      2430,
      2587,
      1453,
      2603,
      933,
      1783,
      1237,
      1185,
      1187,
      344,
      348,
      327,
      330,
    ],
    [1400, 2499, 1864, 1869, 472, 474, 2517, 2603, 344, 348, 327, 330],
    [2346, 2132, 1400, 2499, 1864, 1869, 2598, 352, 348, 357, 366],
    [2116, 1401, 1901, 2733],
    [2237, 2116, 805, 2733, 648, 1456, 2588, 1455, 2600],
    [1907, 1456, 2597, 1457, 2603],
    [1400, 1404],
    [2417, 2402, 2381, 2274, 2588, 1449, 2600],
    [1680, 2499, 940, 177, 2158, 918],
    [
      691,
      1858,
      2747,
      1400,
      1658,
      2725,
      993,
      1864,
      1869,
      2247,
      2675,
      1007,
      1006,
      472,
      474,
      915,
      2600,
    ],
    [2402, 2417, 2613, 2587, 2600],
    [
      1847,
      2483,
      1864,
      1868,
      2247,
      2675,
      1255,
      4,
      3,
      320,
      319,
      391,
      1674,
      1466,
      2454,
      2360,
      2301,
      941,
      952,
      1788,
      2622,
      1457,
      2598,
      1271,
      1272,
      1182,
      1354,
      1172,
      1341,
      1252,
      1256,
      1253,
      1254,
      389,
      390,
      2723,
      2122,
      1961,
    ],
    [
      1847,
      2483,
      1864,
      1868,
      2247,
      2675,
      1255,
      4,
      3,
      320,
      319,
      391,
      2725,
      1466,
      941,
      952,
      1788,
      2598,
      1272,
      1182,
      1354,
      1172,
      1341,
      1252,
      1256,
      1253,
      1254,
      389,
      390,
      2403,
      2596,
      1451,
      2,
      8,
      1674,
      2454,
      2412,
      1270,
    ],
    [2729, 1451],
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
      1408,
      1480,
      1485,
      2461,
      2402,
      2430,
      2598,
      933,
      1783,
      1237,
      1309,
      1306,
      1185,
      1187,
      344,
      348,
      360,
      327,
      330,
      2596,
      1451,
      7,
    ],
    [
      1400,
      2725,
      2499,
      993,
      2483,
      1864,
      1467,
      2252,
      2613,
      2247,
      2675,
      2113,
      2461,
      2402,
      2430,
      2603,
      933,
      1783,
      1237,
      1185,
      1187,
      344,
      348,
      327,
      330,
      2596,
      1451,
    ],
    [
      1847,
      2483,
      1864,
      1868,
      2247,
      2675,
      1255,
      4,
      3,
      320,
      319,
      391,
      1466,
      941,
      952,
      1788,
      2598,
      1272,
      1182,
      1354,
      1172,
      1341,
      1252,
      1256,
      1253,
      1254,
      389,
      390,
      2403,
      2596,
      1451,
      2,
      8,
      1674,
      2454,
      2412,
      1270,
      2723,
      2122,
      1961,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
    ],
    [
      23,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
    ],
    [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
    ],
    [
      24,
      1,
      2,
      3,
      4,
      25,
      25,
      7,
      8,
      9,
      10,
      26,
      27,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
    ],
    [
      28,
      1,
      2,
      3,
      4,
      25,
      25,
      7,
      8,
      9,
      10,
      26,
      27,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
    ],
    [
      24,
      1,
      2,
      3,
      4,
      25,
      25,
      7,
      8,
      9,
      10,
      26,
      27,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
    ],
  ];
}
