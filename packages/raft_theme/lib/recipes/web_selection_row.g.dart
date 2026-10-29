// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `webSelectionRow`.
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

/// raft-ui recipe `webSelectionRow` (`Web src/components/ui/SelectionPopover.tsx sha256:8af0b00698de999e8ec3c1d79e9427e6aa1ccd7c1097cc4e5943ba3d9b1228c6`, index.mjs:1).
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
      965,
      1189,
      1929,
      1319,
      1323,
      1023,
      1583,
      1710,
      1659,
      1836,
      1813,
      1577,
      663,
      1823,
    ],
    [965, 1754, 1740, 1319, 1324],
    [1933, 1827],
    [1740, 1822, 1760],
    [1897],
    [
      965,
      1189,
      1929,
      1319,
      1323,
      1023,
      1583,
      1710,
      1659,
      1836,
      1813,
      1577,
      1822,
      1270,
      978,
      1008,
    ],
    [
      965,
      1189,
      1929,
      1319,
      1323,
      1023,
      1583,
      1710,
      1659,
      1836,
      1813,
      1577,
      1822,
      1270,
      978,
      1013,
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
