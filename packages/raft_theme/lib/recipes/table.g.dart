// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `table`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTableRecipe].
class RaftTableRecipeStyle {
  const RaftTableRecipeStyle({
    required this.root,
    required this.header,
    required this.body,
    required this.row,
    required this.head,
    required this.cell,
    required this.colgroup,
    required this.column,
    required this.caption,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `head`.
  final RaftSlotStyle head;

  /// Slot `cell`.
  final RaftSlotStyle cell;

  /// Slot `colgroup`.
  final RaftSlotStyle colgroup;

  /// Slot `column`.
  final RaftSlotStyle column;

  /// Slot `caption`.
  final RaftSlotStyle caption;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'body': body,
    'row': row,
    'head': head,
    'cell': cell,
    'colgroup': colgroup,
    'column': column,
    'caption': caption,
  };
}

/// raft-ui recipe `table` (`src/components/table/table.recipe.ts`, index.mjs:10665).
///
/// Used by: MarkdownTable, Table, TableBody, TableCaption, TableCell, TableColgroup, TableColumn, TableHead, TableHeader, TableRow.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTableRecipe {
  static const String recipeName = 'table';
  static const List<String> slotNames = [
    'root',
    'header',
    'body',
    'row',
    'head',
    'cell',
    'colgroup',
    'column',
    'caption',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftTableRecipeStyle resolve({
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
    return RaftTableRecipeStyle(
      root: s[0],
      header: s[1],
      body: s[2],
      row: s[3],
      head: s[4],
      cell: s[5],
      colgroup: s[6],
      column: s[7],
      caption: s[8],
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
    [1929, 624, 652, 1016, 1813, 1822],
    [],
    [196, 197, 195],
    [501, 502, 739, 744],
    [1836, 1933, 623, 633, 1660, 1671, 1821, 1008, 1529, 1873, 1824],
    [470, 1937, 623, 633, 1660, 1671],
    [1645, 1814, 1824],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 1, 1, 6],
  ];
}
