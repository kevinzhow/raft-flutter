// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `alertDialog`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftAlertDialogRecipe].
class RaftAlertDialogRecipeStyle {
  const RaftAlertDialogRecipeStyle({
    required this.overlay,
    required this.content,
    required this.header,
    required this.body,
    required this.footer,
    required this.title,
    required this.description,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'overlay': overlay,
    'content': content,
    'header': header,
    'body': body,
    'footer': footer,
    'title': title,
    'description': description,
  };
}

/// raft-ui recipe `alertDialog` (`dist/components/alert-dialog/alert-dialog.mjs`, index.mjs:662).
///
/// Used by: AlertDialogBody, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogOverlay, AlertDialogTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAlertDialogRecipe {
  static const String recipeName = 'alertDialog';
  static const List<String> slotNames = [
    'overlay',
    'content',
    'header',
    'body',
    'footer',
    'title',
    'description',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('nested', ['false', 'true'], null, true),
  ];

  static RaftAlertDialogRecipeStyle resolve({
    bool? nested,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [nested?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftAlertDialogRecipeStyle(
      overlay: s[0],
      content: s[1],
      header: s[2],
      body: s[3],
      footer: s[4],
      title: s[5],
      description: s[6],
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
    [1399, 1849, 2741, 908],
    [
      1399,
      2642,
      1897,
      2741,
      1489,
      2717,
      190,
      2247,
      1954,
      2251,
      2464,
      915,
      2598,
      2496,
      2445,
      2449,
    ],
    [1489, 1497, 1864, 2116, 1466, 2396, 2377, 265, 267],
    [2116, 2396, 2380, 2271, 1393, 1456, 2622, 2603],
    [
      1400,
      2116,
      1864,
      1870,
      1318,
      1320,
      1316,
      1317,
      2188,
      1466,
      2396,
      2271,
      1393,
      630,
    ],
    [1907, 2116, 2598, 1456, 2609, 1449],
    [1907, 1456, 2622, 2603],
    [1399, 1849, 2741, 909],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 2, 3, 4, 5, 6],
    [7, 1, 2, 3, 4, 5, 6],
  ];
}
