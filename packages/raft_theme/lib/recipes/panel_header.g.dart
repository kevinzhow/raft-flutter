// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `panelHeader`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `panelHeader`.
enum RaftPanelHeaderRecipeSize {
  sm('sm'),
  md('md');

  const RaftPanelHeaderRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftPanelHeaderRecipe].
class RaftPanelHeaderRecipeStyle {
  const RaftPanelHeaderRecipeStyle({
    required this.header,
    required this.sectionHeader,
    required this.headerIcon,
    required this.headerContent,
    required this.heading,
    required this.title,
    required this.meta,
    required this.status,
    required this.activity,
    required this.actions,
  });

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `sectionHeader`.
  final RaftSlotStyle sectionHeader;

  /// Slot `headerIcon`.
  final RaftSlotStyle headerIcon;

  /// Slot `headerContent`.
  final RaftSlotStyle headerContent;

  /// Slot `heading`.
  final RaftSlotStyle heading;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `status`.
  final RaftSlotStyle status;

  /// Slot `activity`.
  final RaftSlotStyle activity;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  Map<String, RaftSlotStyle> get slots => {
    'header': header,
    'sectionHeader': sectionHeader,
    'headerIcon': headerIcon,
    'headerContent': headerContent,
    'heading': heading,
    'title': title,
    'meta': meta,
    'status': status,
    'activity': activity,
    'actions': actions,
  };
}

/// raft-ui recipe `panelHeader` (`src/components/panel/panel-header.recipe.ts`, index.mjs:667).
///
/// Used by: PanelActions, PanelActivity, PanelHeader, PanelHeaderContent, PanelHeaderIcon, PanelHeading, PanelMeta, PanelSectionHeader, PanelStatus, PanelTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelHeaderRecipe {
  static const String recipeName = 'panelHeader';
  static const List<String> slotNames = [
    'header',
    'sectionHeader',
    'headerIcon',
    'headerContent',
    'heading',
    'title',
    'meta',
    'status',
    'activity',
    'actions',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['sm', 'md'], null, true),
  ];

  static RaftPanelHeaderRecipeStyle resolve({
    RaftPanelHeaderRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftPanelHeaderRecipeStyle(
      header: s[0],
      sectionHeader: s[1],
      headerIcon: s[2],
      headerContent: s[3],
      heading: s[4],
      title: s[5],
      meta: s[6],
      status: s[7],
      activity: s[8],
      actions: s[9],
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
      965,
      1167,
      1736,
      1318,
      1024,
      1380,
      1634,
      1619,
      1388,
      1386,
      1373,
      126,
      1372,
      623,
      634,
      595,
      1818,
      1393,
      1395,
      1397,
    ],
    [
      965,
      1167,
      1736,
      1318,
      1024,
      1380,
      1634,
      1619,
      1388,
      1386,
      1373,
      126,
      1372,
      623,
      634,
      595,
      1818,
      1393,
      1395,
      1397,
      1376,
      1394,
      1374,
      1370,
      1369,
      1368,
      1367,
      1366,
    ],
    [
      965,
      1760,
      1736,
      1318,
      1323,
      1712,
      622,
      637,
      575,
      1840,
      1691,
      1695,
      1526,
      1527,
      696,
      695,
      694,
    ],
    [965, 1481, 966, 967, 1323],
    [965, 1481, 1318, 1022],
    [1893, 1015, 1829, 1007, 1818],
    [1481, 1893, 1015, 1810, 1820],
    [
      1304,
      1736,
      1318,
      1020,
      621,
      615,
      1588,
      1015,
      1810,
      1012,
      1525,
      1820,
      279,
      277,
    ],
    [1304, 1736, 1318, 1021, 1015, 1810, 1820, 279, 277],
    [965, 1736, 1318, 1019, 1504, 1458, 1442],
    [1481, 1893, 1015, 1820, 1817],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [0, 1, 2, 3, 4, 5, 10, 7, 8, 9],
  ];
}
