// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarItemRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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
  const RaftSidebarItemRecipeStyle({required this.sidebarItem, required this.sidebarItemIcon, required this.sidebarItemChannelIcon, required this.sidebarItemContent, required this.sidebarItemTitle, required this.sidebarItemSubtitle, required this.sidebarItemMeta, required this.sidebarItemStatus, required this.sidebarItemIndicator, required this.sidebarItemMetaIcon, required this.sidebarItemAside, required this.sidebarItemCount});

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

  Map<String, RaftSlotStyle> get slots => {'sidebarItem': sidebarItem, 'sidebarItemIcon': sidebarItemIcon, 'sidebarItemChannelIcon': sidebarItemChannelIcon, 'sidebarItemContent': sidebarItemContent, 'sidebarItemTitle': sidebarItemTitle, 'sidebarItemSubtitle': sidebarItemSubtitle, 'sidebarItemMeta': sidebarItemMeta, 'sidebarItemStatus': sidebarItemStatus, 'sidebarItemIndicator': sidebarItemIndicator, 'sidebarItemMetaIcon': sidebarItemMetaIcon, 'sidebarItemAside': sidebarItemAside, 'sidebarItemCount': sidebarItemCount};
}

/// raft-ui recipe `sidebarItemRecipe` (`src/components/sidebar/sidebar-item.recipe.ts`, index.mjs:3816).
///
/// Used by: SidebarItem, SidebarItemAside, SidebarItemChannelIcon, SidebarItemContent, SidebarItemCount, SidebarItemIcon, SidebarItemIndicator, SidebarItemMeta, SidebarItemMetaIcon, SidebarItemStatus, SidebarItemSubtitle, SidebarItemTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarItemRecipe {
  static const String recipeName = 'sidebarItemRecipe';
  static const List<String> slotNames = ['sidebarItem', 'sidebarItemIcon', 'sidebarItemChannelIcon', 'sidebarItemContent', 'sidebarItemTitle', 'sidebarItemSubtitle', 'sidebarItemMeta', 'sidebarItemStatus', 'sidebarItemIndicator', 'sidebarItemMetaIcon', 'sidebarItemAside', 'sidebarItemCount'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['default', 'primary', 'accent'], 'default', false),
    RaftRecipeAxis('stacked', ['false', 'true'], 'false', false),
  ];

  static RaftSidebarItemRecipeStyle resolve({required RaftRecipeTheme theme, RaftSidebarItemRecipeVariant? variant, bool? stacked, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, variant?.css, stacked?.toString()], states, tokens);
    return RaftSidebarItemRecipeStyle(sidebarItem: s[0], sidebarItemIcon: s[1], sidebarItemChannelIcon: s[2], sidebarItemContent: s[3], sidebarItemTitle: s[4], sidebarItemSubtitle: s[5], sidebarItemMeta: s[6], sidebarItemStatus: s[7], sidebarItemIndicator: s[8], sidebarItemMetaIcon: s[9], sidebarItemAside: s[10], sidebarItemCount: s[11]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1933, 2491, 1620, 3127, 2312, 1697, 2751, 2765, 3003, 866, 3017, 1688, 3084, 567, 2552, 916, 2956, 2241, 2237, 2269, 592, 591, 604, 1393, 1407, 1528, 1527, 1535, 1639, 1648, 1647, 1640, 1391],
    [1620, 2881, 2867, 2312, 2317, 304, 302],
    [1620, 2867, 2312, 2317, 427, 444, 429],
    [2039, 2574, 1620, 1621, 2311, 1696, 3003, 2040, 2041],
    [862, 2574, 3092, 1688, 2956],
    [862, 2574, 1621, 3092, 3032, 1690, 2959],
    [2585, 2867, 2301, 1960, 2312, 2317, 864, 916, 2750, 1691, 3032, 1684, 2344, 2911, 2964],
    [2867, 242],
    [2880, 2867, 2312, 2317, 1694, 2747, 2760, 211, 428, 427, 455, 2822, 864, 876, 831, 2918, 1684, 2344, 2956],
    [2301, 2880, 2867, 2312, 2317, 429, 427, 2964],
    [1620, 2867, 2312, 1696],
    [2867, 1960, 1694, 2822, 864, 876, 780, 2750, 2761, 1691, 2918, 1684, 2344, 2911, 3026],
    [2039, 2574, 1621, 3003],
    [1933, 2491, 1620, 3127, 2312, 1697, 2751, 2765, 3003, 866, 3017, 1688, 3084, 567, 2552, 916, 2956, 2241, 2237, 2269, 592, 591, 604, 1393, 1407, 1528, 1527, 1535, 1639, 1648, 1647, 1640, 1388],
    [1933, 2491, 1620, 3127, 2312, 1697, 2751, 2765, 3003, 866, 3017, 1688, 3084, 567, 2552, 916, 2956, 2241, 2237, 2269, 592, 591, 604, 1393, 1407, 1528, 1527, 1535, 1639, 1648, 1647, 1640, 1387],
    [1933, 1620, 2312, 1697, 3003, 3084, 2775, 2309, 2490, 137, 3119, 2818, 864, 916, 2746, 2763, 2553, 567, 127, 2924, 1688, 2981, 2248, 2214, 2276, 1105, 960, 593, 587, 606, 1394, 1389, 1030, 1411, 1407, 1404, 1405, 1031, 1530, 1525, 1051, 1536, 1531, 1532, 1052],
    [1620, 2867, 2312, 2317, 304, 302, 2881, 2978, 444],
    [1620, 2867, 2312, 2317, 427, 444, 2878, 2978, 430],
    [862, 2574, 3092, 1681, 2981],
    [862, 2574, 1621, 3092, 3032, 1690, 3001],
    [2585, 2867, 2301, 1960, 2576, 2312, 2317, 1691, 2918, 1688, 2344, 2911, 2978],
    [2867, 2716, 580, 3039, 2788, 155, 241],
    [2880, 2867, 2312, 2317, 1694, 2747, 2760, 211, 428, 427, 455, 2822, 865, 2918, 1690, 2344, 3053],
    [2301, 2880, 2867, 2312, 2317, 429, 427, 2978],
    [2867, 1960, 2576, 2312, 2317, 2822, 2749, 2760, 2918, 1690, 2344, 2911, 3053],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [0, 1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11], [13, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [13, 1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11], [14, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [14, 1, 2, 12, 4, 5, 6, 7, 8, 9, 10, 11], [15, 16, 17, 3, 18, 19, 20, 21, 22, 23, 10, 24], [15, 16, 17, 12, 18, 19, 20, 21, 22, 23, 10, 24], [15, 16, 17, 3, 18, 19, 20, 21, 22, 23, 10, 24], [15, 16, 17, 12, 18, 19, 20, 21, 22, 23, 10, 24], [15, 16, 17, 3, 18, 19, 20, 21, 22, 23, 10, 24], [15, 16, 17, 12, 18, 19, 20, 21, 22, 23, 10, 24],
  ];
}
