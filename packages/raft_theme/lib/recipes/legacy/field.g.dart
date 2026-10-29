// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `field`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `field` (default `md`).
enum RaftFieldRecipeSize {
  sm('sm'),
  md('md');

  const RaftFieldRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftFieldRecipe].
class RaftFieldRecipeStyle {
  const RaftFieldRecipeStyle({
    required this.root,
    required this.item,
    required this.label,
    required this.description,
    required this.error,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `error`.
  final RaftSlotStyle error;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'item': item,
    'label': label,
    'description': description,
    'error': error,
  };
}

/// raft-ui recipe `field` (`src/components/field/field.tsx`, index.mjs:6341).
///
/// Used by: Field, FieldDescription, FieldError, FieldItem, FieldLabel, LegacyTaskPanelField.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftFieldRecipe {
  static const String recipeName = 'field';
  static const List<String> slotNames = [
    'root',
    'item',
    'label',
    'description',
    'error',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('size', ['sm', 'md'], 'md', false),
  ];

  static RaftFieldRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftFieldRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftFieldRecipeStyle(
      root: s[0],
      item: s[1],
      label: s[2],
      description: s[3],
      error: s[4],
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
    [1920, 1644, 1646, 1721],
    [1921, 1644, 2333, 1723, 97],
    [874, 1863, 1709, 3073, 3030],
    [3073, 2354, 1863, 3029],
    [3073, 2354, 1863, 3009],
    [874, 1863, 1709, 3013, 3053],
    [1920, 1644, 1646, 1722],
    [874, 1863, 1713, 3024, 1183, 3073],
    [2962, 3014, 1863],
    [1863, 2962, 3009],
    [874, 1863, 1713, 3024, 1183, 3053],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [0, 1, 5, 3, 4],
    [6, 1, 7, 8, 9],
    [6, 1, 10, 8, 9],
  ];
}
