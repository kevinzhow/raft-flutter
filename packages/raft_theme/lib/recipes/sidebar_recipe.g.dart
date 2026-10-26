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
    [1678, 965, 1766, 1465, 1723, 967, 1211, 603, 1818, 1375, 634, 1436, 1449],
    [
      965,
      1318,
      1167,
      1736,
      1022,
      623,
      634,
      1659,
      603,
      1818,
      1376,
      1390,
      1394,
      385,
    ],
    [1626, 422, 1313, 1858, 111, 1264],
    [422, 1313, 1858],
    [1893, 1007, 1015, 1829, 1818, 1394],
    [1654, 1644, 1601, 1015, 1817, 1007, 1525, 1869, 1820],
    [1678, 965, 1465, 966, 1579, 603, 1375],
    [1678, 965, 1465, 1481, 966],
    [1766, 1465, 966, 1582, 1583],
    [1480, 1481, 1924, 1654, 1641, 1597],
    [1937, 965, 1904, 1323, 1664, 1554, 1890, 942, 1626, 900, 899, 898],
    [1626, 422, 1313, 1381, 643, 1938],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
