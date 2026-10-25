// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `panelHeader` (`src/components/panel/panel-header.recipe.ts`, index.mjs:16897).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('size', ['sm', 'md'], null, true),
  ];

  static RaftPanelHeaderRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftPanelHeaderRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, size?.css],
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
    [2477, 2478, 2482, 1644, 1946, 2902, 2331, 1725, 891, 892, 868, 2784],
    [
      2477,
      2478,
      2482,
      1644,
      1946,
      2902,
      2331,
      1725,
      891,
      892,
      868,
      2784,
      2416,
      2418,
      564,
      2408,
      2520,
      2519,
      2407,
    ],
    [1644, 2921, 2902, 2331, 2336, 878, 892, 836, 2994, 2858, 2855],
    [2597, 1645, 1644, 1646, 2036, 2037, 2038, 2035, 2040, 2039, 2034, 2033],
    [1644, 2597, 2331, 1723, 955],
    [3133, 2993, 1709, 2366, 955, 2994],
    [2597, 3133, 1714, 3073, 954, 947, 2998],
    [
      2320,
      2902,
      2331,
      1721,
      2778,
      2791,
      2958,
      1709,
      3137,
      2363,
      436,
      425,
      878,
      892,
      784,
      2994,
    ],
    [2320, 2902, 2331, 1722, 3073, 2363, 436, 425, 2994],
    [1644, 2902, 2331, 1722, 2430, 396],
    [2597, 3133, 1714, 954, 947, 2998, 3053],
    [
      2477,
      2478,
      1644,
      2902,
      2331,
      1723,
      2804,
      2328,
      1978,
      2582,
      2481,
      566,
      890,
      863,
      2417,
      2432,
      2433,
      2434,
      2449,
      2775,
      2460,
      2463,
      2567,
      2568,
      2545,
      2411,
      2410,
    ],
    [
      2477,
      2478,
      1644,
      2902,
      2331,
      1723,
      2804,
      2328,
      1978,
      2582,
      2481,
      566,
      890,
      863,
      2417,
      2432,
      2433,
      2434,
      2449,
      2775,
      2460,
      2463,
      2567,
      2568,
      2545,
      2411,
      2410,
      2416,
    ],
    [
      1644,
      2902,
      2331,
      2336,
      2921,
      2848,
      877,
      806,
      1252,
      3015,
      2413,
      2415,
      2414,
      2475,
      2530,
    ],
    [
      2597,
      1645,
      1644,
      1646,
      2539,
      2557,
      2544,
      2551,
      2422,
      2474,
      2453,
      2429,
      2475,
      2442,
      2443,
      2444,
      2441,
      2447,
      2446,
      2438,
      2436,
      2437,
      2435,
      2440,
      2439,
      2445,
      2550,
    ],
    [1644, 2597, 2331, 1723, 955, 2561, 2579],
    [3133, 955, 1712, 2963, 1717, 2366, 3095, 2946, 3013],
    [2597, 3133, 3073, 954, 947, 1716, 2363, 3021, 2451, 2536, 2532],
    [
      2320,
      2902,
      2331,
      1721,
      2958,
      1709,
      3137,
      2363,
      425,
      877,
      863,
      2690,
      3021,
      437,
    ],
    [2320, 2902, 2331, 1722, 3073, 2363, 425, 3021, 437],
    [1644, 2902, 2331, 1722, 2428, 2423, 2474, 2475, 397],
    [2597, 3133, 954, 947, 1716, 3021, 2451, 2536, 2532, 3053],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [0, 1, 2, 3, 4, 5, 10, 7, 8, 9],
    [11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    [11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    [11, 12, 13, 14, 15, 16, 21, 18, 19, 20],
  ];
}
