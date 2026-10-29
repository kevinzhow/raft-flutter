// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarRecipe`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `sidebarRecipe` (`src/components/sidebar/sidebar.recipe.ts`, index.mjs:3162).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSidebarRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
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
    [2804, 1644, 2925, 2583, 2868, 1646, 2044, 776, 2552],
    [1644, 2331, 1725, 1946, 2902, 891, 892, 776, 2784, 2418, 2471, 565],
    [2739, 586, 2323, 3077, 156, 2189],
    [586, 2323, 3077],
    [3133, 3041, 1709, 3013],
    [2779, 2758, 2706, 1714, 2956, 1713, 3137, 3097, 3018],
    [2804, 1644, 2583, 1645, 2679, 776, 2419],
    [2804, 1644, 2583, 2597, 1645],
    [2925, 2583, 1645, 2682, 2684],
    [2595, 2597, 3168, 2779, 2762, 2701],
    [3181, 1644, 3149, 2336, 2791, 2649, 3126, 1626, 2739, 1584, 1583, 1582],
    [2739, 586, 2323, 2448, 937, 3182],
    [1644, 2925, 2583, 2868, 1646, 2044, 2804, 825, 539, 2527, 2526, 2553],
    [
      1644,
      2902,
      2331,
      1725,
      586,
      2323,
      3077,
      3180,
      2328,
      1945,
      890,
      863,
      2773,
      2569,
      384,
    ],
    [2739, 586, 2323, 3077, 156, 874, 1975],
    [586, 2323, 3077, 1980, 1267, 1266, 1265, 1264, 1262, 1263, 1261, 1260],
    [3133, 1712, 2963, 1713, 3018],
    [2804, 1644, 2583, 1645, 2679, 825],
    [2595, 2597, 3168, 2701, 2773, 2569, 2755],
    [3181, 1644, 3149, 2791, 2649, 3126, 1626, 2739, 1584, 1583, 1582, 2337],
    [
      2739,
      586,
      2323,
      2448,
      942,
      3179,
      2727,
      2749,
      2130,
      2124,
      2129,
      2121,
      2131,
      2128,
      2126,
      2125,
      2123,
      2122,
      2127,
      126,
      127,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [12, 13, 14, 15, 16, 5, 17, 7, 8, 18, 19, 20],
  ];
}
