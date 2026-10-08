// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `panelHeader`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `panelHeader`.
enum RaftPanelHeaderRecipeSize {
  sm('sm'),
  md('md');

  const RaftPanelHeaderRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftPanelHeaderRecipe].
class RaftPanelHeaderRecipeStyle {
  const RaftPanelHeaderRecipeStyle({required this.header, required this.sectionHeader, required this.headerIcon, required this.headerContent, required this.heading, required this.title, required this.meta, required this.status, required this.activity, required this.actions});

  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `sectionHeader`.
  final RaftSlotStyle sectionHeader;
  /// Slot `headerIcon`.
  final RaftSlotStyle headerIcon;
  /// Slot `headerContent`.
  final RaftSlotStyle headerContent;
  /// Slot `heading`.
  final RaftSlotStyle heading;
  /// Slot `title`.
  final RaftSlotStyle title;
  /// Slot `meta`.
  final RaftSlotStyle meta;
  /// Slot `status`.
  final RaftSlotStyle status;
  /// Slot `activity`.
  final RaftSlotStyle activity;
  /// Slot `actions`.
  final RaftSlotStyle actions;

  Map<String, RaftSlotStyle> get slots => {'header': header, 'sectionHeader': sectionHeader, 'headerIcon': headerIcon, 'headerContent': headerContent, 'heading': heading, 'title': title, 'meta': meta, 'status': status, 'activity': activity, 'actions': actions};
}

/// raft-ui recipe `panelHeader` (`src/components/panel/panel-header.recipe.ts`, index.mjs:16643).
///
/// Used by: PanelActions, PanelActivity, PanelHeader, PanelHeaderContent, PanelHeaderIcon, PanelHeading, PanelMeta, PanelSectionHeader, PanelStatus, PanelTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelHeaderRecipe {
  static const String recipeName = 'panelHeader';
  static const List<String> slotNames = ['header', 'sectionHeader', 'headerIcon', 'headerContent', 'heading', 'title', 'meta', 'status', 'activity', 'actions'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('size', ['sm', 'md'], null, true),
  ];

  static RaftPanelHeaderRecipeStyle resolve({required RaftRecipeTheme theme, RaftPanelHeaderRecipeSize? size, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, size?.css], states, tokens);
    return RaftPanelHeaderRecipeStyle(header: s[0], sectionHeader: s[1], headerIcon: s[2], headerContent: s[3], heading: s[4], title: s[5], meta: s[6], status: s[7], activity: s[8], actions: s[9]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2457, 2458, 2462, 1620, 1944, 2867, 2312, 1700, 875, 876, 856, 2756],
    [2457, 2458, 2462, 1620, 1944, 2867, 2312, 1700, 875, 876, 856, 2756, 2394, 2396, 563, 2389, 2499, 2498, 2388],
    [1620, 2886, 2867, 2312, 2317, 866, 876, 831, 2956],
    [2574, 1621, 1620, 1622, 2035, 2036, 2037, 2034, 2038, 2031, 2033, 2032],
    [1620, 2574, 2312, 1698],
    [3092, 2955, 1684, 2347, 2956],
    [2574, 3092, 1689, 3032, 2961],
    [2301, 2867, 2312, 1696, 2750, 2762, 2920, 1684, 3096, 2344, 438, 427, 866, 876, 778, 2956],
    [2301, 2867, 2312, 1697, 3032, 2344, 438, 427, 2956],
    [1620, 2867, 2312, 1697, 2409, 398],
    [2574, 3092, 1689, 2961, 3017],
    [2457, 2458, 1620, 2867, 2312, 1698, 2775, 2309, 1976, 2559, 2461, 565, 874, 850, 2395, 2411, 2412, 2413, 2429, 2747, 2440, 2443, 2544, 2545, 2392, 2391],
    [2457, 2458, 1620, 2867, 2312, 1698, 2775, 2309, 1976, 2559, 2461, 565, 874, 850, 2395, 2411, 2412, 2413, 2429, 2747, 2440, 2443, 2544, 2545, 2392, 2391, 2394],
    [1620, 2867, 2312, 2317, 2886, 2818, 865, 795, 2978, 2401, 2454, 2455],
    [2574, 1621, 1620, 1622, 2517, 2534, 2522, 2528, 2400, 2454, 2433, 2408, 2455, 2423, 2424, 2425, 2422, 2427, 2416, 2419, 2417, 2418, 2421, 2420, 2426, 2415, 2527],
    [1620, 2574, 2312, 1698, 2538, 2556],
    [3092, 1687, 2925, 1688, 2347, 3054, 2911, 2981],
    [2574, 3092, 3032, 1691, 2344, 2984, 2431, 2514, 2510],
    [2301, 2867, 2312, 1696, 2920, 1684, 3096, 2344, 427, 865, 850, 2667, 2984, 439],
    [2301, 2867, 2312, 1697, 3032, 2344, 427, 2984, 439],
    [1620, 2867, 2312, 1697, 2407, 2402, 2454, 2455, 399],
    [2574, 3092, 1691, 2984, 2431, 2514, 2510, 3017],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [0, 1, 2, 3, 4, 5, 10, 7, 8, 9], [11, 12, 13, 14, 15, 16, 17, 18, 19, 20], [11, 12, 13, 14, 15, 16, 17, 18, 19, 20], [11, 12, 13, 14, 15, 16, 21, 18, 19, 20],
  ];
}
