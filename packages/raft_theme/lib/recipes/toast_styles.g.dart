// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `toastStyles`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `placement` axis of `toastStyles` (default `bottom-center`).
enum RaftToastRecipePlacement {
  bottomCenter('bottom-center'),
  bottomRight('bottom-right'),
  topCenter('top-center'),
  topRight('top-right'),
  none('none');

  const RaftToastRecipePlacement(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `strategy` axis of `toastStyles` (default `fixed`).
enum RaftToastRecipeStrategy {
  fixed('fixed'),
  absolute('absolute');

  const RaftToastRecipeStrategy(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `layout` axis of `toastStyles` (default `stacked`).
enum RaftToastRecipeLayout {
  stacked('stacked'),
  inline('inline');

  const RaftToastRecipeLayout(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftToastRecipe].
class RaftToastRecipeStyle {
  const RaftToastRecipeStyle({
    required this.viewport,
    required this.positioner,
    required this.root,
    required this.content,
    required this.icon,
    required this.body,
    required this.title,
    required this.description,
    required this.actions,
    required this.progress,
    required this.close,
    required this.arrow,
  });

  /// Slot `viewport`.
  final RaftSlotStyle viewport;

  /// Slot `positioner`.
  final RaftSlotStyle positioner;

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `icon`.
  final RaftSlotStyle icon;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  /// Slot `progress`.
  final RaftSlotStyle progress;

  /// Slot `close`.
  final RaftSlotStyle close;

  /// Slot `arrow`.
  final RaftSlotStyle arrow;

  Map<String, RaftSlotStyle> get slots => {
    'viewport': viewport,
    'positioner': positioner,
    'root': root,
    'content': content,
    'icon': icon,
    'body': body,
    'title': title,
    'description': description,
    'actions': actions,
    'progress': progress,
    'close': close,
    'arrow': arrow,
  };
}

/// raft-ui recipe `toastStyles` (`dist/components/toast/toast.mjs`, index.mjs:18669).
///
/// Used by: ToastActions, ToastArrow, ToastBody, ToastClose, ToastContent, ToastDescription, ToastIcon, ToastPositioner, ToastProgress, ToastRoot, ToastTitle, ToastViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftToastRecipe {
  static const String recipeName = 'toastStyles';
  static const List<String> slotNames = [
    'viewport',
    'positioner',
    'root',
    'content',
    'icon',
    'body',
    'title',
    'description',
    'actions',
    'progress',
    'close',
    'arrow',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'placement',
      ['bottom-center', 'bottom-right', 'top-center', 'top-right', 'none'],
      'bottom-center',
      false,
    ),
    RaftRecipeAxis('strategy', ['fixed', 'absolute'], 'fixed', false),
    RaftRecipeAxis('layout', ['stacked', 'inline'], 'stacked', false),
  ];

  static RaftToastRecipeStyle resolve({
    RaftToastRecipePlacement? placement,
    RaftToastRecipeStrategy? strategy,
    RaftToastRecipeLayout? layout,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [placement?.css, strategy?.css, layout?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftToastRecipeStyle(
      viewport: s[0],
      positioner: s[1],
      root: s[2],
      content: s[3],
      icon: s[4],
      body: s[5],
      title: s[6],
      description: s[7],
      actions: s[8],
      progress: s[9],
      close: s[10],
      arrow: s[11],
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
    [2346, 1862, 2749, 2721, 2247, 972, 1897, 191, 1399],
    [1862, 2735, 2247],
    [
      1626,
      2345,
      2485,
      2243,
      2248,
      2250,
      596,
      595,
      593,
      597,
      601,
      2671,
      1368,
      1375,
      1259,
      1325,
      1199,
      2138,
      2462,
      914,
      2605,
      2496,
      1424,
      1425,
      691,
      1858,
      965,
      2156,
      1643,
      2240,
      2735,
      848,
      810,
      839,
      864,
      836,
      828,
      594,
      2656,
      1205,
      1206,
      1329,
      371,
      1192,
      1191,
      1190,
      1193,
      413,
      414,
      1811,
      1812,
      1819,
      1817,
      1818,
      1816,
      1815,
      1814,
      1813,
      655,
      654,
      2726,
      1980,
    ],
    [
      2433,
      1489,
      1494,
      1864,
      2252,
      372,
      373,
      258,
      259,
      260,
      261,
      256,
      257,
      2676,
      1367,
      1375,
      2138,
      1481,
      1487,
      2405,
      2419,
      1456,
      2587,
      598,
      599,
      600,
      1229,
      1228,
      374,
    ],
    [1400, 1679, 2703, 2499, 1864, 1869, 474, 478],
    [2116],
    [1907, 2681, 2587, 1455, 2605],
    [1907, 2587, 2606],
    [1400, 1864, 1870, 1469],
    [2346, 691, 1667, 2242, 763, 1589, 1581, 2135, 2136, 1859, 967, 2457, 899],
    [
      1847,
      1864,
      1869,
      2243,
      2248,
      2250,
      2661,
      1366,
      1360,
      1357,
      2433,
      1850,
      2234,
      2535,
      2499,
      2729,
      940,
      933,
      2260,
      2497,
      1456,
      2587,
      1449,
      2605,
      1338,
      2684,
      2193,
      723,
      711,
      717,
      751,
      729,
      692,
      1424,
      1426,
      478,
    ],
    [
      2346,
      1400,
      1093,
      1080,
      1079,
      1088,
      1087,
      1090,
      1092,
      1085,
      1084,
      1081,
      1083,
    ],
    [
      1626,
      2345,
      2485,
      2243,
      2248,
      2250,
      596,
      595,
      593,
      597,
      601,
      2671,
      1368,
      1375,
      1259,
      1325,
      1199,
      2138,
      2462,
      914,
      2605,
      2496,
      1424,
      1425,
      2433,
      2156,
      2726,
      1977,
      2253,
      2239,
      1328,
      1203,
      72,
    ],
    [2346, 1862, 2749, 2721, 2247, 972, 1897, 191, 691],
    [2346, 1862, 2749, 2721, 2247, 972, 2440, 1399],
    [2346, 1862, 2749, 2721, 2247, 972, 2440, 691],
    [2346, 1862, 2749, 2721, 2247, 2647, 1897, 191, 1399],
    [2346, 1862, 2749, 2721, 2247, 2647, 1897, 191, 691],
    [2346, 1862, 2749, 2721, 2247, 2647, 2440, 1399],
    [2346, 1862, 2749, 2721, 2247, 2647, 2440, 691],
    [2346, 1862, 2749, 2721, 2247, 992, 1399],
    [2346, 1862, 2749, 2721, 2247, 992, 691],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [0, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [13, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [13, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [14, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [14, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [15, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [15, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [16, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [17, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [17, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [18, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [19, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [19, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [20, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [20, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [21, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [21, 1, 12, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
