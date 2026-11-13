// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `pullToRefreshIndicator`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `platform` axis of `pullToRefreshIndicator` (default `default`).
enum RaftPullToRefreshIndicatorRecipePlatform {
  default_('default'),
  android('android');

  const RaftPullToRefreshIndicatorRecipePlatform(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftPullToRefreshIndicatorRecipe].
class RaftPullToRefreshIndicatorRecipeStyle {
  const RaftPullToRefreshIndicatorRecipeStyle({
    required this.root,
    required this.surface,
    required this.spinner,
    required this.status,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `surface`.
  final RaftSlotStyle surface;

  /// Slot `spinner`.
  final RaftSlotStyle spinner;

  /// Slot `status`.
  final RaftSlotStyle status;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'surface': surface,
    'spinner': spinner,
    'status': status,
  };
}

/// raft-ui recipe `pullToRefreshIndicator` (`dist/components/pull-to-refresh/pull-to-refresh-indicator.mjs`, index.mjs:28687).
///
/// Used by: PullToRefreshIndicator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPullToRefreshIndicatorRecipe {
  static const String recipeName = 'pullToRefreshIndicator';
  static const List<String> slotNames = [
    'root',
    'surface',
    'spinner',
    'status',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('platform', ['default', 'android'], 'default', false),
  ];

  static RaftPullToRefreshIndicatorRecipeStyle resolve({
    RaftPullToRefreshIndicatorRecipePlatform? platform,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [platform?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftPullToRefreshIndicatorRecipeStyle(
      root: s[0],
      surface: s[1],
      spinner: s[2],
      status: s[3],
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
      1400,
      2725,
      2499,
      1869,
      2603,
      2433,
      1864,
      2252,
      2668,
      1371,
      1377,
      2138,
      1111,
    ],
    [1400, 1864, 1869, 2538],
    [2676, 1371, 1377, 2138, 1810, 1809, 1808],
    [2539],
    [1400, 2725, 2499, 1869, 2603, 2545, 2640, 2748, 1644, 2253],
    [
      1400,
      1864,
      1869,
      691,
      1858,
      2640,
      2156,
      2509,
      2466,
      915,
      2496,
      2680,
      2672,
      1371,
      1377,
      2138,
      1111,
      1110,
      1025,
      1023,
      1024,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 5, 2, 3],
  ];
}
