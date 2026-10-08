// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `alertDialog`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftAlertDialogRecipe].
class RaftAlertDialogRecipeStyle {
  const RaftAlertDialogRecipeStyle({required this.overlay, required this.content, required this.header, required this.body, required this.footer, required this.title, required this.description});

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

/// raft-ui recipe `alertDialog` (`src/components/alert-dialog/alert-dialog.tsx`, index.mjs:682).
///
/// Used by: AlertDialogBody, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogOverlay, AlertDialogTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAlertDialogRecipe {
  static const String recipeName = 'alertDialog';
  static const List<String> slotNames = ['overlay', 'content', 'header', 'body', 'footer', 'title', 'description'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftAlertDialogRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftAlertDialogRecipeStyle(overlay: s[0], content: s[1], header: s[2], body: s[3], footer: s[4], title: s[5], description: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1619, 2303, 3142, 3085, 1602, 1613, 1566, 1464, 819],
    [1619, 3039, 2352, 3142, 1717, 3120, 2475, 152, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 1701, 866, 900, 825, 2757, 2769, 2864],
    [1717, 1724, 2312, 1700, 2574],
    [2574, 2765, 1688],
    [1620, 2312, 2318, 1700],
    [2359, 2574, 2976, 1687, 3004, 2344, 1684, 3096],
    [2359, 1691, 3017, 2335, 2993],
    [1619, 2303, 3142, 3085, 1602, 1613, 1566, 1464, 819, 679],
    [1619, 3039, 2352, 3142, 1717, 3120, 2475, 152, 2641, 3060, 2649, 3078, 1602, 1613, 1567, 1566, 1464, 2655, 2817, 828, 2864],
    [1717, 1724, 2312, 1700, 2574, 873, 898, 824, 2756, 2767, 1009, 1002],
    [2574, 2757, 2770, 1130],
    [1620, 2312, 2318, 1700, 911, 898, 824, 2756, 2767, 1009, 1002],
    [2359, 2574, 2976, 1691, 3017, 2335, 1688, 3046],
    [2359, 1691, 3017, 2335, 2977],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [7, 8, 9, 10, 11, 12, 13],
  ];
}
