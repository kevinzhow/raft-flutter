// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarItemRecipe`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `sidebarItemRecipe` (default `default`).
enum RaftSidebarItemRecipeVariant {
  default_('default'),
  primary('primary'),
  accent('accent');

  const RaftSidebarItemRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftSidebarItemRecipe].
class RaftSidebarItemRecipeStyle {
  const RaftSidebarItemRecipeStyle({
    required this.sidebarItem,
    required this.sidebarItemIcon,
    required this.sidebarItemChannelIcon,
    required this.sidebarItemContent,
    required this.sidebarItemTitle,
    required this.sidebarItemSubtitle,
    required this.sidebarItemMeta,
    required this.sidebarItemStatus,
    required this.sidebarItemIndicator,
    required this.sidebarItemMetaIcon,
    required this.sidebarItemAside,
    required this.sidebarItemCount,
  });

  /// Slot `sidebarItem`.
  final RaftSlotStyle sidebarItem;

  /// Slot `sidebarItemIcon`.
  final RaftSlotStyle sidebarItemIcon;

  /// Slot `sidebarItemChannelIcon`.
  final RaftSlotStyle sidebarItemChannelIcon;

  /// Slot `sidebarItemContent`.
  final RaftSlotStyle sidebarItemContent;

  /// Slot `sidebarItemTitle`.
  final RaftSlotStyle sidebarItemTitle;

  /// Slot `sidebarItemSubtitle`.
  final RaftSlotStyle sidebarItemSubtitle;

  /// Slot `sidebarItemMeta`.
  final RaftSlotStyle sidebarItemMeta;

  /// Slot `sidebarItemStatus`.
  final RaftSlotStyle sidebarItemStatus;

  /// Slot `sidebarItemIndicator`.
  final RaftSlotStyle sidebarItemIndicator;

  /// Slot `sidebarItemMetaIcon`.
  final RaftSlotStyle sidebarItemMetaIcon;

  /// Slot `sidebarItemAside`.
  final RaftSlotStyle sidebarItemAside;

  /// Slot `sidebarItemCount`.
  final RaftSlotStyle sidebarItemCount;

  Map<String, RaftSlotStyle> get slots => {
    'sidebarItem': sidebarItem,
    'sidebarItemIcon': sidebarItemIcon,
    'sidebarItemChannelIcon': sidebarItemChannelIcon,
    'sidebarItemContent': sidebarItemContent,
    'sidebarItemTitle': sidebarItemTitle,
    'sidebarItemSubtitle': sidebarItemSubtitle,
    'sidebarItemMeta': sidebarItemMeta,
    'sidebarItemStatus': sidebarItemStatus,
    'sidebarItemIndicator': sidebarItemIndicator,
    'sidebarItemMetaIcon': sidebarItemMetaIcon,
    'sidebarItemAside': sidebarItemAside,
    'sidebarItemCount': sidebarItemCount,
  };
}

