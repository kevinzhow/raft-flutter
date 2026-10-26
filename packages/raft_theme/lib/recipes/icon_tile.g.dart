// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `iconTile`.
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

/// raft-ui recipe `iconTile` (`src/components/icon-tile/icon-tile.tsx`, index.mjs:9928).
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
    [1304, 1736, 1318, 1323, 1712, 277, 581, 1823, 1758, 268],
    [1304, 1736, 1318, 1323, 1712, 277, 581, 1823, 1760, 264],
    [1304, 1736, 1318, 1323, 1712, 277, 581, 1823, 1761, 269],
    [1304, 1736, 1318, 1323, 1712, 277, 581, 1823, 1762, 270],
    [1304, 1736, 1318, 1323, 1712, 277, 617, 1818, 1758, 268],
    [1304, 1736, 1318, 1323, 1712, 277, 617, 1818, 1760, 264],
    [1304, 1736, 1318, 1323, 1712, 277, 617, 1818, 1761, 269],
    [1304, 1736, 1318, 1323, 1712, 277, 617, 1818, 1762, 270],
    [1304, 1736, 1318, 1323, 1712, 277, 593, 1818, 1758, 268],
    [1304, 1736, 1318, 1323, 1712, 277, 593, 1818, 1760, 264],
    [1304, 1736, 1318, 1323, 1712, 277, 593, 1818, 1761, 269],
    [1304, 1736, 1318, 1323, 1712, 277, 593, 1818, 1762, 270],
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
