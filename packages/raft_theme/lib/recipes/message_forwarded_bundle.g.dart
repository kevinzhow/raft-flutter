// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageForwardedBundle`.
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

/// raft-ui recipe `messageForwardedBundle` (`src/components/message-forwarded-bundle/message-forwarded-bundle.recipe.ts`, index.mjs:11502).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('fullWidth', ['true', 'false'], null, true),
    RaftRecipeAxis('collapsed', ['true', 'false'], null, true),
  ];

  static RaftMessageForwardedBundleRecipeStyle resolve({
    required RaftRecipeTheme theme,
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
      [theme.name, fullWidth?.toString(), collapsed?.toString()],
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
    [2621, 2502],
    [1644, 1650, 2331, 2335, 1723],
    [1644, 2597, 2331, 1723],
    [2320, 2902, 2331, 1721, 2958, 1708, 2363, 3001],
    [2902, 2958, 1709, 2999],
    [
      2597,
      3133,
      2320,
      2331,
      1721,
      2958,
      1709,
      3135,
      3125,
      2998,
      2291,
      2307,
      1663,
      1671,
      1666,
    ],
    [2597, 3133, 2320, 2331, 1721, 2958, 1709, 2997],
    [2804],
    [2320, 2331, 1721, 2958, 1708, 3134, 3135, 3000, 2291, 1663, 1671, 1666],
    [2804, 2382, 2678, 632, 619, 630, 623, 627, 620, 1390, 626, 640, 638],
    [2621, 3168, 2508],
    [2320, 2902, 2331, 1721, 2958, 1713, 2363, 3018],
    [2902, 2958, 1713, 3021],
    [
      2597,
      3133,
      2320,
      2331,
      1721,
      2958,
      1713,
      3125,
      3021,
      2299,
      1663,
      1671,
      1668,
    ],
    [2597, 3133, 2320, 2331, 1721, 2958, 1713, 3021],
    [2320, 2331, 1721, 2958, 1713, 3021, 2299, 1663, 1671, 1668],
    [2804, 2382, 2678, 632, 619, 630, 623, 627, 620, 1390, 625, 639, 637],
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
    [0, 1, 2, 11, 12, 13, 14, 7, 15],
    [0, 1, 2, 11, 12, 13, 14, 16, 15],
    [0, 1, 2, 11, 12, 13, 14, 7, 15],
    [10, 1, 2, 11, 12, 13, 14, 7, 15],
    [10, 1, 2, 11, 12, 13, 14, 16, 15],
    [10, 1, 2, 11, 12, 13, 14, 7, 15],
    [0, 1, 2, 11, 12, 13, 14, 7, 15],
    [0, 1, 2, 11, 12, 13, 14, 16, 15],
    [0, 1, 2, 11, 12, 13, 14, 7, 15],
  ];
}
