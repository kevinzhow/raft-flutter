// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `dialog`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `dialog` (default `md`).
enum RaftDialogRecipeSize {
  sm('sm'),
  md('md'),
  lg('lg'),
  wide('wide');

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
  const RaftDialogRecipeStyle({
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

/// raft-ui recipe `dialog` (`src/components/dialog/dialog.tsx`, index.mjs:313).
///
/// Used by: DialogBody, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogOverlay, DialogTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDialogRecipe {
  static const String recipeName = 'dialog';
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
    RaftRecipeAxis('size', ['sm', 'md', 'lg', 'wide'], 'md', false),
    RaftRecipeAxis('bar', ['false', 'true'], 'false', false),
    RaftRecipeAxis('layer', ['0', '1'], null, true),
  ];

  static RaftDialogRecipeStyle resolve({
    RaftDialogRecipeSize? size,
    bool? bar,
    RaftDialogRecipeLayer? layer,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css, bar?.toString(), layer?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftDialogRecipeStyle(
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
    [964, 1307, 1941, 594],
    [
      964,
      1863,
      1351,
      1941,
      965,
      1918,
      107,
      967,
      1367,
      1575,
      1580,
      1709,
      602,
      1820,
      1735,
      1692,
      1696,
      1428,
    ],
    [1040, 1738, 1046, 1319, 1483, 1023, 1661, 1647],
    [1483, 966, 1585, 1661, 1642, 1607, 962, 1016, 1843, 1825],
    [965, 1738, 1319, 1325, 1023, 1661, 1607, 962, 401],
    [1357, 1483, 1820, 1016, 1831, 1008],
    [1357, 1016, 1843, 1825],
    [964, 1307, 594, 1942],
    [
      964,
      1863,
      1351,
      965,
      1918,
      107,
      967,
      1367,
      1575,
      1580,
      1709,
      602,
      1820,
      1735,
      1692,
      1696,
      1428,
      1942,
    ],
    [1046, 1483, 965, 1176, 1738, 1319, 1023, 623, 1661, 1664, 634, 1640, 134],
    [1483, 1016, 1843, 965, 1467, 966, 1581, 1590, 1652, 1640, 1600, 959, 1820],
    [965, 1319, 1325, 1023, 1738, 639, 1661, 1671, 634, 1645, 1605, 961, 400],
    [
      964,
      1863,
      1351,
      1941,
      965,
      1918,
      107,
      967,
      1367,
      1575,
      1580,
      1709,
      602,
      1820,
      1735,
      1692,
      1696,
      1426,
    ],
    [
      964,
      1863,
      1351,
      965,
      1918,
      107,
      967,
      1367,
      1575,
      1580,
      1709,
      602,
      1820,
      1735,
      1692,
      1696,
      1426,
      1942,
    ],
    [
      964,
      1863,
      1351,
      1941,
      965,
      1918,
      107,
      967,
      1367,
      1575,
      1580,
      1709,
      602,
      1820,
      1735,
      1692,
      1696,
      1425,
    ],
    [
      964,
      1863,
      1351,
      965,
      1918,
      107,
      967,
      1367,
      1575,
      1580,
      1709,
      602,
      1820,
      1735,
      1692,
      1696,
      1425,
      1942,
    ],
    [
      964,
      1863,
      1351,
      1941,
      965,
      1918,
      107,
      967,
      1367,
      1575,
      1580,
      1709,
      602,
      1820,
      1735,
      1692,
      1696,
      1405,
      1195,
    ],
    [
      964,
      1863,
      1351,
      965,
      1918,
      107,
      967,
      1367,
      1575,
      1580,
      1709,
      602,
      1820,
      1735,
      1692,
      1696,
      1405,
      1195,
      1942,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 2, 3, 4, 5, 6],
    [7, 8, 2, 3, 4, 5, 6],
    [0, 1, 9, 10, 11, 5, 6],
    [0, 1, 9, 10, 11, 5, 6],
    [7, 8, 9, 10, 11, 5, 6],
    [0, 12, 2, 3, 4, 5, 6],
    [0, 12, 2, 3, 4, 5, 6],
    [7, 13, 2, 3, 4, 5, 6],
    [0, 12, 9, 10, 11, 5, 6],
    [0, 12, 9, 10, 11, 5, 6],
    [7, 13, 9, 10, 11, 5, 6],
    [0, 14, 2, 3, 4, 5, 6],
    [0, 14, 2, 3, 4, 5, 6],
    [7, 15, 2, 3, 4, 5, 6],
    [0, 14, 9, 10, 11, 5, 6],
    [0, 14, 9, 10, 11, 5, 6],
    [7, 15, 9, 10, 11, 5, 6],
    [0, 16, 2, 3, 4, 5, 6],
    [0, 16, 2, 3, 4, 5, 6],
    [7, 17, 2, 3, 4, 5, 6],
    [0, 16, 9, 10, 11, 5, 6],
    [0, 16, 9, 10, 11, 5, 6],
    [7, 17, 9, 10, 11, 5, 6],
  ];
}
