// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `card`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `card` (default `default`).
enum RaftCardRecipeVariant {
  default_('default'),
  option('option'),
  inset('inset');

  const RaftCardRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftCardRecipe].
class RaftCardRecipeStyle {
  const RaftCardRecipeStyle({
    required this.root,
    required this.header,
    required this.title,
    required this.leading,
    required this.description,
    required this.trailing,
    required this.content,
    required this.footer,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `leading`.
  final RaftSlotStyle leading;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `trailing`.
  final RaftSlotStyle trailing;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'title': title,
    'leading': leading,
    'description': description,
    'trailing': trailing,
    'content': content,
    'footer': footer,
  };
}

/// raft-ui recipe `card` (`src/components/card/card.recipe.ts`, index.mjs:1752).
///
/// Used by: Card, CardContent, CardDescription, CardFooter, CardHeader, CardLeading, CardTitle, CardTrailing, MessageAttachmentCard.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCardRecipe {
  static const String recipeName = 'card';
  static const List<String> slotNames = [
    'root',
    'header',
    'title',
    'leading',
    'description',
    'trailing',
    'content',
    'footer',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['default', 'option', 'inset'], 'default', false),
  ];

  static RaftCardRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftCardRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftCardRecipeStyle(
      root: s[0],
      header: s[1],
      title: s[2],
      leading: s[3],
      description: s[4],
      trailing: s[5],
      content: s[6],
      footer: s[7],
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
    [1644, 2597, 1646, 2679, 3013, 878, 916, 830, 2896],
    [
      1914,
      1742,
      2597,
      682,
      1743,
      2333,
      1735,
      1739,
      1996,
      1998,
      1997,
      1994,
      1995,
      891,
      916,
      2696,
    ],
    [2859, 2597, 952, 1712, 3006, 1710],
    [956, 2856, 2859, 1644, 2902, 2331, 2871, 301, 298, 2581],
    [2860, 2597, 952, 1716, 3053, 2354, 3030],
    [2859, 953, 1644, 2902, 2331, 2870, 2338],
    [2597, 2696],
    [
      1644,
      2597,
      1723,
      1648,
      2331,
      1716,
      3073,
      2352,
      3018,
      300,
      298,
      219,
      927,
      916,
      829,
      2783,
      2796,
    ],
    [1644, 2597, 1646, 2679, 3013, 878, 916, 830, 2897],
    [
      1914,
      1742,
      2597,
      682,
      1743,
      2333,
      1739,
      1996,
      1998,
      1997,
      1994,
      1995,
      1734,
      2695,
    ],
    [2859, 2597, 952, 1712, 3053, 2354, 1709],
    [2860, 2597, 952, 3030, 1716, 3073, 2352],
    [2597, 2781, 2708],
    [1644, 2597, 1723, 1648, 2331, 1716, 3073, 2352, 3018, 300, 298, 219],
    [1644, 2597, 1646, 2679, 3013, 878, 916, 830, 2779, 2896],
    [
      1914,
      1742,
      2597,
      682,
      1743,
      2333,
      1735,
      1739,
      1996,
      1998,
      1997,
      1994,
      1995,
      2783,
      2796,
    ],
    [2597, 139, 935, 916, 830, 2785, 2798],
    [
      1644,
      2597,
      1723,
      1648,
      2331,
      1716,
      3073,
      2352,
      3018,
      300,
      298,
      219,
      2783,
      2796,
    ],
    [1644, 2597, 1646, 2679, 3013, 2847, 879, 912, 830, 2899, 1029],
    [
      1914,
      1742,
      2597,
      682,
      1743,
      2333,
      1735,
      1739,
      1996,
      1998,
      1997,
      1994,
      1995,
      2697,
      1982,
    ],
    [2859, 2597, 952, 1716, 3006, 1710],
    [2860, 2597, 952, 1716, 3073, 2352, 3089, 3042, 3018],
    [2597, 2697],
    [
      1644,
      2597,
      1723,
      1648,
      2331,
      1716,
      3073,
      2352,
      3014,
      300,
      298,
      219,
      925,
      911,
      829,
      2784,
      2797,
      1029,
      1022,
    ],
    [1644, 2597, 1646, 2679, 3013, 2848, 876, 910, 830, 2894],
    [2859, 2597, 952, 1716, 3053, 2354, 1717],
    [2860, 2597, 952, 3089, 3042, 3018, 1716, 3073, 2352],
    [1644, 2597, 1723, 1648, 2331, 1716, 3073, 2352, 3014, 300, 298, 219],
    [1644, 2597, 1646, 2679, 3013, 2847, 879, 912, 826, 2698, 2899, 1029],
    [
      1914,
      1742,
      2597,
      682,
      1743,
      2333,
      1735,
      1739,
      1996,
      1998,
      1997,
      1994,
      1995,
      2784,
      2797,
    ],
    [2597, 2678, 2839, 879, 911, 830, 2697, 1029, 1157],
    [
      1644,
      2597,
      1723,
      1648,
      2331,
      1716,
      3073,
      2352,
      3014,
      300,
      298,
      219,
      2784,
      2796,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 9, 10, 3, 11, 5, 12, 13],
    [14, 15, 2, 3, 4, 5, 16, 17],
    [18, 19, 20, 3, 21, 5, 22, 23],
    [24, 9, 25, 3, 26, 5, 12, 27],
    [28, 29, 20, 3, 21, 5, 30, 31],
  ];
}
