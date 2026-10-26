// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `alertDialog`.
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

/// raft-ui recipe `alertDialog` (`src/components/alert-dialog/alert-dialog.tsx`, index.mjs:511).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftAlertDialogRecipeStyle resolve({
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
    [964, 1306, 1939, 594],
    [
      964,
      1861,
      1350,
      1939,
      1039,
      1916,
      1411,
      107,
      1573,
      1578,
      1707,
      602,
      1818,
      1733,
      1690,
      1694,
    ],
    [1039, 1045, 1318, 1481, 1022, 1659, 1645],
    [1481, 1659, 1640, 1605, 962, 1015, 1841, 1823],
    [965, 1318, 1324, 1022, 1659, 1605, 962, 394],
    [1356, 1481, 1818, 1015, 1829, 1007],
    [1356, 1015, 1841, 1823],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
