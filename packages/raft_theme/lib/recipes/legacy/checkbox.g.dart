// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `checkbox`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `checkbox` (default `default`).
enum RaftCheckboxRecipeVariant {
  default_('default'),
  primary('primary');

  const RaftCheckboxRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `color` axis of `checkbox` (default `default`).
enum RaftCheckboxRecipeColor {
  default_('default'),
  primary('primary');

  const RaftCheckboxRecipeColor(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `checkbox` (default `sm`).
enum RaftCheckboxRecipeSize {
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftCheckboxRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftCheckboxRecipe].
class RaftCheckboxRecipeStyle {
  const RaftCheckboxRecipeStyle({
    required this.root,
    required this.indicator,
    required this.graphic,
    required this.outerRect,
    required this.overlayRect,
    required this.mark,
    required this.checkMark,
    required this.indeterminateMark,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  /// Slot `graphic`.
  final RaftSlotStyle graphic;

  /// Slot `outerRect`.
  final RaftSlotStyle outerRect;

  /// Slot `overlayRect`.
  final RaftSlotStyle overlayRect;

  /// Slot `mark`.
  final RaftSlotStyle mark;

  /// Slot `checkMark`.
  final RaftSlotStyle checkMark;

  /// Slot `indeterminateMark`.
  final RaftSlotStyle indeterminateMark;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'indicator': indicator,
    'graphic': graphic,
    'outerRect': outerRect,
    'overlayRect': overlayRect,
    'mark': mark,
    'checkMark': checkMark,
    'indeterminateMark': indeterminateMark,
  };
}

/// raft-ui recipe `checkbox` (`src/components/checkbox/checkbox.tsx`, index.mjs:2683).
///
/// Used by: Checkbox, MarkdownCheckbox, MessageMultiSelectCheckbox.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCheckboxRecipe {
  static const String recipeName = 'checkbox';
  static const List<String> slotNames = [
    'root',
    'indicator',
    'graphic',
    'outerRect',
    'overlayRect',
    'mark',
    'checkMark',
    'indeterminateMark',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['default', 'primary'], 'default', false),
    RaftRecipeAxis('color', ['default', 'primary'], 'default', false),
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'sm', false),
  ];

  static RaftCheckboxRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftCheckboxRecipeVariant? variant,
    RaftCheckboxRecipeColor? color,
    RaftCheckboxRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, variant?.css, color?.css, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftCheckboxRecipeStyle(
      root: s[0],
      indicator: s[1],
      graphic: s[2],
      outerRect: s[3],
      overlayRect: s[4],
      mark: s[5],
      checkMark: s[6],
      indeterminateMark: s[7],
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
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      2914,
    ],
    [2739],
    [3115, 1627, 1637, 2616],
    [2739, 2649, 3126, 1627, 1637, 2616, 1861, 1895, 1881],
    [586, 2371, 3080, 2902, 2664, 152],
    [144, 2862, 2649, 3119, 1628, 1637, 2616, 2612, 2613],
    [2327, 2863, 2649, 3119, 1627, 1637, 2616, 2614],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      2915,
    ],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      2917,
    ],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      1915,
      2838,
      1702,
      2888,
      1142,
      3112,
      1625,
      1637,
      2616,
      605,
      1458,
      2610,
      2915,
      1447,
      1516,
      1058,
      1069,
      1470,
      1439,
      1514,
    ],
    [2739, 586, 2322, 2925],
    [
      3115,
      1627,
      1637,
      2616,
      1642,
      2944,
      1082,
      1890,
      1103,
      1875,
      1891,
      1104,
      1896,
      1105,
      1877,
      1882,
      1854,
      1865,
      1094,
      1098,
      1101,
      1860,
      1856,
      1867,
      1893,
      1898,
      1879,
      1884,
      1097,
      1096,
      1100,
    ],
    [586, 2371, 3080, 2902, 2664, 152, 3016, 1862],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      1915,
      2838,
      1702,
      2888,
      1142,
      3112,
      1625,
      1637,
      2616,
      605,
      1458,
      2610,
      2916,
      1447,
      1516,
      1058,
      1069,
      1470,
      1439,
      1514,
    ],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      1915,
      2838,
      1702,
      2888,
      1142,
      3112,
      1625,
      1637,
      2616,
      605,
      1458,
      2610,
      2917,
      1447,
      1516,
      1058,
      1069,
      1470,
      1439,
      1514,
    ],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      1915,
      2838,
      1702,
      2888,
      1142,
      3112,
      1625,
      1637,
      2616,
      605,
      1458,
      2610,
      2915,
      1449,
      1517,
      2275,
      2278,
      1058,
      1069,
      1128,
      1129,
      2274,
      2277,
      1470,
      1439,
      1514,
    ],
    [
      3115,
      1627,
      1637,
      2616,
      1642,
      2944,
      1082,
      1890,
      1103,
      1876,
      1892,
      1897,
      1878,
      1883,
      1855,
      1866,
      1095,
      1099,
      1102,
      1860,
      1856,
      1867,
      1893,
      1898,
      1879,
      1884,
      1097,
      1096,
      1100,
    ],
    [
      2739,
      2649,
      3126,
      1627,
      1637,
      2616,
      1861,
      1895,
      1881,
      1894,
      1880,
      1899,
      1885,
    ],
    [586, 2371, 3080, 2902, 2664, 152, 3046, 1862],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      1915,
      2838,
      1702,
      2888,
      1142,
      3112,
      1625,
      1637,
      2616,
      605,
      1458,
      2610,
      2916,
      1449,
      1517,
      2275,
      2278,
      1058,
      1069,
      1128,
      1129,
      2274,
      2277,
      1470,
      1439,
      1514,
    ],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2672,
      1677,
      1683,
      1464,
      619,
      617,
      618,
      624,
      1915,
      2838,
      1702,
      2888,
      1142,
      3112,
      1625,
      1637,
      2616,
      605,
      1458,
      2610,
      2917,
      1449,
      1517,
      2275,
      2278,
      1058,
      1069,
      1128,
      1129,
      2274,
      2277,
      1470,
      1439,
      1514,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 1, 2, 3, 4, 5, 6],
    [7, 1, 1, 2, 3, 4, 5, 6],
    [8, 1, 1, 2, 3, 4, 5, 6],
    [0, 1, 1, 2, 3, 4, 5, 6],
    [7, 1, 1, 2, 3, 4, 5, 6],
    [8, 1, 1, 2, 3, 4, 5, 6],
    [0, 1, 1, 2, 3, 4, 5, 6],
    [7, 1, 1, 2, 3, 4, 5, 6],
    [8, 1, 1, 2, 3, 4, 5, 6],
    [0, 1, 1, 2, 3, 4, 5, 6],
    [7, 1, 1, 2, 3, 4, 5, 6],
    [8, 1, 1, 2, 3, 4, 5, 6],
    [9, 1, 10, 11, 3, 12, 5, 6],
    [13, 1, 10, 11, 3, 12, 5, 6],
    [14, 1, 10, 11, 3, 12, 5, 6],
    [15, 1, 10, 16, 17, 18, 5, 6],
    [19, 1, 10, 16, 17, 18, 5, 6],
    [20, 1, 10, 16, 17, 18, 5, 6],
    [15, 1, 10, 16, 17, 18, 5, 6],
    [19, 1, 10, 16, 17, 18, 5, 6],
    [20, 1, 10, 16, 17, 18, 5, 6],
    [15, 1, 10, 16, 17, 18, 5, 6],
    [19, 1, 10, 16, 17, 18, 5, 6],
    [20, 1, 10, 16, 17, 18, 5, 6],
  ];
}
