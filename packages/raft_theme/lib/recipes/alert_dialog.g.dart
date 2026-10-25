// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `alertDialog` (`src/components/alert-dialog/alert-dialog.tsx`, index.mjs:867).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftAlertDialogRecipeStyle resolve({
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
    [1643, 2322, 3183, 3126, 1626, 1637, 1590, 1486, 824],
    [
      1643,
      3080,
      2371,
      3183,
      1742,
      3161,
      2496,
      152,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      1726,
      878,
      916,
      830,
      2785,
      2798,
      2898,
    ],
    [1742, 1749, 2331, 1725, 2597],
    [2597, 2794, 1713],
    [1644, 2331, 2337, 1725],
    [2378, 2597, 3013, 1712, 3041, 2363, 1709, 3137],
    [2378, 1716, 3053, 2354, 3030],
    [1643, 2322, 3183, 3126, 1626, 1637, 1590, 1486, 824, 685],
    [
      1643,
      3080,
      2371,
      3183,
      1742,
      3161,
      2496,
      152,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2678,
      2847,
      833,
      2898,
    ],
    [1742, 1749, 2331, 1725, 2597, 889, 914, 829, 2784, 2796, 1029, 1022],
    [2597, 2785, 2799, 1149],
    [1644, 2331, 2337, 1725, 925, 914, 829, 2784, 2796, 1029, 1022],
    [2378, 2597, 3013, 1716, 3053, 2354, 1713, 3087],
    [2378, 1716, 3053, 2354, 3014],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [7, 8, 9, 10, 11, 12, 13],
  ];
}
