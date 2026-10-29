// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `dialog`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `dialog` (`src/components/dialog/dialog.tsx`, index.mjs:686).
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
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'md', false),
    RaftRecipeAxis('layer', ['0', '1'], null, true),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftDialogRecipeStyle resolve({
    RaftDialogRecipeSize? size,
    RaftDialogRecipeLayer? layer,
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css, layer?.css, theme.name],
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
    [1643, 2322, 3183, 3126, 1626, 1637, 1590, 1486, 824],
    [
      1643,
      3080,
      2371,
      3183,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2509,
      1726,
      878,
      916,
      830,
      2785,
      2798,
      2898,
    ],
    [1742, 2902, 1749, 2331, 1725, 2597],
    [2597, 1645, 2684, 2794, 1713],
    [1644, 2902, 2331, 2337, 1725],
    [2378, 2597, 3013, 1712, 3041, 2363, 1709, 3137],
    [2378, 1716, 3053, 2354, 3030],
    [1643, 2322, 3183, 3126, 1626, 1637, 1590, 1486, 824, 685],
    [
      1643,
      3080,
      2371,
      3183,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2509,
      2678,
      2847,
      833,
      2898,
    ],
    [1742, 2902, 1749, 2331, 1725, 2597, 2785, 2796],
    [2597, 1645, 2684, 2785, 2799, 1149],
    [1644, 2902, 2331, 2337, 1725, 2785, 2796],
    [2378, 2597, 3013, 1716, 2993, 2356, 1709, 3137, 3090],
    [2378, 1716, 3053, 2354, 3014],
    [1643, 2322, 3126, 1626, 1637, 1590, 1486, 3184, 824],
    [
      1643,
      3080,
      2371,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2509,
      3184,
      1726,
      878,
      916,
      830,
      2785,
      2798,
      2898,
    ],
    [1643, 2322, 3126, 1626, 1637, 1590, 1486, 3184, 824, 685],
    [
      1643,
      3080,
      2371,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2509,
      3184,
      2678,
      2847,
      833,
      2898,
    ],
    [
      1643,
      3080,
      2371,
      3183,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2507,
      1726,
      878,
      916,
      830,
      2785,
      2798,
      2898,
    ],
    [
      1643,
      3080,
      2371,
      3183,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2507,
      2678,
      2847,
      833,
      2898,
    ],
    [
      1643,
      3080,
      2371,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2507,
      3184,
      1726,
      878,
      916,
      830,
      2785,
      2798,
      2898,
    ],
    [
      1643,
      3080,
      2371,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2507,
      3184,
      2678,
      2847,
      833,
      2898,
    ],
    [
      1643,
      3080,
      2371,
      3183,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2506,
      1726,
      878,
      916,
      830,
      2785,
      2798,
      2898,
    ],
    [
      1643,
      3080,
      2371,
      3183,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2506,
      2678,
      2847,
      833,
      2898,
    ],
    [
      1643,
      3080,
      2371,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2506,
      3184,
      1726,
      878,
      916,
      830,
      2785,
      2798,
      2898,
    ],
    [
      1643,
      3080,
      2371,
      1644,
      3161,
      152,
      1646,
      2388,
      2664,
      3101,
      2672,
      3119,
      1626,
      1637,
      1591,
      1590,
      1486,
      2506,
      3184,
      2678,
      2847,
      833,
      2898,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [7, 8, 9, 10, 11, 12, 13],
    [0, 1, 2, 3, 4, 5, 6],
    [7, 8, 9, 10, 11, 12, 13],
    [14, 15, 2, 3, 4, 5, 6],
    [16, 17, 9, 10, 11, 12, 13],
    [0, 18, 2, 3, 4, 5, 6],
    [7, 19, 9, 10, 11, 12, 13],
    [0, 18, 2, 3, 4, 5, 6],
    [7, 19, 9, 10, 11, 12, 13],
    [14, 20, 2, 3, 4, 5, 6],
    [16, 21, 9, 10, 11, 12, 13],
    [0, 22, 2, 3, 4, 5, 6],
    [7, 23, 9, 10, 11, 12, 13],
    [0, 22, 2, 3, 4, 5, 6],
    [7, 23, 9, 10, 11, 12, 13],
    [14, 24, 2, 3, 4, 5, 6],
    [16, 25, 9, 10, 11, 12, 13],
  ];
}
