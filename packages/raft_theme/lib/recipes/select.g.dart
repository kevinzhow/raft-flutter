// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `select` (`src/components/select/select.tsx`, index.mjs:5760).
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
    RaftRecipeAxis('chrome', ['default', 'field'], 'default', false),
  ];

  static RaftSelectRecipeStyle resolve({
    RaftSelectRecipeChrome? chrome,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [chrome?.css],
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
      1305,
      1725,
      1319,
      1323,
      1575,
      1891,
      872,
      3,
      2,
      156,
      155,
      217,
      1174,
      1926,
      1023,
      1636,
      1619,
      1843,
      1017,
      1820,
      883,
      884,
      869,
      873,
      870,
      871,
      215,
      216,
    ],
    [1497, 965, 1738, 1319, 1324, 1894, 177, 1822, 1557, 180, 186, 194],
    [965, 1483, 966, 1895, 1834],
    [1317, 1941, 1575],
    [1680, 1358, 1495, 1581, 1575, 1707, 602, 1592, 1820, 1735, 1692, 1696],
    [1363, 1585, 1587, 1723, 965, 967],
    [
      965,
      1926,
      1738,
      660,
      1725,
      1319,
      1323,
      1581,
      1834,
      1575,
      1891,
      1479,
      1024,
      1708,
      1657,
      1664,
      1811,
      1013,
      1820,
      615,
      1270,
      862,
      903,
      901,
      834,
      836,
      173,
      177,
      189,
      159,
      162,
    ],
    [965, 1738, 1319, 1324, 275, 277, 1751, 1825, 173, 177, 159, 162],
    [1628, 1497, 965, 1738, 1319, 1324, 1820, 180, 177, 186, 194],
    [1483, 966, 1895],
    [1357, 1016, 1819, 1017, 1825],
    [965, 967],
    [1669, 1657, 1643, 1602, 1812, 1008, 1822],
    [1199, 1738, 621, 98, 1521, 604],
    [
      422,
      1314,
      1937,
      965,
      1185,
      1926,
      660,
      1319,
      1324,
      1575,
      1891,
      675,
      674,
      275,
      277,
      602,
      1822,
    ],
    [1657, 1669, 1834, 1811, 1822],
    [
      1305,
      1725,
      1319,
      1323,
      1575,
      1891,
      872,
      3,
      2,
      156,
      155,
      217,
      1926,
      1023,
      1820,
      884,
      869,
      873,
      870,
      871,
      215,
      216,
      1658,
      1818,
      1011,
      1,
      6,
      1174,
      1664,
      882,
    ],
    [
      965,
      1926,
      1738,
      660,
      1725,
      1319,
      1323,
      1581,
      1834,
      1575,
      1891,
      1479,
      1024,
      1708,
      1657,
      1664,
      1820,
      615,
      1270,
      862,
      903,
      901,
      834,
      836,
      173,
      177,
      189,
      159,
      162,
      1818,
      1011,
      5,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [16, 1, 2, 3, 4, 5, 17, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  ];
}
