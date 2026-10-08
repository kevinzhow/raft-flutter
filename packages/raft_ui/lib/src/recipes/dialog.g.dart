// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `dialog`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `dialog` (default `md`).
enum RaftDialogRecipeSize {
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftDialogRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `layer` axis of `dialog`.
enum RaftDialogRecipeLayer {
  v0('0'),
  v1('1');

  const RaftDialogRecipeLayer(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftDialogRecipe].
class RaftDialogRecipeStyle {
  const RaftDialogRecipeStyle({required this.overlay, required this.content, required this.header, required this.body, required this.footer, required this.title, required this.description});

  /// Slot `overlay`.
  final RaftSlotStyle overlay;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `body`.
  final RaftSlotStyle body;
  /// Slot `footer`.
  final RaftSlotStyle footer;
  /// Slot `title`.
  final RaftSlotStyle title;
  /// Slot `description`.
  final RaftSlotStyle description;

  Map<String, RaftSlotStyle> get slots => {'overlay': overlay, 'content': content, 'header': header, 'body': body, 'footer': footer, 'title': title, 'description': description};
}

/// raft-ui recipe `dialog` (`src/components/dialog/dialog.tsx`, index.mjs:839).
///
/// Used by: DialogBody, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogOverlay, DialogTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDialogRecipe {
  static const String recipeName = 'dialog';
  static const List<String> slotNames = ['overlay', 'content', 'header', 'body', 'footer', 'title', 'description'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'md', false),
    RaftRecipeAxis('layer', ['0', '1'], null, true),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftDialogRecipeStyle resolve({RaftDialogRecipeSize? size, RaftDialogRecipeLayer? layer, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [size?.css, layer?.css, theme.name], states, tokens);
    return RaftDialogRecipeStyle(overlay: s[0], content: s[1], header: s[2], body: s[3], footer: s[4], title: s[5], description: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1619, 2303, 3142, 3085, 1602, 1613, 1566, 1464, 819],
    [1619, 3039, 2352, 3142, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2488, 1701, 866, 900, 825, 2757, 2769, 2864],
    [1717, 2867, 1724, 2312, 1700, 2574],
    [2574, 1621, 2661, 2765, 1688],
    [1620, 2867, 2312, 2318, 1700],
    [2359, 2574, 2976, 1687, 3004, 2344, 1684, 3096],
    [2359, 1691, 3017, 2335, 2993],
    [1619, 2303, 3142, 3085, 1602, 1613, 1566, 1464, 819, 679],
    [1619, 3039, 2352, 3142, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2488, 2655, 2817, 828, 2864],
    [1717, 2867, 1724, 2312, 1700, 2574, 2757, 2767],
    [2574, 1621, 2661, 2757, 2770, 1130],
    [1620, 2867, 2312, 2318, 1700, 2757, 2767],
    [2359, 2574, 2976, 1691, 2955, 2337, 1684, 3096, 3049],
    [2359, 1691, 3017, 2335, 2977],
    [1619, 2303, 3085, 1602, 1613, 1566, 1464, 3143, 819],
    [1619, 3039, 2352, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2488, 3143, 1701, 866, 900, 825, 2757, 2769, 2864],
    [1619, 2303, 3085, 1602, 1613, 1566, 1464, 3143, 819, 679],
    [1619, 3039, 2352, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2488, 3143, 2655, 2817, 828, 2864],
    [1619, 3039, 2352, 3142, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2486, 1701, 866, 900, 825, 2757, 2769, 2864],
    [1619, 3039, 2352, 3142, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2486, 2655, 2817, 828, 2864],
    [1619, 3039, 2352, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2486, 3143, 1701, 866, 900, 825, 2757, 2769, 2864],
    [1619, 3039, 2352, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2486, 3143, 2655, 2817, 828, 2864],
    [1619, 3039, 2352, 3142, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2485, 1701, 866, 900, 825, 2757, 2769, 2864],
    [1619, 3039, 2352, 3142, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2485, 2655, 2817, 828, 2864],
    [1619, 3039, 2352, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2485, 3143, 1701, 866, 900, 825, 2757, 2769, 2864],
    [1619, 3039, 2352, 1620, 3120, 152, 1622, 2369, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2485, 3143, 2655, 2817, 828, 2864],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [7, 8, 9, 10, 11, 12, 13], [0, 1, 2, 3, 4, 5, 6], [7, 8, 9, 10, 11, 12, 13], [14, 15, 2, 3, 4, 5, 6], [16, 17, 9, 10, 11, 12, 13], [0, 18, 2, 3, 4, 5, 6], [7, 19, 9, 10, 11, 12, 13], [0, 18, 2, 3, 4, 5, 6], [7, 19, 9, 10, 11, 12, 13], [14, 20, 2, 3, 4, 5, 6], [16, 21, 9, 10, 11, 12, 13], [0, 22, 2, 3, 4, 5, 6], [7, 23, 9, 10, 11, 12, 13], [0, 22, 2, 3, 4, 5, 6], [7, 23, 9, 10, 11, 12, 13],
    [14, 24, 2, 3, 4, 5, 6], [16, 25, 9, 10, 11, 12, 13],
  ];
}