/// raft-ui recipe `sidebarItemRecipe` (`src/components/sidebar/sidebar-item.recipe.ts`, index.mjs:3827).
///
/// Used by: SidebarItem, SidebarItemAside, SidebarItemChannelIcon, SidebarItemContent, SidebarItemCount, SidebarItemIcon, SidebarItemIndicator, SidebarItemMeta, SidebarItemMetaIcon, SidebarItemStatus, SidebarItemSubtitle, SidebarItemTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarItemRecipe {
  static const String recipeName = 'sidebarItemRecipe';
  static const List<String> slotNames = [
    'sidebarItem',
    'sidebarItemIcon',
    'sidebarItemChannelIcon',
    'sidebarItemContent',
    'sidebarItemTitle',
    'sidebarItemSubtitle',
    'sidebarItemMeta',
    'sidebarItemStatus',
    'sidebarItemIndicator',
    'sidebarItemMetaIcon',
    'sidebarItemAside',
    'sidebarItemCount',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis(
      'variant',
      ['default', 'primary', 'accent'],
      'default',
      false,
    ),
    RaftRecipeAxis('stacked', ['false', 'true'], 'false', false),
  ];

  static RaftSidebarItemRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftSidebarItemRecipeVariant? variant,
    bool? stacked,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, variant?.css, stacked?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSidebarItemRecipeStyle(
      sidebarItem: s[0],
      sidebarItemIcon: s[1],
      sidebarItemChannelIcon: s[2],
      sidebarItemContent: s[3],
      sidebarItemTitle: s[4],
      sidebarItemSubtitle: s[5],
      sidebarItemMeta: s[6],
      sidebarItemStatus: s[7],
      sidebarItemIndicator: s[8],
      sidebarItemMetaIcon: s[9],
      sidebarItemAside: s[10],
      sidebarItemCount: s[11],
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
      1935,
      2512,
      1644,
      3168,
      2331,
      1722,
      2779,
      2794,
      3040,
      878,
      3053,
      1713,
      3125,
      568,
      2575,
      930,
      2994,
      2260,
      2256,
      2288,
      598,
      597,
      610,
      1415,
      1429,
      1552,
      1551,
      1559,
      1663,
      1672,
      1671,
      1664,
      1413,
    ],
    [1644, 2916, 2902, 2331, 2336, 300, 298],
    [1644, 2902, 2331, 2336, 425, 442, 427],
    [2041, 2597, 1644, 1645, 2330, 1721, 3040, 2042, 2043],
    [874, 2597, 3133, 2485, 2901, 1713, 2994],
    [874, 2597, 1645, 3133, 3073, 1715, 2996],
    [
      2608,
      2902,
      2320,
      1962,
      2331,
      2336,
      876,
      930,
      2778,
      1716,
      3073,
      1709,
      2363,
      2946,
      3001,
    ],
    [2902, 240],
    [
      2915,
      2902,
      2331,
      2336,
      1719,
      2775,
      2789,
      209,
      426,
      425,
      453,
      2852,
      876,
      892,
      836,
      2956,
      1709,
      2363,
      2994,
    ],
    [2320, 2915, 2902, 2331, 2336, 427, 425, 3001],
    [1644, 2902, 2331, 1721],
    [
      2902,
      1962,
      1719,
      2852,
      876,
      892,
      786,
      2778,
      2790,
      1716,
      2956,
      1709,
      2363,
      2946,
      3067,
    ],
    [2041, 2597, 1645, 3040],
    [
      1935,
      2512,
      1644,
      3168,
      2331,
      1722,
      2779,
      2794,
      3040,
      878,
      3053,
      1713,
      3125,
      568,
      2575,
      930,
      2994,
      2260,
      2256,
      2288,
      598,
      597,
      610,
      1415,
      1429,
      1552,
      1551,
      1559,
      1663,
      1672,
      1671,
      1664,
      1410,
    ],
    [
      1935,
      2512,
      1644,
      3168,
      2331,
      1722,
      2779,
      2794,
      3040,
      878,
      3053,
      1713,
      3125,
      568,
      2575,
      930,
      2994,
      2260,
      2256,
      2288,
      598,
      597,
      610,
      1415,
      1429,
      1552,
      1551,
      1559,
      1663,
      1672,
      1671,
      1664,
      1409,
    ],
    [
      1935,
      1644,
      2331,
      1722,
      3040,
      3125,
      2804,
      2328,
      2511,
      137,
      3160,
      2848,
      876,
      930,
      2774,
      2792,
      2576,
      568,
      127,
      2962,
      1713,
      3018,
      2267,
      2233,
      2295,
      1125,
      980,
      599,
      593,
      612,
      1416,
      1411,
      1050,
      1433,
      1429,
      1426,
      1427,
      1051,
      1554,
      1549,
      1071,
      1560,
      1555,
      1556,
      1072,
    ],
    [1644, 2902, 2331, 2336, 300, 298, 2916, 3015, 442],
    [1644, 2902, 2331, 2336, 425, 442, 2913, 3015, 428],
    [874, 2597, 3133, 2485, 2901, 1706, 3018],
    [874, 2597, 1645, 3133, 3073, 1715, 3038],
    [
      2608,
      2902,
      2320,
      1962,
      2599,
      2331,
      2336,
      1716,
      2956,
      1713,
      2363,
      2946,
      3015,
    ],
    [2902, 2739, 586, 3080, 2817, 155, 239],
    [
      2915,
      2902,
      2331,
      2336,
      1719,
      2775,
      2789,
      209,
      426,
      425,
      453,
      2852,
      877,
      2956,
      1715,
      2363,
      3094,
    ],
    [2320, 2915, 2902, 2331, 2336, 427, 425, 3015],
    [
      2902,
      1962,
      2599,
      2331,
      2336,
      2852,
      2777,
      2789,
      2956,
      1715,
      2363,
      2946,
      3094,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [0, 1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11],
    [13, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [13, 1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11],
    [14, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [14, 1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11],
    [15, 16, 17, 3, 18, 19, 20, 21, 22, 23, 10, 24],
    [15, 16, 17, 12, 18, 19, 20, 21, 22, 23, 10, 24],
    [15, 16, 17, 3, 18, 19, 20, 21, 22, 23, 10, 24],
    [15, 16, 17, 12, 18, 19, 20, 21, 22, 23, 10, 24],
    [15, 16, 17, 3, 18, 19, 20, 21, 22, 23, 10, 24],
    [15, 16, 17, 12, 18, 19, 20, 21, 22, 23, 10, 24],
  ];
}
