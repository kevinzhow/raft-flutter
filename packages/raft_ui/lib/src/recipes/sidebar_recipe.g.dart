// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSidebarRecipe].
class RaftSidebarRecipeStyle {
  const RaftSidebarRecipeStyle({required this.sidebarRoot, required this.sidebarHeader, required this.sidebarHeaderMask, required this.sidebarHeaderMaskLayer, required this.sidebarHeaderTitle, required this.sidebarGroupLabel, required this.sidebarBody, required this.sidebarContent, required this.sidebarViewport, required this.sidebarContentInner, required this.sidebarScrollbar, required this.sidebarLiveActivity});

  /// Slot `sidebarRoot`.
  final RaftSlotStyle sidebarRoot;
  /// Slot `sidebarHeader`.
  final RaftSlotStyle sidebarHeader;
  /// Slot `sidebarHeaderMask`.
  final RaftSlotStyle sidebarHeaderMask;
  /// Slot `sidebarHeaderMaskLayer`.
  final RaftSlotStyle sidebarHeaderMaskLayer;
  /// Slot `sidebarHeaderTitle`.
  final RaftSlotStyle sidebarHeaderTitle;
  /// Slot `sidebarGroupLabel`.
  final RaftSlotStyle sidebarGroupLabel;
  /// Slot `sidebarBody`.
  final RaftSlotStyle sidebarBody;
  /// Slot `sidebarContent`.
  final RaftSlotStyle sidebarContent;
  /// Slot `sidebarViewport`.
  final RaftSlotStyle sidebarViewport;
  /// Slot `sidebarContentInner`.
  final RaftSlotStyle sidebarContentInner;
  /// Slot `sidebarScrollbar`.
  final RaftSlotStyle sidebarScrollbar;
  /// Slot `sidebarLiveActivity`.
  final RaftSlotStyle sidebarLiveActivity;

  Map<String, RaftSlotStyle> get slots => {'sidebarRoot': sidebarRoot, 'sidebarHeader': sidebarHeader, 'sidebarHeaderMask': sidebarHeaderMask, 'sidebarHeaderMaskLayer': sidebarHeaderMaskLayer, 'sidebarHeaderTitle': sidebarHeaderTitle, 'sidebarGroupLabel': sidebarGroupLabel, 'sidebarBody': sidebarBody, 'sidebarContent': sidebarContent, 'sidebarViewport': sidebarViewport, 'sidebarContentInner': sidebarContentInner, 'sidebarScrollbar': sidebarScrollbar, 'sidebarLiveActivity': sidebarLiveActivity};
}

/// raft-ui recipe `sidebarRecipe` (`src/components/sidebar/sidebar.recipe.ts`, index.mjs:3151).
///
/// Used by: SidebarBody, SidebarContent, SidebarGroupLabel, SidebarHeader, SidebarHeaderTitle, SidebarLiveActivity, SidebarRoot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarRecipe {
  static const String recipeName = 'sidebarRecipe';
  static const List<String> slotNames = ['sidebarRoot', 'sidebarHeader', 'sidebarHeaderMask', 'sidebarHeaderMaskLayer', 'sidebarHeaderTitle', 'sidebarGroupLabel', 'sidebarBody', 'sidebarContent', 'sidebarViewport', 'sidebarContentInner', 'sidebarScrollbar', 'sidebarLiveActivity'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSidebarRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftSidebarRecipeStyle(sidebarRoot: s[0], sidebarHeader: s[1], sidebarHeaderMask: s[2], sidebarHeaderMaskLayer: s[3], sidebarHeaderTitle: s[4], sidebarGroupLabel: s[5], sidebarBody: s[6], sidebarContent: s[7], sidebarViewport: s[8], sidebarContentInner: s[9], sidebarScrollbar: s[10], sidebarLiveActivity: s[11]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 1620, 2890, 2560, 2834, 1622, 2042, 770, 2529],
    [1620, 2312, 1700, 1944, 2867, 875, 876, 770, 2756, 2396, 2451, 564],
    [2716, 580, 2304, 3036, 156, 2174],
    [580, 2304, 3036],
    [3092, 3004, 1684, 2976],
    [2751, 2733, 2683, 1689, 2918, 1688, 3096, 3056, 2981],
    [2775, 1620, 2560, 1621, 2656, 770, 2397],
    [2775, 1620, 2560, 2574, 1621],
    [2890, 2560, 1621, 2659, 2661],
    [2572, 2574, 3127, 2751, 2737, 2678],
    [3140, 1620, 3108, 2317, 2762, 2626, 3085, 1602, 2716, 1560, 1559, 1558],
    [2716, 580, 2304, 2428, 924, 3141],
    [1620, 2890, 2560, 2834, 1622, 2042, 2775, 820, 538, 2506, 2505, 2530],
    [1620, 2867, 2312, 1700, 580, 2304, 3036, 3139, 2309, 1943, 874, 850, 2745, 2546, 386],
    [2716, 580, 2304, 3036, 156, 862, 1973],
    [580, 2304, 3036, 1978, 1245, 1244, 1243, 1242, 1240, 1241, 1239, 1238],
    [3092, 1687, 2925, 1688, 2981],
    [2775, 1620, 2560, 1621, 2656, 820],
    [2572, 2574, 3127, 2678, 2745, 2546, 2730],
    [3140, 1620, 3108, 2762, 2626, 3085, 1602, 2716, 1560, 1559, 1558, 2318],
    [2716, 580, 2304, 2428, 929, 3138, 2704, 2724, 2120, 2114, 2119, 2111, 2121, 2118, 2116, 2115, 2113, 2112, 2117, 126, 127],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [12, 13, 14, 15, 16, 5, 17, 7, 8, 18, 19, 20],
  ];
}
