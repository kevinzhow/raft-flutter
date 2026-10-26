// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `checkboxIndicator`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `shape` axis of `checkboxIndicator` (default `square`).
enum RaftCheckboxIndicatorRecipeShape {
  square('square'),
  circle('circle');

  const RaftCheckboxIndicatorRecipeShape(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftCheckboxIndicatorRecipe].
class RaftCheckboxIndicatorRecipeStyle {
  const RaftCheckboxIndicatorRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `checkboxIndicator` (`src/components/checkbox/checkbox-indicator.tsx`, index.mjs:2444).
///
/// Used by: CheckboxIndicator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCheckboxIndicatorRecipe {
  static const String recipeName = 'checkboxIndicator';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('shape', ['square', 'circle'], 'square', false),
    RaftRecipeAxis('checked', ['true', 'false'], null, true),
    RaftRecipeAxis('disabled', ['true', 'false'], 'false', false),
    RaftRecipeAxis('previewOnHover', ['true', 'false'], 'false', false),
  ];

  static RaftCheckboxIndicatorRecipeStyle resolve({
    RaftCheckboxIndicatorRecipeShape? shape,
    bool? checked,
    bool? disabled,
    bool? previewOnHover,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [
        shape?.css,
        checked?.toString(),
        disabled?.toString(),
        previewOnHover?.toString(),
      ],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftCheckboxIndicatorRecipeStyle(root: s[0]);
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
      1304,
      1750,
      1736,
      1318,
      1323,
      1712,
      622,
      1889,
      277,
      264,
      292,
      1850,
      628,
      581,
      1131,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      1712,
      622,
      1889,
      277,
      264,
      292,
      1850,
      628,
      581,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      1712,
      622,
      635,
      1889,
      277,
      264,
      292,
      596,
      1850,
      1131,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      1712,
      622,
      635,
      1889,
      277,
      264,
      292,
      596,
      1850,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      1712,
      622,
      1889,
      277,
      264,
      292,
      628,
      583,
      1831,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      1712,
      622,
      1889,
      277,
      264,
      292,
      627,
      582,
      1821,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      622,
      1889,
      277,
      264,
      292,
      1708,
      1850,
      628,
      581,
      1131,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      622,
      1889,
      277,
      264,
      292,
      1708,
      1850,
      628,
      581,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      622,
      635,
      1889,
      277,
      264,
      292,
      1708,
      596,
      1850,
      1131,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      622,
      635,
      1889,
      277,
      264,
      292,
      1708,
      596,
      1850,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      622,
      1889,
      277,
      264,
      292,
      1708,
      628,
      583,
      1831,
    ],
    [
      1304,
      1750,
      1736,
      1318,
      1323,
      622,
      1889,
      277,
      264,
      292,
      1708,
      627,
      582,
      1821,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
    [2],
    [3],
    [4],
    [4],
    [5],
    [5],
    [0],
    [1],
    [2],
    [3],
    [6],
    [7],
    [8],
    [9],
    [10],
    [10],
    [11],
    [11],
    [6],
    [7],
    [8],
    [9],
  ];
}
