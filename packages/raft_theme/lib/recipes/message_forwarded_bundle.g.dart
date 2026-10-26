// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `messageForwardedBundle` (`src/components/message-forwarded-bundle/message-forwarded-bundle.recipe.ts`, index.mjs:9184).
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
    [1507, 1420],
    [965, 971, 1318, 1322, 1022],
    [965, 1481, 1318, 1022],
    [1304, 1736, 1318, 1020, 1817, 1007, 1823, 279],
    [1736, 1013, 1835, 1820],
    [
      1481,
      1893,
      1304,
      1318,
      1020,
      1700,
      1810,
      1016,
      1820,
      915,
      1896,
      1284,
      1287,
      1573,
      995,
      279,
    ],
    [1481, 1893, 1304, 1318, 1020, 1810, 1820, 279],
    [1678],
    [
      1304,
      1318,
      1020,
      1700,
      1817,
      1016,
      1818,
      1894,
      915,
      1896,
      1280,
      1573,
      995,
    ],
    [1678, 1359, 1578, 458, 442, 455, 449, 453, 444, 785, 452, 466, 464],
    [1507, 1924, 1425],
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
