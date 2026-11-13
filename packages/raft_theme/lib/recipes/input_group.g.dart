// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `inputGroup`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `inputGroup` (default `lg`).
enum RaftInputGroupRecipeSize {
  md('md'),
  lg('lg');

  const RaftInputGroupRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `align` axis of `inputGroup` (default `inline-start`).
enum RaftInputGroupRecipeAlign {
  inlineStart('inline-start'),
  inlineEnd('inline-end');

  const RaftInputGroupRecipeAlign(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `inputGroup` (default `default`).
enum RaftInputGroupRecipeVariant {
  default_('default'),
  container('container');

  const RaftInputGroupRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftInputGroupRecipe].
class RaftInputGroupRecipeStyle {
  const RaftInputGroupRecipeStyle({
    required this.root,
    required this.addon,
    required this.text,
    required this.textInner,
    required this.control,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `addon`.
  final RaftSlotStyle addon;

  /// Slot `text`.
  final RaftSlotStyle text;

  /// Slot `textInner`.
  final RaftSlotStyle textInner;

  /// Slot `control`.
  final RaftSlotStyle control;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'addon': addon,
    'text': text,
    'textInner': textInner,
    'control': control,
  };
}

/// raft-ui recipe `inputGroup` (`dist/components/input-group/input-group.mjs`, index.mjs:7806).
///
/// Used by: InputGroup, InputGroupAddon, InputGroupInput.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInputGroupRecipe {
  static const String recipeName = 'inputGroup';
  static const List<String> slotNames = [
    'root',
    'addon',
    'text',
    'textInner',
    'control',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['md', 'lg'], 'lg', false),
    RaftRecipeAxis(
      'align',
      ['inline-start', 'inline-end'],
      'inline-start',
      false,
    ),
    RaftRecipeAxis('variant', ['default', 'container'], 'default', false),
  ];

  static RaftInputGroupRecipeStyle resolve({
    RaftInputGroupRecipeSize? size,
    RaftInputGroupRecipeAlign? align,
    RaftInputGroupRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css, align?.css, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftInputGroupRecipeStyle(
      root: s[0],
      addon: s[1],
      text: s[2],
      textInner: s[3],
      control: s[4],
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
      1609,
      2433,
      1400,
      2725,
      2116,
      1864,
      1733,
      941,
      952,
      911,
      2598,
      2497,
      2677,
      1373,
      1376,
      1775,
      1722,
      1721,
      1720,
      1719,
      1717,
      1718,
      1661,
      2042,
      2463,
      2253,
      547,
      2022,
      112,
      113,
      509,
      2019,
      147,
      146,
    ],
    [1400, 2499, 1864, 1869, 1466, 2403, 2483, 2557, 328, 2236, 499, 2359],
    [
      1400,
      2116,
      1953,
      2499,
      1864,
      2403,
      2483,
      1454,
      2615,
      2558,
      2236,
      499,
      2354,
    ],
    [2116, 2681],
    [
      2116,
      1401,
      933,
      2300,
      2247,
      2351,
      1678,
      2412,
      1452,
      2596,
      1451,
      2598,
      2311,
      1353,
      1363,
      1359,
    ],
    [
      1400,
      2499,
      1864,
      1869,
      1466,
      2403,
      2483,
      2557,
      328,
      2236,
      2490,
      546,
      953,
      895,
      956,
    ],
    [
      1400,
      2116,
      1953,
      2499,
      1864,
      2403,
      2483,
      1454,
      2615,
      2558,
      2236,
      2490,
      548,
      953,
      895,
      956,
    ],
    [
      1400,
      2499,
      1864,
      1869,
      1466,
      2403,
      2483,
      2557,
      328,
      2237,
      2298,
      100,
      99,
      269,
      268,
    ],
    [1400, 2116, 1953, 2499, 1864, 2403, 2483, 1454, 2615, 2558, 2237, 2296],
    [
      1400,
      2499,
      1864,
      1869,
      1466,
      2403,
      2483,
      2557,
      328,
      2237,
      2490,
      546,
      953,
      895,
      950,
    ],
    [
      1400,
      2116,
      1953,
      2499,
      1864,
      2403,
      2483,
      1454,
      2615,
      2558,
      2237,
      2490,
      548,
      953,
      895,
      950,
    ],
    [
      1609,
      2433,
      1400,
      2725,
      2116,
      1864,
      1733,
      1674,
      2252,
      2454,
      941,
      952,
      911,
      2598,
      2497,
      2677,
      1373,
      1376,
      1775,
      1722,
      1721,
      1720,
      1719,
      1717,
      1718,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [0, 5, 6, 3, 4],
    [0, 7, 8, 3, 4],
    [0, 9, 10, 3, 4],
    [11, 1, 2, 3, 4],
    [11, 5, 6, 3, 4],
    [11, 7, 8, 3, 4],
    [11, 9, 10, 3, 4],
  ];
}
