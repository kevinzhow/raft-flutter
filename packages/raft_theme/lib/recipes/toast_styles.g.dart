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
    [1626, 1316, 1941, 1920, 1573, 647, 1350, 108, 964],
    [1316, 1943, 1573],
    [
      1161,
      1625,
      1724,
      1569,
      1574,
      1576,
      374,
      373,
      371,
      375,
      379,
      1886,
      944,
      949,
      876,
      906,
      847,
      1501,
      1705,
      601,
      1825,
      1733,
      982,
      983,
      422,
      1313,
      643,
      1516,
      1169,
      1566,
      1943,
      544,
      513,
      537,
      558,
      534,
      529,
      372,
      1872,
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
      1293,
      1294,
      1301,
      1299,
      1300,
      1298,
      1297,
      1296,
      1295,
      408,
      407,
      1925,
      1422,
    ],
    [
      1678,
      1039,
      1042,
      1318,
      1579,
      199,
      200,
      119,
      120,
      121,
      122,
      117,
      118,
      1890,
      943,
      949,
      1501,
      1033,
      1038,
      1658,
      1669,
      1015,
      1809,
      376,
      377,
      378,
      855,
      854,
      201,
    ],
    [965, 1750, 1736, 1318, 1323, 277, 280],
    [1481],
    [1356, 1893, 1839, 1014, 1825],
    [1356, 1839, 1826],
    [965, 1318, 1324, 1025],
    [1626, 422, 1192, 1568, 471, 1129, 1124, 1498, 1499, 1314, 645, 1700, 584],
    [
      1304,
      1318,
      1323,
      1569,
      1574,
      1576,
      1876,
      942,
      935,
      932,
      1678,
      1307,
      1560,
      1765,
      1736,
      1928,
      621,
      615,
      1588,
      1734,
      1015,
      1809,
      1007,
      1825,
      1894,
      915,
      1896,
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
    [1626, 965, 765, 752, 751, 760, 759, 762, 764, 757, 756, 753, 755],
    [
      1161,
      1625,
      1724,
      1569,
      1574,
      1576,
      374,
      373,
      371,
      375,
      379,
      1886,
      944,
      949,
      876,
      906,
      847,
      1501,
      1705,
      601,
      1825,
      1733,
      982,
      983,
      1678,
      1516,
      1925,
      1419,
      1580,
      1565,
      909,
      851,
      46,
    ],
    [1626, 1316, 1941, 1920, 1573, 647, 1350, 108, 422],
    [1626, 1316, 1941, 1920, 1573, 1686, 647, 964],
    [1626, 1316, 1941, 1920, 1573, 1686, 647, 422],
    [1626, 1316, 1941, 1920, 1573, 1863, 1350, 108, 964],
    [1626, 1316, 1941, 1920, 1573, 1863, 1350, 108, 422],
    [1626, 1316, 1941, 1920, 1573, 1863, 1686, 964],
    [1626, 1316, 1941, 1920, 1573, 1863, 1686, 422],
    [1626, 1316, 1941, 1920, 1573, 659, 964],
    [1626, 1316, 1941, 1920, 1573, 659, 422],
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
