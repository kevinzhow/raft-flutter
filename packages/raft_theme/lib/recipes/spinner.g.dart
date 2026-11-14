// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `spinner`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `spinner` (default `sm`).
enum RaftSpinnerRecipeSize {
  xs('xs'),
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftSpinnerRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `spinner`.
enum RaftSpinnerRecipeVariant {
  default_('default'),
  inverse('inverse');

  const RaftSpinnerRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftSpinnerRecipe].
class RaftSpinnerRecipeStyle {
  const RaftSpinnerRecipeStyle({
    required this.root,
    required this.ring,
    required this.pixel,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `ring`.
  final RaftSlotStyle ring;

  /// Slot `pixel`.
  final RaftSlotStyle pixel;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'ring': ring,
    'pixel': pixel,
  };
}

/// raft-ui recipe `spinner` (`dist/components/spinner/spinner.mjs`, index.mjs:363).
///
/// Used by: Spinner.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSpinnerRecipe {
  static const String recipeName = 'spinner';
  static const List<String> slotNames = ['root', 'ring', 'pixel'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['xs', 'sm', 'md', 'lg'], 'sm', false),
    RaftRecipeAxis('variant', ['default', 'inverse'], null, true),
  ];

  static RaftSpinnerRecipeStyle resolve({
    RaftSpinnerRecipeSize? size,
    RaftSpinnerRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSpinnerRecipeStyle(root: s[0], ring: s[1], pixel: s[2]);
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
    [2433, 1847, 2499, 1864, 1869, 1892, 2592, 581, 578],
    [2499, 1489, 2535, 1499, 1461],
    [937, 2504, 2456, 891, 2230],
    [2433, 1847, 2499, 1864, 1869, 1892, 581, 578, 2601],
    [2433, 1847, 2499, 1864, 1869, 1892, 2592, 582, 579],
    [2433, 1847, 2499, 1864, 1869, 1892, 582, 579, 2601],
    [2433, 1847, 2499, 1864, 1869, 1892, 2592, 583, 579],
    [2433, 1847, 2499, 1864, 1869, 1892, 583, 579, 2601],
    [2433, 1847, 2499, 1864, 1869, 1892, 2592, 584, 580],
    [2433, 1847, 2499, 1864, 1869, 1892, 584, 580, 2601],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [0, 1, 2],
    [3, 1, 2],
    [4, 1, 2],
    [4, 1, 2],
    [5, 1, 2],
    [6, 1, 2],
    [6, 1, 2],
    [7, 1, 2],
    [8, 1, 2],
    [8, 1, 2],
    [9, 1, 2],
  ];
}
