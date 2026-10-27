// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `formSection`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftFormSectionRecipe].
class RaftFormSectionRecipeStyle {
  const RaftFormSectionRecipeStyle({
    required this.root,
    required this.head,
    required this.titleRow,
    required this.title,
    required this.description,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `head`.
  final RaftSlotStyle head;

  /// Slot `titleRow`.
  final RaftSlotStyle titleRow;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `description`.
  final RaftSlotStyle description;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'head': head,
    'titleRow': titleRow,
    'title': title,
    'description': description,
  };
}

/// raft-ui recipe `formSection` (`src/components/form-section/form-section.tsx`, index.mjs:1248).
///
/// Used by: FormSection.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftFormSectionRecipe {
  static const String recipeName = 'formSection';
  static const List<String> slotNames = [
    'root',
    'head',
    'titleRow',
    'title',
    'description',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftFormSectionRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftFormSectionRecipeStyle(
      root: s[0],
      head: s[1],
      titleRow: s[2],
      title: s[3],
      description: s[4],
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
    [965, 967, 1025, 1673, 959, 403, 402],
    [965, 1483, 967, 1020],
    [965, 1483, 1319, 1023],
    [1357, 1483, 966, 1016, 1819, 1008, 1825],
    [1357, 1016, 1819, 1822],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
  ];
}
