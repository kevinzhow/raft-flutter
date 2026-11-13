// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `kbd`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `kbd` (default `sm`).
enum RaftKbdRecipeSize {
  sm('sm'),
  md('md');

  const RaftKbdRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftKbdRecipe].
class RaftKbdRecipeStyle {
  const RaftKbdRecipeStyle({required this.root, required this.group});

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `group`.
  final RaftSlotStyle group;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'group': group};
}

/// raft-ui recipe `kbd` (`dist/components/kbd/kbd.mjs`, index.mjs:5544).
///
/// Used by: Kbd, KbdGroup.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftKbdRecipe {
  static const String recipeName = 'kbd';
  static const List<String> slotNames = ['root', 'group'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['sm', 'md'], 'sm', false),
  ];

  static RaftKbdRecipeStyle resolve({
    RaftKbdRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftKbdRecipeStyle(root: s[0], group: s[1]);
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
      2346,
      1847,
      2724,
      2499,
      1864,
      1869,
      1464,
      2729,
      2483,
      472,
      1454,
      1455,
      1851,
      1854,
      458,
      2119,
      2458,
      2399,
      2616,
      2600,
      1807,
      1806,
    ],
    [1847, 1864, 1464],
    [
      2346,
      1847,
      2724,
      2499,
      1864,
      1869,
      1464,
      2729,
      2483,
      472,
      1454,
      1455,
      1851,
      1854,
      459,
      1658,
      2124,
      2471,
      2400,
      2615,
      2603,
      895,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1],
    [2, 1],
  ];
}
