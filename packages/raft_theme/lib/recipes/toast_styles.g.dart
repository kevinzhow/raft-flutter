// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `toastStyles`.
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

/// raft-ui recipe `toastStyles` (`src/components/toast/toast.tsx`, index.mjs:12748).
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
    [1630, 1317, 1946, 1925, 1577, 647, 1351, 108, 964],
    [1317, 1948, 1577],
    [
      1162,
      1629,
      1728,
      1573,
      1578,
      1580,
      374,
      373,
      371,
      375,
      379,
      1890,
      944,
      949,
      876,
      906,
      847,
      1505,
      1709,
      601,
      1829,
      1737,
      982,
      983,
      422,
      1314,
      643,
      1520,
      1170,
      1570,
      1948,
      544,
      513,
      537,
      558,
      534,
      529,
      372,
      1876,
      852,
      853,
      910,
      198,
      841,
      840,
      839,
      842,
      238,
      239,
      1294,
      1295,
      1302,
      1300,
      1301,
      1299,
      1298,
      1297,
      1296,
      408,
      407,
      1930,
      1424,
    ],
    [
      1682,
      1040,
      1043,
      1319,
      1583,
      199,
      200,
      119,
      120,
      121,
      122,
      117,
      118,
      1894,
      943,
      949,
      1505,
      1034,
      1039,
      1662,
      1673,
      1016,
      1813,
      376,
      377,
      378,
      855,
      854,
      201,
    ],
    [965, 1754, 1740, 1319, 1324, 277, 280],
    [1484],
    [1357, 1897, 1843, 1015, 1829],
    [1357, 1843, 1830],
    [965, 1319, 1325, 1026],
    [1630, 422, 1193, 1572, 471, 1130, 1125, 1502, 1503, 1315, 645, 1704, 584],
    [
      1305,
      1319,
      1324,
      1573,
      1578,
      1580,
      1880,
      942,
      935,
      932,
      1682,
      1308,
      1564,
      1769,
      1740,
      1933,
      621,
      615,
      1592,
      1738,
      1016,
      1813,
      1008,
      1829,
      1898,
      915,
      1900,
      442,
      435,
      441,
      461,
      450,
      423,
      982,
      984,
      280,
    ],
    [1630, 965, 765, 752, 751, 760, 759, 762, 764, 757, 756, 753, 755],
    [
      1162,
      1629,
      1728,
      1573,
      1578,
      1580,
      374,
      373,
      371,
      375,
      379,
      1890,
      944,
      949,
      876,
      906,
      847,
      1505,
      1709,
      601,
      1829,
      1737,
      982,
      983,
      1682,
      1520,
      1930,
      1421,
      1584,
      1569,
      909,
      851,
      46,
    ],
    [1630, 1317, 1946, 1925, 1577, 647, 1351, 108, 422],
    [1630, 1317, 1946, 1925, 1577, 1690, 647, 964],
    [1630, 1317, 1946, 1925, 1577, 1690, 647, 422],
    [1630, 1317, 1946, 1925, 1577, 1867, 1351, 108, 964],
    [1630, 1317, 1946, 1925, 1577, 1867, 1351, 108, 422],
    [1630, 1317, 1946, 1925, 1577, 1867, 1690, 964],
    [1630, 1317, 1946, 1925, 1577, 1867, 1690, 422],
    [1630, 1317, 1946, 1925, 1577, 659, 964],
    [1630, 1317, 1946, 1925, 1577, 659, 422],
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
