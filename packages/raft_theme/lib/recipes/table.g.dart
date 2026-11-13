// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `table`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `align` axis of `table`.
enum RaftTableRecipeAlign {
  left('left'),
  right('right');

  const RaftTableRecipeAlign(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

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
    required this.sortableHead,
    required this.sortButton,
    required this.headSortButton,
    required this.sortArrow,
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

  /// Slot `sortableHead`.
  final RaftSlotStyle sortableHead;

  /// Slot `sortButton`.
  final RaftSlotStyle sortButton;

  /// Slot `headSortButton`.
  final RaftSlotStyle headSortButton;

  /// Slot `sortArrow`.
  final RaftSlotStyle sortArrow;

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
    'sortableHead': sortableHead,
    'sortButton': sortButton,
    'headSortButton': headSortButton,
    'sortArrow': sortArrow,
  };
}

/// raft-ui recipe `table` (`dist/components/table/table.recipe.mjs`, index.mjs:15594).
///
/// Used by: Table, TableBody, TableCaption, TableCell, TableColgroup, TableColumn, TableHead, TableHeader, TableRow, TableSortButton, TableSortableHead.
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
    'sortableHead',
    'sortButton',
    'headSortButton',
    'sortArrow',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('align', ['left', 'right'], null, true),
    RaftRecipeAxis('sorted', ['true', 'false'], null, true),
  ];

  static RaftTableRecipeStyle resolve({
    RaftTableRecipeAlign? align,
    bool? sorted,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [align?.css, sorted?.toString()],
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
      sortableHead: s[9],
      sortButton: s[10],
      headSortButton: s[11],
      sortArrow: s[12],
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
    [2725, 943, 978, 1456, 2587, 2598],
    [],
    [367, 368, 370, 369],
    [2166, 2167, 794, 795, 793, 1069, 1073, 1063],
    [2613, 2729, 942, 953, 2403, 2417, 2597, 1449, 2165, 2654, 2600],
    [762, 2733, 942, 953, 2403, 2417],
    [2381, 2588, 2600],
    [2260],
    [
      2433,
      1400,
      1678,
      2725,
      1864,
      1464,
      940,
      933,
      680,
      997,
      2471,
      1798,
      2247,
      1439,
      2326,
      2329,
      2327,
      2328,
      2325,
      2600,
    ],
    [
      2433,
      1400,
      2725,
      1864,
      1464,
      940,
      933,
      2403,
      2417,
      680,
      997,
      2471,
      1798,
      2247,
      1439,
      2326,
      2329,
      2327,
      2328,
      2325,
      2600,
    ],
    [2515, 2499],
    [
      2433,
      1400,
      1678,
      2725,
      1864,
      1464,
      940,
      933,
      680,
      997,
      2471,
      1798,
      2247,
      1439,
      2326,
      2329,
      2327,
      2328,
      2325,
      2598,
    ],
    [
      2433,
      1400,
      2725,
      1864,
      1464,
      940,
      933,
      2403,
      2417,
      680,
      997,
      2471,
      1798,
      2247,
      1439,
      2326,
      2329,
      2327,
      2328,
      2325,
      2598,
    ],
    [2729, 942, 953, 2403, 2417, 2597, 1449, 2165, 2654, 2600, 2618],
    [762, 2733, 942, 953, 2403, 2417, 2618],
    [
      2433,
      1400,
      1678,
      2725,
      1864,
      1464,
      940,
      933,
      680,
      997,
      2471,
      1798,
      2247,
      1439,
      2326,
      2329,
      2327,
      2328,
      2325,
      1870,
      2600,
    ],
    [
      2433,
      1400,
      2725,
      1864,
      1464,
      940,
      933,
      2403,
      2417,
      680,
      997,
      2471,
      1798,
      2247,
      1439,
      2326,
      2329,
      2327,
      2328,
      2325,
      1870,
      2600,
    ],
    [
      2433,
      1400,
      1678,
      2725,
      1864,
      1464,
      940,
      933,
      680,
      997,
      2471,
      1798,
      2247,
      1439,
      2326,
      2329,
      2327,
      2328,
      2325,
      1870,
      2598,
    ],
    [
      2433,
      1400,
      2725,
      1864,
      1464,
      940,
      933,
      2403,
      2417,
      680,
      997,
      2471,
      1798,
      2247,
      1439,
      2326,
      2329,
      2327,
      2328,
      2325,
      1870,
      2598,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 1, 1, 6, 7, 8, 9, 10],
    [0, 1, 2, 3, 4, 5, 1, 1, 6, 7, 11, 12, 10],
    [0, 1, 2, 3, 4, 5, 1, 1, 6, 7, 8, 9, 10],
    [0, 1, 2, 3, 4, 5, 1, 1, 6, 7, 8, 9, 10],
    [0, 1, 2, 3, 4, 5, 1, 1, 6, 7, 11, 12, 10],
    [0, 1, 2, 3, 4, 5, 1, 1, 6, 7, 8, 9, 10],
    [0, 1, 2, 3, 13, 14, 1, 1, 6, 7, 15, 16, 10],
    [0, 1, 2, 3, 13, 14, 1, 1, 6, 7, 17, 18, 10],
    [0, 1, 2, 3, 13, 14, 1, 1, 6, 7, 15, 16, 10],
  ];
}
