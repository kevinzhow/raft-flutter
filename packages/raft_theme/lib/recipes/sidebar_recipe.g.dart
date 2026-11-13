// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarRecipe`.
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
  };
}

/// raft-ui recipe `sidebarRecipe` (`dist/components/sidebar/sidebar.recipe.mjs`, index.mjs:4379).
///
/// Used by: SidebarBody, SidebarContent, SidebarGroupLabel, SidebarHeader, SidebarHeaderTitle, SidebarRoot.
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
    [2433, 1400, 2538, 2098, 2483, 1404, 508, 2018, 916, 2598, 1931, 954, 1997],
    [
      1400,
      1864,
      1639,
      2499,
      1466,
      942,
      954,
      2394,
      916,
      2598,
      1932,
      1949,
      265,
      267,
      609,
    ],
    [2346, 691, 1858, 2640, 2737, 1776],
    [691, 1858, 2640],
    [2681, 1449, 1456, 2609, 2598, 1949],
    [2406, 2384, 2272, 2069, 2067, 1456, 2597, 1449, 2165, 2654, 2600],
    [2433, 1400, 2098, 1401, 2252, 916, 1931],
    [2433, 1400, 2098, 2116, 1401],
    [2538, 2098, 1401, 2255, 2256],
    [2112, 2116, 2725, 2381, 2270],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  ];
}
