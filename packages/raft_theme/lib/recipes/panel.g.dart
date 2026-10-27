// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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
  const RaftPanelRecipeStyle({
    required this.root,
    required this.header,
    required this.body,
    required this.scrollViewport,
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
    'scrollContent': scrollContent,
    'section': section,
    'footer': footer,
  };
}

/// raft-ui recipe `panel` (`src/components/panel/panel.recipe.ts`, index.mjs:3462).
///
/// Used by: ActivityInboxPanel, MessageActionCardContent, Panel, PanelBody, PanelFooter, PanelHeaderRoot, PanelScrollContent, PanelScrollViewport, PanelSection, ResizablePanel, TabsPanel, TaskBoardColumnPanel, TaskSectionPanel.
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
      scrollContent: s[4],
      section: s[5],
      footer: s[6],
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
    [341, 595, 1820],
    [385],
    [1680, 1467, 966, 1581],
    [1198, 1467, 1585, 1587, 420, 380],
    [1482],
    [639, 1661, 1673, 633],
    [1680, 965, 1738, 1319, 1645, 595, 1661, 1392, 1609, 1387],
    [341, 595, 1820, 1154],
    [341, 595, 1820, 1154, 630, 634, 1379],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [7, 1, 2, 3, 4, 5, 6],
    [8, 1, 2, 3, 4, 5, 6],
  ];
}
