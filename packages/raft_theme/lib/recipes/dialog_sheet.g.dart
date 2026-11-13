// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `dialogSheet`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftDialogSheetRecipe].
class RaftDialogSheetRecipeStyle {
  const RaftDialogSheetRecipeStyle({
    required this.content,
    required this.overlay,
    required this.header,
    required this.title,
    required this.commitSlot,
    required this.body,
    required this.barBody,
    required this.bodyEnd,
  });

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `overlay`.
  final RaftSlotStyle overlay;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `commitSlot`.
  final RaftSlotStyle commitSlot;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `barBody`.
  final RaftSlotStyle barBody;

  /// Slot `bodyEnd`.
  final RaftSlotStyle bodyEnd;

  Map<String, RaftSlotStyle> get slots => {
    'content': content,
    'overlay': overlay,
    'header': header,
    'title': title,
    'commitSlot': commitSlot,
    'body': body,
    'barBody': barBody,
    'bodyEnd': bodyEnd,
  };
}

/// raft-ui recipe `dialogSheet` (`dist/components/dialog/dialog-sheet-context.mjs`, index.mjs:636).
///
/// Used by: DialogBody, DialogHeader, DialogSheetContent, DialogTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDialogSheetRecipe {
  static const String recipeName = 'dialogSheet';
  static const List<String> slotNames = [
    'content',
    'overlay',
    'header',
    'title',
    'commitSlot',
    'body',
    'barBody',
    'bodyEnd',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftDialogSheetRecipeStyle resolve({
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
    return RaftDialogSheetRecipeStyle(
      content: s[0],
      overlay: s[1],
      header: s[2],
      title: s[3],
      commitSlot: s[4],
      body: s[5],
      barBody: s[6],
      bodyEnd: s[7],
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
    [
      1399,
      1858,
      2649,
      965,
      1895,
      1668,
      1923,
      2725,
      1983,
      2679,
      2468,
      2472,
      2368,
      2310,
      2678,
      1369,
      1377,
      1195,
      1330,
      1204,
      2138,
    ],
    [2676, 1369, 1377, 1195, 1325, 1199, 2138],
    [1400, 1635, 2499, 1864, 1466, 2405, 2378, 942, 954],
    [2116, 1401, 2681],
    [1400, 2499, 1864, 1378],
    [2098, 991, 2405, 2384, 1397, 2288],
    [937, 2256],
    [2149, 1378, 2620, 1456, 2597, 2603, 145],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
