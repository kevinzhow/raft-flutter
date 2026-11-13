// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `buttonSplitMenu`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `buttonSplitMenu` (default `default`).
enum RaftButtonSplitMenuRecipeVariant {
  primary('primary'),
  warning('warning'),
  danger('danger'),
  default_('default');

  const RaftButtonSplitMenuRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `buttonSplitMenu` (default `md`).
enum RaftButtonSplitMenuRecipeSize {
  md('md'),
  lg('lg');

  const RaftButtonSplitMenuRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftButtonSplitMenuRecipe].
class RaftButtonSplitMenuRecipeStyle {
  const RaftButtonSplitMenuRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `buttonSplitMenu` (`dist/components/button/button-split.mjs`, index.mjs:9142).
///
/// Used by: ButtonSplitMenu.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftButtonSplitMenuRecipe {
  static const String recipeName = 'buttonSplitMenu';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'variant',
      ['primary', 'warning', 'danger', 'default'],
      'default',
      false,
    ),
    RaftRecipeAxis('size', ['md', 'lg'], 'md', false),
  ];

  static RaftButtonSplitMenuRecipeStyle resolve({
    RaftButtonSplitMenuRecipeVariant? variant,
    RaftButtonSplitMenuRecipeSize? size,
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
    return RaftButtonSplitMenuRecipeStyle(base: s[0]);
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
    [2116, 2469, 2397, 2444, 1442, 737, 1281, 2707, 709],
    [2116, 2469, 2397, 2444, 1442, 737, 1281, 2710, 2086, 708, 2027],
    [2116, 2469, 2397, 2444, 1442, 737, 1280, 2707, 709],
    [2116, 2469, 2397, 2444, 1442, 737, 1280, 2710, 2086, 708, 2027],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
    [0],
    [1],
    [0],
    [1],
    [2],
    [3],
  ];
}
