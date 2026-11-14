// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageCardRecipe].
class RaftMessageCardRecipeStyle {
  const RaftMessageCardRecipeStyle({
    required this.source,
    required this.sourceIcon,
    required this.sourceName,
    required this.sourceHost,
    required this.sourceHostText,
    required this.sourceFooter,
    required this.body,
    required this.eyebrow,
    required this.title,
    required this.heading,
    required this.meta,
    required this.actions,
    required this.actionRow,
    required this.actionGroup,
    required this.inset,
    required this.popover,
  });

  /// Slot `source`.
  final RaftSlotStyle source;

  /// Slot `sourceIcon`.
  final RaftSlotStyle sourceIcon;

  /// Slot `sourceName`.
  final RaftSlotStyle sourceName;

  /// Slot `sourceHost`.
  final RaftSlotStyle sourceHost;

  /// Slot `sourceHostText`.
  final RaftSlotStyle sourceHostText;

  /// Slot `sourceFooter`.
  final RaftSlotStyle sourceFooter;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `eyebrow`.
  final RaftSlotStyle eyebrow;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `heading`.
  final RaftSlotStyle heading;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  /// Slot `actionRow`.
  final RaftSlotStyle actionRow;

  /// Slot `actionGroup`.
  final RaftSlotStyle actionGroup;

  /// Slot `inset`.
  final RaftSlotStyle inset;

  /// Slot `popover`.
  final RaftSlotStyle popover;

  Map<String, RaftSlotStyle> get slots => {
    'source': source,
    'sourceIcon': sourceIcon,
    'sourceName': sourceName,
    'sourceHost': sourceHost,
    'sourceHostText': sourceHostText,
    'sourceFooter': sourceFooter,
    'body': body,
    'eyebrow': eyebrow,
    'title': title,
    'heading': heading,
    'meta': meta,
    'actions': actions,
    'actionRow': actionRow,
    'actionGroup': actionGroup,
    'inset': inset,
    'popover': popover,
  };
}

/// raft-ui recipe `messageCard` (`dist/components/message-embed/message-embed.recipe.mjs`, index.mjs:7021).
///
/// Used by: AppLinkCardActions, AppLinkCardBody, AppLinkCardEyebrow, AppLinkCardHeader, AppLinkCardHost, AppLinkCardIcon, AppLinkCardMeta, AppLinkCardName, AppLinkCardPlaceholder, AppLinkCardTitle, MessageActionCardActions, MessageActionCardContent, MessageActionCardHeader, PopoverActions, PopoverArrow, PopoverBackdrop, PopoverBody, PopoverClose, PopoverContent, PopoverDescription, PopoverHeader, PopoverPopup, PopoverSeparator, PopoverTitle, PopoverTrigger, PopoverViewport, PreviewCardActions, PreviewCardArrow, PreviewCardBody, PreviewCardContent, PreviewCardDescription, PreviewCardEyebrow, PreviewCardFooter, PreviewCardHeader, PreviewCardMeta, PreviewCardPopup, PreviewCardSeparator, PreviewCardTitle, PreviewCardTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageCardRecipe {
  static const String recipeName = 'messageCard';
  static const List<String> slotNames = [
    'source',
    'sourceIcon',
    'sourceName',
    'sourceHost',
    'sourceHostText',
    'sourceFooter',
    'body',
    'eyebrow',
    'title',
    'heading',
    'meta',
    'actions',
    'actionRow',
    'actionGroup',
    'inset',
    'popover',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageCardRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageCardRecipeStyle(
      source: s[0],
      sourceIcon: s[1],
      sourceName: s[2],
      sourceHost: s[3],
      sourceHostText: s[4],
      sourceFooter: s[5],
      body: s[6],
      eyebrow: s[7],
      title: s[8],
      heading: s[9],
      meta: s[10],
      actions: s[11],
      actionRow: s[12],
      actionGroup: s[13],
      inset: s[14],
      popover: s[15],
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
    [1400, 2116, 1864, 1465, 942, 953, 2403, 2417, 1456, 2588, 2603],
    [1847, 2517, 2499, 1864, 1869, 164, 163, 312, 311],
    [2116, 2681, 1457, 2598],
    [1400, 2116, 1863, 858, 847, 829],
    [2116, 2681],
    [1907, 2681, 960, 953, 2403, 2417, 1456, 2588, 2603],
    [1400, 2116, 1404, 1465, 2264],
    [1907, 2681, 1454, 2616, 2603],
    [1907, 1901, 1456, 2622, 1449, 2598, 419, 415, 420, 417, 418, 416],
    [1456, 2622, 1449, 2598],
    [1400, 2116, 1408, 1864, 1479, 1486, 1907, 1456, 2587, 2603],
    [1400, 1408, 1864, 1870, 1466, 2403, 2276],
    [1400, 1408, 1864, 1870, 1466],
    [1400, 2116, 1980, 1408, 1864, 1870, 1466, 2142],
    [2264],
    [2716, 1952],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  ];
}
