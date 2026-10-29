// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSidebarRecipe].
class RaftSidebarRecipeStyle {
  const RaftSidebarRecipeStyle({
    required this.sidebarRoot,
    required this.sidebarHeader,
    required this.sidebarHeaderMask,
    required this.sidebarHeaderMaskLayer,
    required this.sidebarHeaderTitle,
    required this.sidebarGroupLabel,
    required this.sidebarBody,
    required this.sidebarContent,
    required this.sidebarViewport,
    required this.sidebarContentInner,
    required this.sidebarScrollbar,
    required this.sidebarLiveActivity,
  });

  /// Slot `sidebarRoot`.
  final RaftSlotStyle sidebarRoot;

  /// Slot `sidebarHeader`.
  final RaftSlotStyle sidebarHeader;

  /// Slot `sidebarHeaderMask`.
  final RaftSlotStyle sidebarHeaderMask;

  /// Slot `sidebarHeaderMaskLayer`.
  final RaftSlotStyle sidebarHeaderMaskLayer;

  /// Slot `sidebarHeaderTitle`.
  final RaftSlotStyle sidebarHeaderTitle;

  /// Slot `sidebarGroupLabel`.
  final RaftSlotStyle sidebarGroupLabel;

  /// Slot `sidebarBody`.
  final RaftSlotStyle sidebarBody;

  /// Slot `sidebarContent`.
  final RaftSlotStyle sidebarContent;

  /// Slot `sidebarViewport`.
  final RaftSlotStyle sidebarViewport;

  /// Slot `sidebarContentInner`.
  final RaftSlotStyle sidebarContentInner;

  /// Slot `sidebarScrollbar`.
  final RaftSlotStyle sidebarScrollbar;

  /// Slot `sidebarLiveActivity`.
  final RaftSlotStyle sidebarLiveActivity;

  Map<String, RaftSlotStyle> get slots => {
    'sidebarRoot': sidebarRoot,
    'sidebarHeader': sidebarHeader,
    'sidebarHeaderMask': sidebarHeaderMask,
    'sidebarHeaderMaskLayer': sidebarHeaderMaskLayer,
    'sidebarHeaderTitle': sidebarHeaderTitle,
    'sidebarGroupLabel': sidebarGroupLabel,
    'sidebarBody': sidebarBody,
    'sidebarContent': sidebarContent,
    'sidebarViewport': sidebarViewport,
    'sidebarContentInner': sidebarContentInner,
    'sidebarScrollbar': sidebarScrollbar,
    'sidebarLiveActivity': sidebarLiveActivity,
  };
}

/// raft-ui recipe `sidebarRecipe` (`src/components/sidebar/sidebar.recipe.ts`, index.mjs:2620).
///
/// Used by: SidebarBody, SidebarContent, SidebarGroupLabel, SidebarHeader, SidebarHeaderTitle, SidebarLiveActivity, SidebarRoot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarRecipe {
  static const String recipeName = 'sidebarRecipe';
  static const List<String> slotNames = [
    'sidebarRoot',
    'sidebarHeader',
    'sidebarHeaderMask',
    'sidebarHeaderMaskLayer',
    'sidebarHeaderTitle',
    'sidebarGroupLabel',
    'sidebarBody',
    'sidebarContent',
    'sidebarViewport',
    'sidebarContentInner',
    'sidebarScrollbar',
    'sidebarLiveActivity',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSidebarRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSidebarRecipeStyle(
      sidebarRoot: s[0],
      sidebarHeader: s[1],
      sidebarHeaderMask: s[2],
      sidebarHeaderMaskLayer: s[3],
      sidebarHeaderTitle: s[4],
      sidebarGroupLabel: s[5],
      sidebarBody: s[6],
      sidebarContent: s[7],
      sidebarViewport: s[8],
      sidebarContentInner: s[9],
      sidebarScrollbar: s[10],
      sidebarLiveActivity: s[11],
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
    [1682, 965, 1770, 1468, 1727, 967, 1212, 603, 1822, 1377, 634, 1439, 1452],
    [
      965,
      1319,
      1168,
      1740,
      1023,
      623,
      634,
      1663,
      603,
      1822,
      1378,
      1392,
      1396,
      385,
    ],
    [1630, 422, 1314, 1862, 111, 1265],
    [422, 1314, 1862],
    [1897, 1008, 1016, 1833, 1822, 1396],
    [1658, 1648, 1605, 1016, 1821, 1008, 1529, 1873, 1824],
    [1682, 965, 1468, 966, 1583, 603, 1377],
    [1682, 965, 1468, 1484, 966],
    [1770, 1468, 966, 1586, 1587],
    [1483, 1484, 1929, 1658, 1645, 1601],
    [1942, 965, 1908, 1324, 1668, 1558, 1894, 942, 1630, 900, 899, 898],
    [1630, 422, 1314, 1383, 643, 1943],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
