// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `listRow`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `listRow` (default `default`).
enum RaftListRowRecipeVariant {
  default_('default'),
  plain('plain'),
  entry('entry');

  const RaftListRowRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftListRowRecipe].
class RaftListRowRecipeStyle {
  const RaftListRowRecipeStyle({
    required this.group,
    required this.root,
    required this.icon,
    required this.body,
    required this.line,
    required this.title,
    required this.description,
    required this.meta,
    required this.value,
    required this.chevron,
  });

  /// Slot `group`.
  final RaftSlotStyle group;

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `icon`.
  final RaftSlotStyle icon;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `line`.
  final RaftSlotStyle line;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `value`.
  final RaftSlotStyle value;

  /// Slot `chevron`.
  final RaftSlotStyle chevron;

  Map<String, RaftSlotStyle> get slots => {
    'group': group,
    'root': root,
    'icon': icon,
    'body': body,
    'line': line,
    'title': title,
    'description': description,
    'meta': meta,
    'value': value,
    'chevron': chevron,
  };
}

/// raft-ui recipe `listRow` (`src/components/list-row/list-row.recipe.ts`, index.mjs:1795).
///
/// Used by: ListRow, ListRowBody, ListRowBottom, ListRowChevron, ListRowDescription, ListRowGroup, ListRowIcon, ListRowMeta, ListRowTitle, ListRowTop, ListRowValue.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftListRowRecipe {
  static const String recipeName = 'listRow';
  static const List<String> slotNames = [
    'group',
    'root',
    'icon',
    'body',
    'line',
    'title',
    'description',
    'meta',
    'value',
    'chevron',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('variant', ['default', 'plain', 'entry'], 'default', false),
    RaftRecipeAxis('interactive', ['true', 'false'], 'true', false),
    RaftRecipeAxis('wrap', ['true', 'false'], 'false', false),
  ];

  static const List<RaftRecipePackBinding> _packBindings = [
    RaftRecipePackBinding(
      'group',
      'border-top-left-radius',
      RaftRecipeTokenKind.number,
      'radius.container',
    ),
    RaftRecipePackBinding(
      'group',
      'border-top-right-radius',
      RaftRecipeTokenKind.number,
      'radius.container',
    ),
    RaftRecipePackBinding(
      'group',
      'border-bottom-left-radius',
      RaftRecipeTokenKind.number,
      'radius.container',
    ),
    RaftRecipePackBinding(
      'group',
      'border-bottom-right-radius',
      RaftRecipeTokenKind.number,
      'radius.container',
    ),
  ];

  static RaftListRowRecipeStyle resolve({
    RaftListRowRecipeVariant? variant,
    bool? interactive,
    bool? wrap,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css, interactive?.toString(), wrap?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
      bindings: _packBindings,
    );
    return RaftListRowRecipeStyle(
      group: s[0],
      root: s[1],
      icon: s[2],
      body: s[3],
      line: s[4],
      title: s[5],
      description: s[6],
      meta: s[7],
      value: s[8],
      chevron: s[9],
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
      bindings: _packBindings,
    );
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [965, 1484, 967, 1583, 1709, 620, 633, 596, 1822],
    [
      1150,
      1682,
      965,
      1929,
      1484,
      1319,
      1025,
      1662,
      1673,
      1836,
      1016,
      1528,
      1893,
      941,
      1577,
      979,
      980,
      902,
      337,
      335,
      336,
      1786,
      1540,
      1539,
      1538,
      1537,
      928,
      920,
      918,
      919,
      485,
      477,
      475,
      476,
      1473,
      339,
      545,
      513,
      554,
      546,
      536,
      538,
      526,
      524,
      405,
      419,
      1542,
      1541,
      1536,
    ],
    [965, 1740, 1319, 1324, 1788, 181, 177],
    [965, 1484, 966, 967, 1020],
    [965, 1484, 1319, 1023],
    [1484, 966, 1897, 1810, 1017, 1106],
    [1484, 966, 1897, 1813, 1787, 1932, 1840],
    [1740, 1014, 1839, 1015, 1783, 1788],
    [1416, 1740, 1897, 1845, 1788],
    [1484, 966, 1897, 1813, 1787],
    [
      1150,
      1682,
      965,
      1929,
      1484,
      1319,
      1025,
      1662,
      1673,
      1836,
      1016,
      1528,
      1893,
      941,
      1577,
      979,
      980,
      902,
      337,
      335,
      336,
      1786,
      1540,
      1539,
      1538,
      1537,
      928,
      920,
      918,
      919,
      485,
      477,
      475,
      476,
      1473,
      339,
      545,
      513,
      554,
      546,
      536,
      538,
      526,
      524,
      405,
      419,
    ],
    [
      1150,
      1682,
      965,
      1929,
      1484,
      1319,
      1025,
      1662,
      1673,
      1836,
      1016,
      1528,
      1893,
      941,
      1577,
      979,
      980,
      902,
      337,
      335,
      336,
      1786,
      1540,
      1539,
      1538,
      1537,
      928,
      920,
      918,
      919,
      485,
      477,
      475,
      476,
      338,
      545,
      513,
      554,
      546,
      536,
      538,
      526,
      524,
      405,
      419,
      1542,
      1541,
      1536,
    ],
    [
      1150,
      1682,
      965,
      1929,
      1484,
      1319,
      1025,
      1662,
      1673,
      1836,
      1016,
      1528,
      1893,
      941,
      1577,
      979,
      980,
      902,
      337,
      335,
      336,
      1786,
      1540,
      1539,
      1538,
      1537,
      928,
      920,
      918,
      919,
      485,
      477,
      475,
      476,
      338,
      545,
      513,
      554,
      546,
      536,
      538,
      526,
      524,
      405,
      419,
    ],
    [
      1150,
      1682,
      965,
      1929,
      1484,
      1319,
      1025,
      1662,
      1673,
      1836,
      1016,
      1528,
      1893,
      941,
      1577,
      979,
      980,
      902,
      337,
      335,
      336,
      1786,
      1540,
      1539,
      1538,
      1537,
      928,
      920,
      918,
      919,
      485,
      477,
      475,
      476,
      1542,
      1541,
      1536,
    ],
    [
      1150,
      1682,
      965,
      1929,
      1484,
      1319,
      1025,
      1662,
      1673,
      1836,
      1016,
      1528,
      1893,
      941,
      1577,
      979,
      980,
      902,
      337,
      335,
      336,
      1786,
      1540,
      1539,
      1538,
      1537,
      928,
      920,
      918,
      919,
      485,
      477,
      475,
      476,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 2],
    [0, 1, 2, 3, 4, 5, 9, 7, 8, 2],
    [0, 10, 2, 3, 4, 5, 6, 7, 8, 2],
    [0, 10, 2, 3, 4, 5, 9, 7, 8, 2],
    [0, 11, 2, 3, 4, 5, 6, 7, 8, 2],
    [0, 11, 2, 3, 4, 5, 9, 7, 8, 2],
    [0, 12, 2, 3, 4, 5, 6, 7, 8, 2],
    [0, 12, 2, 3, 4, 5, 9, 7, 8, 2],
    [0, 13, 2, 3, 4, 5, 6, 7, 8, 2],
    [0, 13, 2, 3, 4, 5, 9, 7, 8, 2],
    [0, 14, 2, 3, 4, 5, 6, 7, 8, 2],
    [0, 14, 2, 3, 4, 5, 9, 7, 8, 2],
  ];
}
