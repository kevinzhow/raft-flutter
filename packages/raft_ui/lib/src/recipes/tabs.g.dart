// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `tabs`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `tabs` (default `default`).
enum RaftTabsRecipeVariant {
  default_('default'),
  underline('underline');

  const RaftTabsRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `placement` axis of `tabs` (default `top`).
enum RaftTabsRecipePlacement {
  top('top'),
  bottom('bottom'),
  left('left'),
  right('right');

  const RaftTabsRecipePlacement(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftTabsRecipe].
class RaftTabsRecipeStyle {
  const RaftTabsRecipeStyle({required this.root, required this.list, required this.background, required this.tab, required this.content, required this.label, required this.panel, required this.indicator});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `list`.
  final RaftSlotStyle list;
  /// Slot `background`.
  final RaftSlotStyle background;
  /// Slot `tab`.
  final RaftSlotStyle tab;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `label`.
  final RaftSlotStyle label;
  /// Slot `panel`.
  final RaftSlotStyle panel;
  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'list': list, 'background': background, 'tab': tab, 'content': content, 'label': label, 'panel': panel, 'indicator': indicator};
}

/// raft-ui recipe `tabs` (`src/components/tabs/tabs.tsx`, index.mjs:15753).
///
/// Used by: ConversationPanelTabs, SortableTabsTab, Tabs, TabsBackground, TabsIndicator, TabsLabel, TabsList, TabsPanel, TabsTab.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTabsRecipe {
  static const String recipeName = 'tabs';
  static const List<String> slotNames = ['root', 'list', 'background', 'tab', 'content', 'label', 'panel', 'indicator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['default', 'underline'], 'default', false),
    RaftRecipeAxis('placement', ['top', 'bottom', 'left', 'right'], 'top', false),
  ];

