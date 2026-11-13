// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `iconTile`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `iconTile` (default `default`).
enum RaftIconTileRecipeVariant {
  default_('default'),
  warning('warning'),
  information('information');

  const RaftIconTileRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `iconTile` (default `md`).
enum RaftIconTileRecipeSize {
  xs('xs'),
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftIconTileRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftIconTileRecipe].
class RaftIconTileRecipeStyle {
  const RaftIconTileRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `iconTile` (`dist/components/icon-tile/icon-tile.mjs`, index.mjs:15074).
///
/// Used by: IconTile.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftIconTileRecipe {
  static const String recipeName = 'iconTile';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'variant',
      ['default', 'warning', 'information'],
      'default',
      false,
    ),
    RaftRecipeAxis('size', ['xs', 'sm', 'md', 'lg'], 'md', false),
  ];

  static RaftIconTileRecipeStyle resolve({
    RaftIconTileRecipeVariant? variant,
    RaftIconTileRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftIconTileRecipeStyle(root: s[0]);
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
    [1847, 2499, 1864, 1869, 2471, 474, 895, 2603, 2527, 463],
    [1847, 2499, 1864, 1869, 474, 895, 2603, 2528, 2461, 459],
    [1847, 2499, 1864, 1869, 474, 895, 2603, 2529, 2463, 464],
    [1847, 2499, 1864, 1869, 474, 895, 2603, 2530, 2462, 465],
    [1847, 2499, 1864, 1869, 2471, 474, 935, 2598, 2527, 463],
    [1847, 2499, 1864, 1869, 474, 935, 2598, 2528, 2461, 459],
    [1847, 2499, 1864, 1869, 474, 935, 2598, 2529, 2463, 464],
    [1847, 2499, 1864, 1869, 474, 935, 2598, 2530, 2462, 465],
    [1847, 2499, 1864, 1869, 2471, 474, 907, 2598, 2527, 463],
    [1847, 2499, 1864, 1869, 474, 907, 2598, 2528, 2461, 459],
    [1847, 2499, 1864, 1869, 474, 907, 2598, 2529, 2463, 464],
    [1847, 2499, 1864, 1869, 474, 907, 2598, 2530, 2462, 465],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
    [2],
    [3],
    [4],
    [5],
    [6],
    [7],
    [8],
    [9],
    [10],
    [11],
  ];
}
