// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `panelHeader`.
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

/// raft-ui recipe `panelHeader` (`dist/components/panel/panel-header.recipe.mjs`, index.mjs:2538).
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
      1400,
      1639,
      2499,
      1864,
      1468,
      1937,
      2394,
      265,
      267,
      942,
      954,
      910,
      2598,
      1947,
      1950,
      1951,
    ],
    [
      1400,
      1639,
      2499,
      1864,
      1468,
      1937,
      2394,
      265,
      267,
      942,
      954,
      910,
      2598,
      1947,
      1950,
      1951,
      1932,
      1949,
      1929,
      1928,
      1927,
      1926,
      1925,
      1924,
    ],
    [
      1400,
      2528,
      2499,
      1864,
      1869,
      2079,
      2076,
      2471,
      941,
      958,
      888,
      2621,
      2446,
      2450,
      2174,
      2175,
      1032,
      1031,
      1030,
    ],
    [1400, 2116, 1401, 1404, 1869, 2000, 2002, 2003, 2001],
    [1400, 2116, 1864, 1466],
    [2681, 1456, 2609, 1449, 2598],
    [2116, 2681, 1456, 2588, 2600, 1999, 2090],
    [
      1847,
      2499,
      1864,
      1464,
      940,
      933,
      2260,
      1456,
      2588,
      1453,
      2165,
      2600,
      477,
      474,
    ],
    [1847, 2499, 1864, 1465, 1456, 2588, 2600, 477, 474, 137],
    [1400, 2499, 1864, 1463, 2038, 543],
    [2116, 2681, 1456, 2600, 1999, 2090, 2597],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [0, 1, 2, 3, 4, 5, 10, 7, 8, 9],
  ];
}