  static RaftTabsRecipeStyle resolve({required RaftRecipeTheme theme, RaftTabsRecipeVariant? variant, RaftTabsRecipePlacement? placement, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, variant?.css, placement?.css], states, tokens);
    return RaftTabsRecipeStyle(root: s[0], list: s[1], background: s[2], tab: s[3], content: s[4], label: s[5], panel: s[6], indicator: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [3127],
    [1620, 3128, 2484, 866, 900, 825, 2833, 173, 2658, 1354],
    [2174],
    [2775, 3138, 1620, 2867, 942, 3044, 2312, 1697, 3131, 2649, 1301, 1213, 825, 2755, 2763, 3032, 1692, 3084, 2187, 165, 166, 1212, 425, 427, 447, 462, 416, 1390, 1398, 1447, 1446, 169, 170, 172],
    [2775, 3138, 2301, 2312, 1705],
    [],
    [2649],
    [3127, 1620, 1622],
    [1620, 3128, 2484, 866, 900, 825, 2833, 173, 2637, 2658, 1354],
    [3127, 1620, 2314],
    [1620, 3128, 2484, 866, 900, 825, 2833, 173, 1622, 2661, 1355],
    [2775, 3138, 1620, 2867, 942, 3044, 2312, 1697, 3131, 2649, 1301, 1213, 825, 2755, 2763, 3032, 1692, 3084, 2187, 165, 166, 1212, 425, 427, 447, 462, 416, 1390, 1398, 1447, 1446, 2322, 168, 171, 167],
    [2649, 2574, 1621],
    [1620, 3128, 2484, 866, 900, 825, 2833, 173, 2637, 1622, 2661, 1355],
    [1934, 2775, 2309, 1620, 1976, 3128, 2484, 1696, 2664, 3131, 2677, 1352, 1353, 2833, 173, 2312, 2658, 2663, 1354],
    [2716, 580, 2303, 3137, 2811, 795, 995, 1143],
    [2775, 3138, 1620, 2867, 942, 3044, 2312, 3131, 2649, 1301, 1213, 1935, 1967, 1697, 2818, 2754, 2765, 2924, 1688, 3046, 2984, 3063, 1602, 1613, 2277, 1410, 1401, 1384, 2794, 1870, 1133, 1302, 1022, 1304, 1303, 1209, 1014, 1211, 1210, 425, 430, 427, 444, 452, 454, 422, 424, 2178, 1386, 1447, 1446, 2317],
    [580, 3137, 2818, 825, 2354, 3043, 1975, 3121, 2863, 2791, 2794, 983, 1870, 1133, 1609, 1612, 3077],
    [2637, 1934, 2775, 2309, 1620, 1976, 3128, 2484, 1696, 2664, 3131, 2677, 1352, 1353, 2833, 173, 2312, 2658, 2663, 1354],
    [1934, 2775, 2309, 1620, 1976, 3128, 2484, 1696, 2664, 3131, 2677, 1352, 1353, 2833, 173, 1622, 2315, 2661, 2660, 1355],
    [2775, 3138, 1620, 2867, 942, 3044, 2312, 3131, 2649, 1301, 1213, 1935, 1967, 1697, 2818, 2754, 2765, 2924, 1688, 3046, 2984, 3063, 1602, 1613, 2277, 1410, 1401, 1384, 2794, 1870, 1133, 1302, 1022, 1304, 1303, 1209, 1014, 1211, 1210, 425, 430, 427, 444, 452, 454, 422, 424, 2178, 1386, 1447, 1446, 2322],
    [580, 3137, 2818, 825, 2354, 3043, 1975, 3121, 2863, 2791, 2794, 983, 1870, 1133, 1609, 1612, 3079],
    [2637, 1934, 2775, 2309, 1620, 1976, 3128, 2484, 1696, 2664, 3131, 2677, 1352, 1353, 2833, 173, 1622, 2315, 2661, 2660, 1355],
    [1934, 2775, 1620, 3128, 2484, 1696, 2664, 3131, 895, 1352, 1353, 2833, 173, 1953, 2312, 2755, 2658, 2662, 1354, 873],
    [2716, 580, 3137, 829, 2304, 1979, 3036],
    [2775, 3138, 1620, 2867, 942, 3044, 2312, 1697, 3131, 2649, 1301, 1213, 1935, 2924, 1688, 3046, 2984, 3084, 1605, 1613, 2279, 1409, 1400, 425, 430, 427, 444, 452, 454, 423, 424, 2179, 1385, 1397, 1447, 1446, 1953, 2317, 2753, 2685, 2738],
    [580, 3138, 801, 1609, 1612, 2348, 1948, 3097, 3077, 924],
    [2637, 1934, 2775, 1620, 3128, 2484, 1696, 2664, 3131, 895, 1352, 1353, 2833, 173, 1953, 2312, 2755, 2658, 2662, 1354, 911],
    [2716, 580, 3137, 829, 2304, 1979, 924],
    [2775, 3138, 1620, 2867, 942, 3044, 2312, 1697, 3131, 2649, 1301, 1213, 1935, 2924, 1688, 3046, 2984, 3084, 1605, 1613, 2279, 1409, 1400, 425, 430, 427, 444, 452, 454, 423, 424, 2179, 1385, 1397, 1447, 1446, 1953, 2317, 2753, 2686, 2737],
    [580, 3138, 801, 1609, 1612, 2348, 1948, 3097, 3077, 3036],
    [1934, 2775, 1620, 3128, 2484, 1696, 2664, 3131, 895, 1352, 1353, 2833, 173, 1622, 2315, 2765, 2661, 2659, 1355, 906],
    [2716, 580, 3137, 829, 2306, 3129, 2350],
    [2775, 3138, 1620, 2867, 942, 3044, 2312, 1697, 3131, 2649, 1301, 1213, 1935, 2924, 1688, 3046, 2984, 3084, 1605, 1613, 2279, 1409, 1400, 425, 430, 427, 444, 452, 454, 423, 424, 2179, 1385, 1397, 1447, 1446, 1967, 2322, 2755],
    [580, 3138, 801, 1609, 1612, 3034, 1940, 3099, 3079, 2780],
    [2637, 1934, 2775, 1620, 3128, 2484, 1696, 2664, 3131, 895, 1352, 1353, 2833, 173, 1622, 2315, 2765, 2661, 2659, 1355, 891],
    [2716, 580, 3137, 829, 2306, 3129, 2780],
    [580, 3138, 801, 1609, 1612, 3034, 1940, 3099, 3079, 2350],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 5], [7, 8, 2, 3, 4, 5, 6, 5], [9, 10, 2, 11, 4, 5, 12, 5], [9, 13, 2, 11, 4, 5, 12, 5], [0, 1, 2, 3, 4, 5, 6, 5], [7, 8, 2, 3, 4, 5, 6, 5], [9, 10, 2, 11, 4, 5, 12, 5], [9, 13, 2, 11, 4, 5, 12, 5], [0, 14, 15, 16, 4, 5, 6, 17], [7, 18, 15, 16, 4, 5, 6, 17], [9, 19, 15, 20, 4, 5, 12, 21], [9, 22, 15, 20, 4, 5, 12, 21], [0, 23, 24, 25, 4, 5, 6, 26], [7, 27, 28, 29, 4, 5, 6, 30], [9, 31, 32, 33, 4, 5, 12, 34], [9, 35, 36, 33, 4, 5, 12, 37],
  ];
}
