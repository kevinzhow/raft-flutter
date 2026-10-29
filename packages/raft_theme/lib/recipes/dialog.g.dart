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
    [964, 1307, 1944, 594],
    [
      964,
      1865,
      1351,
      1944,
      965,
      1921,
      107,
      967,
      1367,
      1577,
      1582,
      1711,
      602,
      1822,
      1737,
      1694,
      1698,
      1428,
    ],
    [1040, 1740, 1046, 1319, 1484, 1023, 1663, 1649],
    [1484, 966, 1587, 1663, 1644, 1609, 962, 1016, 1845, 1827],
    [965, 1740, 1319, 1325, 1023, 1663, 1609, 962, 401],
    [1357, 1484, 1822, 1016, 1833, 1008],
    [1357, 1016, 1845, 1827],
    [964, 1307, 594, 1945],
    [
      964,
      1865,
      1351,
      965,
      1921,
      107,
      967,
      1367,
      1577,
      1582,
      1711,
      602,
      1822,
      1737,
      1694,
      1698,
      1428,
      1945,
    ],
    [1046, 1484, 965, 1176, 1740, 1319, 1023, 623, 1663, 1666, 634, 1642, 134],
    [1484, 1016, 1845, 965, 1468, 966, 1583, 1592, 1654, 1642, 1602, 959, 1822],
    [965, 1319, 1325, 1023, 1740, 639, 1663, 1673, 634, 1647, 1607, 961, 400],
    [
      964,
      1865,
      1351,
      1944,
      965,
      1921,
      107,
      967,
      1367,
      1577,
      1582,
      1711,
      602,
      1822,
      1737,
      1694,
      1698,
      1426,
    ],
    [
      964,
      1865,
      1351,
      965,
      1921,
      107,
      967,
      1367,
      1577,
      1582,
      1711,
      602,
      1822,
      1737,
      1694,
      1698,
      1426,
      1945,
    ],
    [
      964,
      1865,
      1351,
      1944,
      965,
      1921,
      107,
      967,
      1367,
      1577,
      1582,
      1711,
      602,
      1822,
      1737,
      1694,
      1698,
      1425,
    ],
    [
      964,
      1865,
      1351,
      965,
      1921,
      107,
      967,
      1367,
      1577,
      1582,
      1711,
      602,
      1822,
      1737,
      1694,
      1698,
      1425,
      1945,
    ],
    [
      964,
      1865,
      1351,
      1944,
      965,
      1921,
      107,
      967,
      1367,
      1577,
      1582,
      1711,
      602,
      1822,
      1737,
      1694,
      1698,
      1405,
      1195,
    ],
    [
      964,
      1865,
      1351,
      965,
      1921,
      107,
      967,
      1367,
      1577,
      1582,
      1711,
      602,
      1822,
      1737,
      1694,
      1698,
      1405,
      1195,
      1945,
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
