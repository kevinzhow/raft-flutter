// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `files`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `files` (`src/components/files/files.recipe.ts`, index.mjs:13164).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftFilesRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
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
    [1644, 2583, 1645, 1646, 868],
    [2583, 1645, 2684],
    [1644, 1646, 1723, 2784, 2796],
    [
      1922,
      1644,
      3168,
      2597,
      2333,
      1725,
      878,
      2781,
      2796,
      3125,
      896,
      868,
      2260,
      2288,
    ],
    [1644, 2597, 1645, 2334, 1725, 3040, 1663, 1672, 1671, 1666],
    [
      1644,
      2909,
      2902,
      2331,
      2336,
      2679,
      878,
      430,
      425,
      2082,
      2152,
      2151,
      2150,
      892,
      868,
      2994,
    ],
    [874, 2925, 868, 1244, 1245],
    [1644, 2597, 1645, 1646],
    [874, 3133, 3053, 1709, 2994],
    [2628, 1644, 2597, 1650, 2331, 1732, 1739, 1714, 3073, 2998],
    [2320, 2331, 1721, 427, 425],
    [1644, 2902, 2870, 2331, 1722],
    [1644, 2583, 1645, 1646, 830, 1022],
    [1644, 1646, 1724, 2784, 2798],
    [
      1922,
      1644,
      3168,
      2597,
      2333,
      1725,
      3125,
      2847,
      879,
      912,
      830,
      2781,
      2796,
      2899,
      2204,
      1113,
      1029,
    ],
    [
      1644,
      2597,
      1645,
      2334,
      1725,
      3040,
      1663,
      1672,
      1671,
      1673,
      1677,
      1690,
      1686,
      1688,
    ],
    [
      1644,
      2909,
      2902,
      2331,
      2336,
      2679,
      430,
      425,
      2082,
      2152,
      2151,
      2150,
      2848,
      876,
      912,
      801,
      3015,
    ],
    [874, 2925, 1244, 1245, 830],
    [874, 3133, 3053, 1716, 1713, 3013],
    [2628, 1644, 2597, 1650, 2331, 1732, 1739, 3073, 1716, 3021],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [12, 1, 13, 14, 15, 16, 17, 7, 18, 19, 10, 11],
  ];
}
