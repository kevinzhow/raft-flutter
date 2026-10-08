// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageForwardedBundle`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageForwardedBundleRecipe].
class RaftMessageForwardedBundleRecipeStyle {
  const RaftMessageForwardedBundleRecipeStyle({required this.root, required this.header, required this.headerContent, required this.headerLabel, required this.headerCount, required this.source, required this.sourceLabel, required this.items, required this.footerAction});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'headerContent': headerContent, 'headerLabel': headerLabel, 'headerCount': headerCount, 'source': source, 'sourceLabel': sourceLabel, 'items': items, 'footerAction': footerAction};
}

/// raft-ui recipe `messageForwardedBundle` (`src/components/message-forwarded-bundle/message-forwarded-bundle.recipe.ts`, index.mjs:11459).
///
/// Used by: MessageForwardedBundle, MessageForwardedBundleFooterAction, MessageForwardedBundleHeader, MessageForwardedBundleHeaderContent, MessageForwardedBundleHeaderCount, MessageForwardedBundleHeaderLabel, MessageForwardedBundleItems, MessageForwardedBundleSource, MessageForwardedBundleSourceLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageForwardedBundleRecipe {
  static const String recipeName = 'messageForwardedBundle';
  static const List<String> slotNames = ['root', 'header', 'headerContent', 'headerLabel', 'headerCount', 'source', 'sourceLabel', 'items', 'footerAction'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('fullWidth', ['true', 'false'], null, true),
    RaftRecipeAxis('collapsed', ['true', 'false'], null, true),
  ];

  static RaftMessageForwardedBundleRecipeStyle resolve({required RaftRecipeTheme theme, bool? fullWidth, bool? collapsed, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, fullWidth?.toString(), collapsed?.toString()], states, tokens);
    return RaftMessageForwardedBundleRecipeStyle(root: s[0], header: s[1], headerContent: s[2], headerLabel: s[3], headerCount: s[4], source: s[5], sourceLabel: s[6], items: s[7], footerAction: s[8]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2598, 2481],
    [1620, 1626, 2312, 2316, 1698],
    [1620, 2574, 2312, 1698],
    [2301, 2867, 2312, 1696, 2920, 1683, 2344, 2964],
    [2867, 2920, 1684, 2962],
    [2574, 3092, 2301, 2312, 1696, 2920, 1684, 3094, 3084, 2961, 2272, 2288, 1639, 1647, 1642],
    [2574, 3092, 2301, 2312, 1696, 2920, 1684, 2960],
    [2775],
    [2301, 2312, 1696, 2920, 1683, 3093, 3094, 2963, 2272, 1639, 1647, 1642],
    [2775, 2363, 2655, 626, 613, 624, 617, 621, 614, 1368, 620, 634, 632],
    [2598, 3127, 2487],
    [2301, 2867, 2312, 1696, 2920, 1688, 2344, 2981],
    [2867, 2920, 1688, 2984],
    [2574, 3092, 2301, 2312, 1696, 2920, 1688, 3084, 2984, 2280, 1639, 1647, 1644],
    [2574, 3092, 2301, 2312, 1696, 2920, 1688, 2984],
    [2301, 2312, 1696, 2920, 1688, 2984, 2280, 1639, 1647, 1644],
    [2775, 2363, 2655, 626, 613, 624, 617, 621, 614, 1368, 619, 633, 631],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8], [0, 1, 2, 3, 4, 5, 6, 9, 8], [0, 1, 2, 3, 4, 5, 6, 7, 8], [10, 1, 2, 3, 4, 5, 6, 7, 8], [10, 1, 2, 3, 4, 5, 6, 9, 8], [10, 1, 2, 3, 4, 5, 6, 7, 8], [0, 1, 2, 3, 4, 5, 6, 7, 8], [0, 1, 2, 3, 4, 5, 6, 9, 8], [0, 1, 2, 3, 4, 5, 6, 7, 8], [0, 1, 2, 11, 12, 13, 14, 7, 15], [0, 1, 2, 11, 12, 13, 14, 16, 15], [0, 1, 2, 11, 12, 13, 14, 7, 15], [10, 1, 2, 11, 12, 13, 14, 7, 15], [10, 1, 2, 11, 12, 13, 14, 16, 15], [10, 1, 2, 11, 12, 13, 14, 7, 15], [0, 1, 2, 11, 12, 13, 14, 7, 15],
    [0, 1, 2, 11, 12, 13, 14, 16, 15], [0, 1, 2, 11, 12, 13, 14, 7, 15],
  ];
}
