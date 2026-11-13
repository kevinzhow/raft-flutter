// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `panel`.
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
  const RaftPanelRecipeStyle({
    required this.root,
    required this.header,
    required this.body,
    required this.scrollViewport,
    required this.nativeScrollViewport,
    required this.scrollContent,
    required this.section,
    required this.footer,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `scrollViewport`.
  final RaftSlotStyle scrollViewport;

  /// Slot `nativeScrollViewport`.
  final RaftSlotStyle nativeScrollViewport;

  /// Slot `scrollContent`.
  final RaftSlotStyle scrollContent;

  /// Slot `section`.
  final RaftSlotStyle section;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'body': body,
    'scrollViewport': scrollViewport,
    'nativeScrollViewport': nativeScrollViewport,
    'scrollContent': scrollContent,
    'section': section,
    'footer': footer,
  };
}

/// raft-ui recipe `panel` (`dist/components/panel/panel.recipe.mjs`, index.mjs:5141).
///
/// Used by: MessageList, Panel, PanelBody, PanelFooter, PanelHeaderRoot, PanelScrollContent, PanelScrollViewport, PanelSection.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelRecipe {
  static const String recipeName = 'panel';
  static const List<String> slotNames = [
    'root',
    'header',
    'body',
    'scrollViewport',
    'nativeScrollViewport',
    'scrollContent',
    'section',
    'footer',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('edge', ['inset', 'attached'], null, true),
  ];

  static RaftPanelRecipeStyle resolve({
    RaftPanelRecipeEdge? edge,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [edge?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftPanelRecipeStyle(
      root: s[0],
      header: s[1],
      body: s[2],
      scrollViewport: s[3],
      nativeScrollViewport: s[4],
      scrollContent: s[5],
      section: s[6],
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
    [567, 910, 2598],
    [609],
    [2433, 2098, 1401, 2252],
    [1678, 2098, 685],
    [1678, 2098, 2256, 2258, 685, 602],
    [2112],
    [960, 2396, 2421, 953],
    [2433, 1400, 2499, 1864, 2383, 910, 2394, 2284, 1943],
    [567, 910, 2598, 1617],
    [567, 910, 2598, 1617, 950, 954, 1933],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 1, 2, 3, 4, 5, 6, 7],
    [9, 1, 2, 3, 4, 5, 6, 7],
  ];
}
