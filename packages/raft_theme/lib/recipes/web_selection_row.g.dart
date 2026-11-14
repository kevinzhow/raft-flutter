// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `webSelectionRow`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftWebSelectionRowRecipe].
class RaftWebSelectionRowRecipeStyle {
  const RaftWebSelectionRowRecipeStyle({
    required this.root,
    required this.leading,
    required this.label,
    required this.indicator,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `leading`.
  final RaftSlotStyle leading;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'leading': leading,
    'label': label,
    'indicator': indicator,
  };
}

/// raft-ui recipe `webSelectionRow` (`Web src/components/ui/SelectionPopover.tsx sha256:70e0c0cd94cd4c04e8affb90ed7f5e8648870d49d6ce5293b0595876bc296fca`, index.mjs:1).
///
/// Used by: SelectionPopoverOptionRow.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftWebSelectionRowRecipe {
  static const String recipeName = 'webSelectionRow';
  static const List<String> slotNames = [
    'root',
    'leading',
    'label',
    'indicator',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('checked', ['true', 'false'], 'false', false),
    RaftRecipeAxis('disabled', ['true', 'false'], 'false', false),
    RaftRecipeAxis('italic', ['true', 'false'], 'false', false),
  ];

  static RaftWebSelectionRowRecipeStyle resolve({
    bool? checked,
    bool? disabled,
    bool? italic,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [checked?.toString(), disabled?.toString(), italic?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftWebSelectionRowRecipeStyle(
      root: s[0],
      leading: s[1],
      label: s[2],
      indicator: s[3],
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
      1636,
      2725,
      1864,
      1868,
      1466,
      2252,
      2461,
      2402,
      2613,
      2587,
      2247,
      996,
      2599,
    ],
    [1400, 2519, 2499, 1864, 1869],
    [2729, 2603],
    [2499, 2598, 2525],
    [2681],
    [
      1400,
      1636,
      2725,
      1864,
      1868,
      1466,
      2252,
      2461,
      2402,
      2613,
      2587,
      2247,
      2598,
      1783,
      1415,
      1449,
    ],
    [
      1400,
      1636,
      2725,
      1864,
      1868,
      1466,
      2252,
      2461,
      2402,
      2613,
      2587,
      2247,
      2598,
      1783,
      1415,
      1453,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [0, 1, 4, 3],
    [5, 1, 2, 3],
    [5, 1, 4, 3],
    [0, 1, 2, 3],
    [0, 1, 4, 3],
    [6, 1, 2, 3],
    [6, 1, 4, 3],
  ];
}
