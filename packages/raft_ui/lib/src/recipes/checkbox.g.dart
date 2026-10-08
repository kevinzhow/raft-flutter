// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `checkbox`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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
  const RaftCheckboxRecipeStyle({required this.root, required this.indicator, required this.graphic, required this.outerRect, required this.overlayRect, required this.mark, required this.checkMark, required this.indeterminateMark});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'indicator': indicator, 'graphic': graphic, 'outerRect': outerRect, 'overlayRect': overlayRect, 'mark': mark, 'checkMark': checkMark, 'indeterminateMark': indeterminateMark};
}

/// raft-ui recipe `checkbox` (`src/components/checkbox/checkbox.tsx`, index.mjs:2672).
///
/// Used by: Checkbox, MarkdownCheckbox, MessageMultiSelectCheckbox.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCheckboxRecipe {
  static const String recipeName = 'checkbox';
  static const List<String> slotNames = ['root', 'indicator', 'graphic', 'outerRect', 'overlayRect', 'mark', 'checkMark', 'indeterminateMark'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['default', 'primary'], 'default', false),
    RaftRecipeAxis('color', ['default', 'primary'], 'default', false),
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'sm', false),
  ];

  static RaftCheckboxRecipeStyle resolve({required RaftRecipeTheme theme, RaftCheckboxRecipeVariant? variant, RaftCheckboxRecipeColor? color, RaftCheckboxRecipeSize? size, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, variant?.css, color?.css, size?.css], states, tokens);
    return RaftCheckboxRecipeStyle(root: s[0], indicator: s[1], graphic: s[2], outerRect: s[3], overlayRect: s[4], mark: s[5], checkMark: s[6], indeterminateMark: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 2879],
    [2716],
    [3074, 1603, 1613, 2593],
    [2716, 2626, 3085, 1603, 1613, 2593, 1836, 1890, 1854],
    [580, 2352, 3039, 2867, 2641, 152],
    [144, 2829, 2626, 3078, 1604, 1613, 2593, 2589, 2590],
    [2308, 2830, 2626, 3078, 1603, 1613, 2593, 2591],
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 2880],
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 2882],
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 1914, 2808, 1677, 2854, 1123, 3071, 1601, 1613, 2593, 599, 1436, 2587, 2880, 1425, 1492, 1038, 1049, 1448, 1417, 1490],
    [2716, 580, 2303, 2890],
    [3074, 1603, 1613, 2593, 1618, 2909, 1062, 1885, 1083, 1848, 1886, 1084, 1891, 1085, 1850, 1855, 1829, 1840, 1074, 1078, 1081, 1835, 1831, 1842, 1888, 1893, 1852, 1857, 1077, 1076, 1080],
    [580, 2352, 3039, 2867, 2641, 152, 2979, 1837],
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 1914, 2808, 1677, 2854, 1123, 3071, 1601, 1613, 2593, 599, 1436, 2587, 2881, 1425, 1492, 1038, 1049, 1448, 1417, 1490],
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 1914, 2808, 1677, 2854, 1123, 3071, 1601, 1613, 2593, 599, 1436, 2587, 2882, 1425, 1492, 1038, 1049, 1448, 1417, 1490],
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 1914, 2808, 1677, 2854, 1123, 3071, 1601, 1613, 2593, 599, 1436, 2587, 2880, 1427, 1493, 2256, 2259, 1038, 1049, 1108, 1109, 2255, 2258, 1448, 1417, 1490],
    [3074, 1603, 1613, 2593, 1618, 2909, 1062, 1885, 1083, 1849, 1887, 1892, 1851, 1856, 1830, 1841, 1075, 1079, 1082, 1835, 1831, 1842, 1888, 1893, 1852, 1857, 1077, 1076, 1080],
    [2716, 2626, 3085, 1603, 1613, 2593, 1836, 1890, 1854, 1889, 1853, 1894, 1858],
    [580, 2352, 3039, 2867, 2641, 152, 3010, 1837],
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 1914, 2808, 1677, 2854, 1123, 3071, 1601, 1613, 2593, 599, 1436, 2587, 2881, 1427, 1493, 2256, 2259, 1038, 1049, 1108, 1109, 2255, 2258, 1448, 1417, 1490],
    [2775, 2301, 2867, 3044, 2312, 2317, 2649, 1653, 1659, 1442, 613, 611, 612, 618, 1914, 2808, 1677, 2854, 1123, 3071, 1601, 1613, 2593, 599, 1436, 2587, 2882, 1427, 1493, 2256, 2259, 1038, 1049, 1108, 1109, 2255, 2258, 1448, 1417, 1490],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 1, 2, 3, 4, 5, 6], [7, 1, 1, 2, 3, 4, 5, 6], [8, 1, 1, 2, 3, 4, 5, 6], [0, 1, 1, 2, 3, 4, 5, 6], [7, 1, 1, 2, 3, 4, 5, 6], [8, 1, 1, 2, 3, 4, 5, 6], [0, 1, 1, 2, 3, 4, 5, 6], [7, 1, 1, 2, 3, 4, 5, 6], [8, 1, 1, 2, 3, 4, 5, 6], [0, 1, 1, 2, 3, 4, 5, 6], [7, 1, 1, 2, 3, 4, 5, 6], [8, 1, 1, 2, 3, 4, 5, 6], [9, 1, 10, 11, 3, 12, 5, 6], [13, 1, 10, 11, 3, 12, 5, 6], [14, 1, 10, 11, 3, 12, 5, 6], [15, 1, 10, 16, 17, 18, 5, 6],
    [19, 1, 10, 16, 17, 18, 5, 6], [20, 1, 10, 16, 17, 18, 5, 6], [15, 1, 10, 16, 17, 18, 5, 6], [19, 1, 10, 16, 17, 18, 5, 6], [20, 1, 10, 16, 17, 18, 5, 6], [15, 1, 10, 16, 17, 18, 5, 6], [19, 1, 10, 16, 17, 18, 5, 6], [20, 1, 10, 16, 17, 18, 5, 6],
  ];
}
