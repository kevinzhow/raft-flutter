// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageForwardedBundle`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageForwardedBundleRecipe].
class RaftMessageForwardedBundleRecipeStyle {
  const RaftMessageForwardedBundleRecipeStyle({
    required this.root,
    required this.header,
    required this.headerContent,
    required this.headerLabel,
    required this.headerCount,
    required this.source,
    required this.sourceLabel,
    required this.items,
    required this.footerAction,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `headerContent`.
  final RaftSlotStyle headerContent;

  /// Slot `headerLabel`.
  final RaftSlotStyle headerLabel;

  /// Slot `headerCount`.
  final RaftSlotStyle headerCount;

  /// Slot `source`.
  final RaftSlotStyle source;

  /// Slot `sourceLabel`.
  final RaftSlotStyle sourceLabel;

  /// Slot `items`.
  final RaftSlotStyle items;

  /// Slot `footerAction`.
  final RaftSlotStyle footerAction;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'headerContent': headerContent,
    'headerLabel': headerLabel,
    'headerCount': headerCount,
    'source': source,
    'sourceLabel': sourceLabel,
    'items': items,
    'footerAction': footerAction,
  };
}

/// raft-ui recipe `messageForwardedBundle` (`dist/components/message-forwarded-bundle/message-forwarded-bundle.recipe.mjs`, index.mjs:14146).
///
/// Used by: MessageForwardedBundle, MessageForwardedBundleFooterAction, MessageForwardedBundleHeader, MessageForwardedBundleHeaderContent, MessageForwardedBundleHeaderCount, MessageForwardedBundleHeaderLabel, MessageForwardedBundleItems, MessageForwardedBundleSource, MessageForwardedBundleSourceLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageForwardedBundleRecipe {
  static const String recipeName = 'messageForwardedBundle';
  static const List<String> slotNames = [
    'root',
    'header',
    'headerContent',
    'headerLabel',
    'headerCount',
    'source',
    'sourceLabel',
    'items',
    'footerAction',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('fullWidth', ['true', 'false'], null, true),
    RaftRecipeAxis('collapsed', ['true', 'false'], null, true),
  ];

  static RaftMessageForwardedBundleRecipeStyle resolve({
    bool? fullWidth,
    bool? collapsed,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [fullWidth?.toString(), collapsed?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageForwardedBundleRecipeStyle(
      root: s[0],
      header: s[1],
      headerContent: s[2],
      headerLabel: s[3],
      headerCount: s[4],
      source: s[5],
      sourceLabel: s[6],
      items: s[7],
      footerAction: s[8],
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
    [2145],
    [1400, 1408, 1864, 1868, 1466],
    [1400, 2116, 1864, 1466],
    [1847, 2499, 1864, 1464, 2597, 1449, 2603, 477],
    [2499, 1454, 2616, 2600],
    [
      2116,
      2681,
      1847,
      1864,
      1464,
      2457,
      2588,
      1457,
      2600,
      1338,
      2684,
      1798,
      1800,
      2247,
      1439,
      477,
    ],
    [2116, 2681, 1847, 1864, 1464, 2588, 2600, 477],
    [2433],
    [1847, 1864, 1464, 2457, 2597, 1457, 2598, 1338, 2684, 1800, 2247, 1439],
    [2433, 1913, 2251, 1909, 1333],
    [2145, 2725, 1983],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [0, 1, 2, 3, 4, 5, 6, 9, 8],
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [10, 1, 2, 3, 4, 5, 6, 7, 8],
    [10, 1, 2, 3, 4, 5, 6, 9, 8],
    [10, 1, 2, 3, 4, 5, 6, 7, 8],
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [0, 1, 2, 3, 4, 5, 6, 9, 8],
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
