// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `files`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftFilesRecipe].
class RaftFilesRecipeStyle {
  const RaftFilesRecipeStyle({required this.panel, required this.viewport, required this.list, required this.row, required this.rowOpen, required this.thumbnail, required this.image, required this.content, required this.name_, required this.meta, required this.metaItem, required this.actions});

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

  Map<String, RaftSlotStyle> get slots => {'panel': panel, 'viewport': viewport, 'list': list, 'row': row, 'rowOpen': rowOpen, 'thumbnail': thumbnail, 'image': image, 'content': content, 'name': name_, 'meta': meta, 'metaItem': metaItem, 'actions': actions};
}

/// raft-ui recipe `files` (`src/components/files/files.recipe.ts`, index.mjs:12943).
///
/// Used by: FileActions, FileContent, FileImage, FileMeta, FileMetaItem, FileName, FileRow, FileRowOpen, FileThumbnail, FilesList, FilesPanel, FilesViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftFilesRecipe {
  static const String recipeName = 'files';
  static const List<String> slotNames = ['panel', 'viewport', 'list', 'row', 'rowOpen', 'thumbnail', 'image', 'content', 'name', 'meta', 'metaItem', 'actions'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftFilesRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftFilesRecipeStyle(panel: s[0], viewport: s[1], list: s[2], row: s[3], rowOpen: s[4], thumbnail: s[5], image: s[6], content: s[7], name_: s[8], meta: s[9], metaItem: s[10], actions: s[11]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2560, 1621, 1622, 856],
    [2560, 1621, 2661],
    [1620, 1622, 1698, 2756, 2767],
    [1921, 1620, 3127, 2574, 2314, 1700, 866, 2753, 2767, 3084, 880, 856, 2241, 2269],
    [1620, 2574, 1621, 2315, 1700, 3003, 1639, 1648, 1647, 1642],
    [1620, 2874, 2867, 2312, 2317, 2656, 866, 432, 427, 2076, 2141, 2140, 2139, 876, 856, 2956],
    [862, 2890, 856, 1225, 1226],
    [1620, 2574, 1621, 1622],
    [862, 3092, 3017, 1684, 2956],
    [2605, 1620, 2574, 1626, 2312, 1707, 1714, 1689, 3032, 2961],
    [2301, 2312, 1696, 429, 427],
    [1620, 2867, 2836, 2312, 1697],
    [1620, 2560, 1621, 1622, 825, 1002],
    [1620, 1622, 1699, 2756, 2769],
    [1921, 1620, 3127, 2574, 2314, 1700, 3084, 2817, 867, 896, 825, 2753, 2767, 2865, 2185, 1093, 1009],
    [1620, 2574, 1621, 2315, 1700, 3003, 1639, 1648, 1647, 1649, 1653, 1666, 1662, 1664],
    [1620, 2874, 2867, 2312, 2317, 2656, 432, 427, 2076, 2141, 2140, 2139, 2818, 864, 896, 795, 2978],
    [862, 2890, 1225, 1226, 825],
    [862, 3092, 3017, 1691, 1688, 2976],
    [2605, 1620, 2574, 1626, 2312, 1707, 1714, 3032, 1691, 2984],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [12, 1, 13, 14, 15, 16, 17, 7, 18, 19, 10, 11],
  ];
}
