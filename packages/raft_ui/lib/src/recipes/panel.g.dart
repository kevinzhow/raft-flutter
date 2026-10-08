// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `panel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `edge` axis of `panel`.
enum RaftPanelRecipeEdge {
  inset('inset'),
  attached('attached');

  const RaftPanelRecipeEdge(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftPanelRecipe].
class RaftPanelRecipeStyle {
  const RaftPanelRecipeStyle({required this.root, required this.header, required this.body, required this.scrollViewport, required this.scrollContent, required this.section, required this.footer});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `body`.
  final RaftSlotStyle body;
  /// Slot `scrollViewport`.
  final RaftSlotStyle scrollViewport;
  /// Slot `scrollContent`.
  final RaftSlotStyle scrollContent;
  /// Slot `section`.
  final RaftSlotStyle section;
  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'body': body, 'scrollViewport': scrollViewport, 'scrollContent': scrollContent, 'section': section, 'footer': footer};
}

/// raft-ui recipe `panel` (`src/components/panel/panel.recipe.ts`, index.mjs:4350).
///
/// Used by: ActivityInboxPanel, Panel, PanelBody, PanelFooter, PanelHeaderRoot, PanelScrollContent, PanelScrollViewport, PanelSection, ResizablePanel, TabsPanel, TaskBoardColumnPanel, TaskSectionPanel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelRecipe {
  static const String recipeName = 'panel';
  static const List<String> slotNames = ['root', 'header', 'body', 'scrollViewport', 'scrollContent', 'section', 'footer'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('edge', ['inset', 'attached'], null, true),
  ];

  static RaftPanelRecipeStyle resolve({required RaftRecipeTheme theme, RaftPanelRecipeEdge? edge, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, edge?.css], states, tokens);
    return RaftPanelRecipeStyle(root: s[0], header: s[1], body: s[2], scrollViewport: s[3], scrollContent: s[4], section: s[5], footer: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [509, 2987],
    [564],
    [2775, 2560, 1621, 2656],
    [1978, 2560, 2661, 2664, 578, 559],
    [2572],
    [911, 889, 2756, 2769],
    [2775, 1620, 2867, 2312, 2753, 2448, 2737, 2690, 2438],
    [509, 2987, 1928],
    [509, 2987, 1928, 892, 876, 123, 124],
    [2572, 2543],
    [2775, 1620, 2867, 2312, 2753, 2737, 2690, 3141, 2509, 2533, 2512, 2449, 2550, 2444, 2547, 2439, 2542, 912, 850, 718, 688, 711, 701, 731, 707, 696, 689, 965, 964, 714, 687, 715, 686, 703, 126, 127],
    [509, 2987, 1928, 891, 896, 122, 125],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [7, 1, 2, 3, 4, 5, 6], [8, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 9, 5, 10], [7, 1, 2, 3, 9, 5, 10], [11, 1, 2, 3, 9, 5, 10],
  ];
}
