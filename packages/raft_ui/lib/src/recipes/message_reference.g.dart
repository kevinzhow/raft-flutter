// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageReference`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `messageReference` (default `muted`).
enum RaftMessageReferenceRecipeVariant {
  primary('primary'),
  secondary('secondary'),
  accent('accent'),
  muted('muted'),
  info('info'),
  link('link'),
  pending('pending'),
  unavailable('unavailable');

  const RaftMessageReferenceRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageReferenceRecipe].
class RaftMessageReferenceRecipeStyle {
  const RaftMessageReferenceRecipeStyle({required this.root, required this.chipLabel, required this.badge, required this.indicator});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `chipLabel`.
  final RaftSlotStyle chipLabel;
  /// Slot `badge`.
  final RaftSlotStyle badge;
  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'chipLabel': chipLabel, 'badge': badge, 'indicator': indicator};
}

/// raft-ui recipe `messageReference` (`src/components/message-item/message-reference.recipe.ts`, index.mjs:9756).
///
/// Used by: MessageReferenceBadge, MessageReferenceChip, MessageReferenceIndicator, MessageReferenceLabel, MessageReferencePending, MessageReferenceText, MessageReferenceUnavailable.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageReferenceRecipe {
  static const String recipeName = 'messageReference';
  static const List<String> slotNames = ['root', 'chipLabel', 'badge', 'indicator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['primary', 'secondary', 'accent', 'muted', 'info', 'link', 'pending', 'unavailable'], 'muted', false),
  ];

  static RaftMessageReferenceRecipeStyle resolve({required RaftRecipeTheme theme, RaftMessageReferenceRecipeVariant? variant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, variant?.css], states, tokens);
    return RaftMessageReferenceRecipeStyle(root: s[0], chipLabel: s[1], badge: s[2], indicator: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2311, 2760, 635, 576, 2340, 2484, 3092, 2835, 2611, 1639, 1647, 436, 427, 426, 2010, 2008, 2007, 2009, 1642, 2301, 939, 1696, 864, 876, 831, 2749, 1688, 2956, 2230, 2272],
    [2574, 3092],
    [2312, 3131, 2174],
    [2716, 580, 143, 3036, 2301, 2876, 2867, 2312, 2317, 105],
    [2311, 1696, 2760, 635, 576, 2340, 2484, 3092, 2835, 1639, 1647, 436, 427, 426, 2010, 2008, 2007, 2009, 1642, 2299, 939, 1684, 2956, 3093, 1579, 1577, 3094, 2275, 2262],
    [2311, 2760, 635, 576, 2340, 3092, 2835, 2611, 1639, 1647, 436, 427, 426, 2010, 2008, 2007, 2009, 1642, 2301, 2484, 939, 1696, 864, 876, 2749, 1688, 2956, 2071, 2068, 2070, 2069, 2060, 2053, 2058, 2059, 2062, 2061, 2056, 2055, 2054, 2057, 2050, 2052, 2049, 2051, 534, 781, 2203],
    [2311, 2760, 635, 576, 2340, 3092, 2835, 2611, 1639, 1647, 436, 427, 426, 2010, 2008, 2007, 2009, 1642, 2301, 2484, 939, 1696, 864, 876, 2749, 1688, 2956, 2071, 2068, 2070, 2069, 2060, 2053, 2058, 2059, 2062, 2061, 2056, 2055, 2054, 2057, 2050, 2052, 2049, 2051, 535, 784, 2206],
    [2311, 2760, 635, 576, 2340, 3092, 2835, 2611, 1639, 1647, 436, 427, 426, 2010, 2008, 2007, 2009, 1642, 2301, 2484, 939, 1696, 864, 876, 2749, 1688, 2956, 2071, 2068, 2070, 2069, 2060, 2053, 2058, 2059, 2062, 2061, 2056, 2055, 2054, 2057, 2050, 2052, 2049, 2051, 533, 774, 2198],
    [2311, 2760, 635, 576, 2340, 3092, 2835, 2611, 1639, 1647, 436, 427, 426, 2010, 2008, 2007, 2009, 1642, 2301, 2484, 939, 1696, 864, 876, 2749, 1688, 2071, 2068, 2070, 2069, 2060, 2053, 2058, 2059, 2062, 2061, 2056, 2055, 2054, 2057, 2050, 2052, 2049, 2051, 533, 774, 2956, 2198],
    [2311, 2760, 635, 576, 2340, 2484, 3092, 2835, 2611, 1639, 1647, 436, 427, 426, 2010, 2008, 2007, 2009, 1642, 2301, 943, 1696, 864, 876, 785, 2749, 1688, 2956, 2631],
    [2311, 2760, 635, 576, 2340, 2484, 3092, 2835, 2611, 1639, 1647, 436, 427, 426, 2010, 2008, 2007, 2009, 1642, 2301, 1696, 864, 876, 785, 2749, 1688, 2956, 2629],
    [2311, 2760, 635, 576, 2340, 2484, 3092, 2835, 2611, 1639, 1647, 1644, 436, 427, 426, 2010, 2008, 2007, 2009, 2301, 1695, 2815, 864, 916, 833, 2751, 942, 1690, 3053, 2936, 3075, 1601, 2224, 2270],
    [2301, 3131, 2716, 580, 151, 2789, 3137, 1972, 2312, 2816, 2820, 2722, 2699, 1690, 2344, 3053, 737, 2912, 574, 3072, 1605, 1613, 2593, 1905, 1859],
    [2311, 1696, 2760, 635, 576, 2340, 2484, 3092, 2835, 1639, 1647, 1644, 436, 427, 426, 2010, 2008, 2007, 2009, 2299, 942, 1688, 3093, 3094],
    [2311, 2760, 635, 576, 2340, 3092, 2835, 2611, 1639, 1647, 1644, 436, 427, 426, 2010, 2008, 2007, 2009, 529, 1726, 2775, 2301, 2484, 1696, 2815, 864, 916, 2721, 2699, 942, 1690, 3053, 3075, 1601, 2026, 2030, 2029, 2027, 2028, 1982, 2022, 2018, 2017, 2021, 2025, 2024, 2023, 2019, 2020, 2013, 2016, 2011, 2012, 2014, 2015, 530, 751, 2943, 2189, 2271, 981, 1161, 1098, 1114],
    [2311, 2760, 635, 576, 2340, 3092, 2835, 2611, 1639, 1647, 1644, 436, 427, 426, 2010, 2008, 2007, 2009, 529, 1726, 2775, 2301, 2484, 1696, 2815, 864, 2721, 2699, 942, 1690, 3053, 3075, 1601, 2026, 2030, 2029, 2027, 2028, 1982, 2022, 2018, 2017, 2021, 2025, 2024, 2023, 2019, 2020, 2013, 2016, 2011, 2012, 2014, 2015, 531, 896, 795, 2976, 2213],
    [2311, 2760, 635, 576, 2340, 3092, 2835, 2611, 1639, 1647, 1644, 436, 427, 426, 2010, 2008, 2007, 2009, 529, 1726, 2775, 2301, 2484, 1696, 2815, 864, 916, 2721, 2699, 942, 1690, 3053, 3075, 1601, 2026, 2030, 2029, 2027, 2028, 1982, 2022, 2018, 2017, 2021, 2025, 2024, 2023, 2019, 2020, 2013, 2016, 2011, 2012, 2014, 2015, 532, 753, 2999, 2190, 2281, 986, 1103],
    [2311, 2760, 635, 576, 2340, 2484, 3092, 2835, 2611, 1639, 1647, 1644, 436, 427, 426, 2010, 2008, 2007, 2009, 2301, 1697, 2815, 864, 916, 795, 2751, 943, 1690, 3053, 2981],
    [2311, 2760, 635, 576, 2340, 2484, 3092, 2835, 2611, 1639, 1647, 1644, 436, 427, 426, 2010, 2008, 2007, 2009, 2301, 1697, 2815, 864, 916, 795, 2751, 939, 1690, 3053, 2981],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 1, 2, 3], [5, 1, 2, 3], [6, 1, 2, 3], [7, 1, 2, 3], [8, 1, 2, 3], [9, 1, 2, 3], [10, 1, 2, 3], [11, 1, 12, 3], [13, 1, 12, 3], [14, 1, 12, 3], [15, 1, 12, 3], [14, 1, 12, 3], [16, 1, 12, 3], [17, 1, 12, 3], [18, 1, 12, 3],
  ];
}
