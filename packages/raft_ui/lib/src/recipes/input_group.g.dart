// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `inputGroup`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

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
    required this.control,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `addon`.
  final RaftSlotStyle addon;

  /// Slot `text`.
  final RaftSlotStyle text;

  /// Slot `control`.
  final RaftSlotStyle control;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'addon': addon,
    'text': text,
    'control': control,
  };
}

/// raft-ui recipe `inputGroup` (`src/components/input-group/input-group.tsx`, index.mjs:6440).
///
/// Used by: ComboboxInputGroup, InputGroup, InputGroupAddon, InputGroupInput.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInputGroupRecipe {
  static const String recipeName = 'inputGroup';
  static const List<String> slotNames = ['root', 'addon', 'text', 'control'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis(
      'align',
      ['inline-start', 'inline-end'],
      'inline-start',
      false,
    ),
    RaftRecipeAxis('variant', ['default', 'container'], 'default', false),
  ];

  static RaftInputGroupRecipeStyle resolve({
    required RaftRecipeTheme theme,
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
      [theme.name, align?.css, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftInputGroupRecipeStyle(
      root: s[0],
      addon: s[1],
      text: s[2],
      control: s[3],
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
      1924,
      2804,
      1644,
      3168,
      2597,
      2331,
      2144,
      878,
      916,
      830,
      2897,
      2098,
      2105,
      2104,
      2110,
      2108,
      2109,
    ],
    [1644, 2902, 2331, 2336, 1723, 2781, 2868, 284, 3029, 2659, 461],
    [1644, 2902, 2331, 2781, 3053, 2868, 3172, 1712, 3029, 2659, 461],
    [2597, 1645, 863, 2794, 2724, 3053, 2672, 2740, 1712],
    [
      1644,
      2902,
      2331,
      2336,
      1723,
      2781,
      2868,
      284,
      2659,
      2872,
      1027,
      1014,
      507,
      793,
      1709,
      3032,
      922,
      916,
    ],
    [
      1644,
      2902,
      2331,
      2781,
      3053,
      2868,
      3172,
      1712,
      2659,
      2872,
      1027,
      1014,
      508,
      793,
      1709,
      3032,
      922,
      916,
    ],
    [1644, 2902, 2331, 2336, 1723, 2781, 2868, 284, 3029, 2660],
    [1644, 2902, 2331, 2781, 3053, 2868, 3172, 1712, 3029, 2660],
    [
      1644,
      2902,
      2331,
      2336,
      1723,
      2781,
      2868,
      284,
      2660,
      2872,
      1027,
      1014,
      507,
      793,
      1709,
      3032,
      908,
      916,
    ],
    [
      1644,
      2902,
      2331,
      2781,
      3053,
      2868,
      3172,
      1712,
      2660,
      2872,
      1027,
      1014,
      508,
      793,
      1709,
      3032,
      908,
      916,
    ],
    [
      1924,
      2804,
      1644,
      3168,
      2597,
      2331,
      2144,
      2095,
      2096,
      2087,
      2088,
      2679,
      2848,
      876,
      910,
      830,
      2894,
      1013,
      1147,
      1161,
      1131,
      3013,
      3102,
      1629,
      1637,
      1187,
      2264,
      2097,
      1110,
      2093,
      2094,
      1108,
      1109,
      2106,
      2107,
      2103,
      2101,
      2102,
      2091,
      2090,
      2089,
      2092,
      2099,
      2100,
    ],
    [
      1644,
      2902,
      2331,
      2336,
      1723,
      2781,
      2868,
      284,
      2947,
      3102,
      1629,
      1637,
      2659,
      461,
    ],
    [
      1644,
      2902,
      2331,
      2781,
      3053,
      2868,
      3172,
      2948,
      3102,
      1629,
      1637,
      2659,
      461,
    ],
    [
      2597,
      1645,
      863,
      2794,
      2724,
      3053,
      2672,
      2740,
      3013,
      2735,
      1187,
      3102,
      1629,
      1637,
      2737,
      2731,
      2732,
      1608,
      1617,
      1613,
    ],
    [
      1644,
      2902,
      2331,
      2336,
      1723,
      2781,
      2868,
      284,
      2947,
      3102,
      1629,
      1637,
      2659,
      2872,
      915,
      802,
      1027,
      1014,
      507,
      921,
    ],
    [
      1644,
      2902,
      2331,
      2781,
      3053,
      2868,
      3172,
      2948,
      3102,
      1629,
      1637,
      2659,
      2872,
      915,
      802,
      1027,
      1014,
      508,
      921,
    ],
    [
      1644,
      2902,
      2331,
      2336,
      1723,
      2781,
      2868,
      284,
      2947,
      3102,
      1629,
      1637,
      2660,
    ],
    [1644, 2902, 2331, 2781, 3053, 2868, 3172, 2948, 3102, 1629, 1637, 2660],
    [
      1644,
      2902,
      2331,
      2336,
      1723,
      2781,
      2868,
      284,
      2947,
      3102,
      1629,
      1637,
      2660,
      2872,
      915,
      802,
      1027,
      1014,
      507,
      907,
    ],
    [
      1644,
      2902,
      2331,
      2781,
      3053,
      2868,
      3172,
      2948,
      3102,
      1629,
      1637,
      2660,
      2872,
      915,
      802,
      1027,
      1014,
      508,
      907,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [0, 4, 5, 3],
    [0, 6, 7, 3],
    [0, 8, 9, 3],
    [10, 11, 12, 13],
    [10, 14, 15, 13],
    [10, 16, 17, 13],
    [10, 18, 19, 13],
  ];
}
