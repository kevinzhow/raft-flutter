// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `files`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftFilesRecipe].
class RaftFilesRecipeStyle {
  const RaftFilesRecipeStyle({
    required this.panel,
    required this.viewport,
    required this.list,
    required this.row,
    required this.rowOpen,
    required this.thumbnail,
    required this.image,
    required this.content,
    required this.name_,
    required this.meta,
    required this.metaItem,
    required this.actions,
  });

  /// Slot `panel`.
  final RaftSlotStyle panel;

  /// Slot `viewport`.
  final RaftSlotStyle viewport;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `rowOpen`.
  final RaftSlotStyle rowOpen;

  /// Slot `thumbnail`.
  final RaftSlotStyle thumbnail;

  /// Slot `image`.
  final RaftSlotStyle image;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `name`.
  final RaftSlotStyle name_;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `metaItem`.
  final RaftSlotStyle metaItem;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  Map<String, RaftSlotStyle> get slots => {
    'panel': panel,
    'viewport': viewport,
    'list': list,
    'row': row,
    'rowOpen': rowOpen,
    'thumbnail': thumbnail,
    'image': image,
    'content': content,
    'name': name_,
    'meta': meta,
    'metaItem': metaItem,
    'actions': actions,
  };
}

/// raft-ui recipe `files` (`dist/components/files/files.recipe.mjs`, index.mjs:16562).
///
/// Used by: FileActions, FileContent, FileImage, FileMeta, FileMetaItem, FileName, FileRow, FileRowOpen, FileThumbnail, FilesList, FilesPanel, FilesViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftFilesRecipe {
  static const String recipeName = 'files';
  static const List<String> slotNames = [
    'panel',
    'viewport',
    'list',
    'row',
    'rowOpen',
    'thumbnail',
    'image',
    'content',
    'name',
    'meta',
    'metaItem',
    'actions',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftFilesRecipeStyle resolve({
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
    return RaftFilesRecipeStyle(
      panel: s[0],
      viewport: s[1],
      list: s[2],
      row: s[3],
      rowOpen: s[4],
      thumbnail: s[5],
      image: s[6],
      content: s[7],
      name_: s[8],
      meta: s[9],
      metaItem: s[10],
      actions: s[11],
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
    [1400, 2098, 1401, 1404, 910, 2598],
    [2098, 1401],
    [1400, 1404, 1466, 2396, 2419, 1945],
    [
      1606,
      1400,
      2725,
      2116,
      1468,
      2403,
      2675,
      1864,
      2462,
      939,
      953,
      911,
      2418,
      2356,
      2299,
      2497,
      604,
      1713,
      1771,
      1714,
    ],
    [1400, 2116, 1401, 1468, 2613, 1431, 1433, 1864, 2247, 1432],
    [
      1400,
      2499,
      1864,
      1869,
      2252,
      479,
      474,
      1738,
      1737,
      1736,
      2523,
      2461,
      940,
      895,
      2603,
      1712,
    ],
    [937, 2538, 1026, 1027, 911],
    [1400, 2116, 1401, 1404, 1869, 1463],
    [937, 2681, 1456, 2587, 1457, 2598],
    [1400, 2116, 1408, 1864, 1486, 2143, 1478, 1454, 2616, 2600],
    [1847, 1864, 1464, 476, 474],
    [1400, 2499, 2487, 1864, 1465],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
