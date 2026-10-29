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
      1168,
      1740,
      1319,
      1025,
      1382,
      1638,
      1623,
      1390,
      1388,
      1375,
      126,
      1374,
      623,
      634,
      595,
      1822,
      1395,
      1397,
      1399,
    ],
    [
      965,
      1168,
      1740,
      1319,
      1025,
      1382,
      1638,
      1623,
      1390,
      1388,
      1375,
      126,
      1374,
      623,
      634,
      595,
      1822,
      1395,
      1397,
      1399,
      1378,
      1396,
      1376,
      1372,
      1371,
      1370,
      1369,
      1368,
    ],
    [
      965,
      1764,
      1740,
      1319,
      1324,
      1716,
      622,
      637,
      575,
      1844,
      1695,
      1699,
      1530,
      1531,
      696,
      695,
      694,
    ],
    [965, 1484, 966, 967, 1324],
    [965, 1484, 1319, 1023],
    [1897, 1016, 1833, 1008, 1822],
    [1484, 1897, 1016, 1814, 1824],
    [
      1305,
      1740,
      1319,
      1021,
      621,
      615,
      1592,
      1016,
      1814,
      1013,
      1529,
      1824,
      279,
      277,
    ],
    [1305, 1740, 1319, 1022, 1016, 1814, 1824, 279, 277],
    [965, 1740, 1319, 1020, 1508, 1461, 1445],
    [1484, 1897, 1016, 1824, 1821],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [0, 1, 2, 3, 4, 5, 10, 7, 8, 9],
  ];
}
