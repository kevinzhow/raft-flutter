// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `card`.
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

/// raft-ui recipe `card` (`dist/components/card/card.recipe.mjs`, index.mjs:3353).
///
/// Used by: Card, CardContent, CardDescription, CardFooter, CardHeader, CardLeading, CardTitle, CardTrailing.
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
    RaftRecipeAxis('variant', ['default', 'option', 'inset'], 'default', false),
  ];

  static RaftCardRecipeStyle resolve({
    RaftCardRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css],
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
    [1400, 2116, 1404, 2252, 2598, 2462, 939, 953, 911, 2497],
    [
      1598,
      1489,
      2116,
      802,
      1490,
      1866,
      1482,
      1486,
      1693,
      1695,
      1694,
      1691,
      1692,
      2265,
      1682,
    ],
    [2476, 2116, 986, 1456, 2589, 1450, 2598],
    [988, 2474, 2476, 1400, 2499, 1864, 2489, 352, 348, 2095],
    [2477, 2116, 986, 1456, 2587, 2617, 2603],
    [2476, 987, 1400, 2499, 1864, 2487, 1871],
    [2116, 2265],
    [
      1400,
      2116,
      1466,
      1406,
      1864,
      1456,
      2588,
      2600,
      351,
      348,
      264,
      960,
      953,
      2405,
      2419,
    ],
    [1400, 2116, 1404, 2252, 2598, 2463, 941, 952, 911, 2497],
    [
      1598,
      1489,
      2116,
      802,
      1490,
      1866,
      1486,
      1693,
      1695,
      1694,
      1691,
      1692,
      1481,
      2264,
    ],
    [2476, 2116, 986, 2598, 1456, 2587, 1457],
    [2477, 2116, 986, 2617, 1456, 2597, 2603],
    [2116, 2403, 2276],
    [1400, 2116, 1466, 1406, 1864, 1456, 2588, 2600, 351, 348, 264],
    [
      1598,
      1489,
      2116,
      802,
      1490,
      1866,
      1482,
      1486,
      1693,
      1695,
      1694,
      1691,
      1692,
      2405,
      2419,
    ],
    [2116, 960, 953, 2265, 1391],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 9, 10, 3, 11, 5, 12, 13],
    [0, 14, 2, 3, 4, 5, 15, 7],
  ];
}
