// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `field`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `field` (`dist/components/field/field.mjs`, index.mjs:7536).
///
/// Used by: Field, FieldDescription, FieldError, FieldItem, FieldLabel.
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
    RaftRecipeAxis('size', ['sm', 'md'], 'md', false),
  ];

  static RaftFieldRecipeStyle resolve({
    RaftFieldRecipeSize? size,
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
    [1604, 1400, 1404, 1465],
    [1605, 1400, 1866, 1466, 155, 102, 126, 141, 2588],
    [937, 2733, 1560, 1456, 2603, 2588, 1457],
    [2733, 1560, 2588, 2600],
    [2733, 1560, 2588, 1457, 2594],
    [1605, 1400, 1866, 1466, 155, 102, 126, 141, 2597],
    [937, 2733, 1560, 1456, 2603, 2597, 1457],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [0, 5, 6, 3, 4],
  ];
}
