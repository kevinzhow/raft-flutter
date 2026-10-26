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
      1304,
      1723,
      1318,
      1322,
      1573,
      1889,
      872,
      3,
      2,
      156,
      155,
      217,
      1173,
      1924,
      1022,
      1634,
      1617,
      1841,
      1016,
      1818,
      883,
      884,
      869,
      873,
      870,
      871,
      215,
      216,
    ],
    [1495, 965, 1736, 1318, 1323, 1892, 177, 1820, 1555, 180, 186, 194],
    [965, 1481, 966, 1893, 1832],
    [1316, 1939, 1573],
    [1678, 1357, 1493, 1579, 1573, 1705, 602, 1590, 1818, 1733, 1690, 1694],
    [1361, 1583, 1585, 1721, 965, 967],
    [
      965,
      1924,
      1736,
      660,
      1723,
      1318,
      1322,
      1579,
      1832,
      1573,
      1889,
      1477,
      1023,
      1706,
      1655,
      1662,
      1809,
      1012,
      1818,
      615,
      1269,
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
    [965, 1736, 1318, 1323, 275, 277, 1749, 1823, 173, 177, 159, 162],
    [1626, 1495, 965, 1736, 1318, 1323, 1818, 180, 177, 186, 194],
    [1481, 966, 1893],
    [1356, 1015, 1817, 1016, 1823],
    [965, 967],
    [1667, 1655, 1641, 1600, 1810, 1007, 1820],
    [1198, 1736, 621, 98, 1519, 604],
    [
      422,
      1313,
      1935,
      965,
      1184,
      1924,
      660,
      1318,
      1323,
      1573,
      1889,
      675,
      674,
      275,
      277,
      602,
      1820,
    ],
    [1655, 1667, 1832, 1809, 1820],
    [
      1304,
      1723,
      1318,
      1322,
      1573,
      1889,
      872,
      3,
      2,
      156,
      155,
      217,
      1924,
      1022,
      1818,
      884,
      869,
      873,
      870,
      871,
      215,
      216,
      1656,
      1816,
      1010,
      1,
      6,
      1173,
      1662,
      882,
    ],
    [
      965,
      1924,
      1736,
      660,
      1723,
      1318,
      1322,
      1579,
      1832,
      1573,
      1889,
      1477,
      1023,
      1706,
      1655,
      1662,
      1818,
      615,
      1269,
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
      1816,
      1010,
      5,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [16, 1, 2, 3, 4, 5, 17, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  ];
}
