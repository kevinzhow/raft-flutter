// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `previewCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPreviewCardRecipe].
class RaftPreviewCardRecipeStyle {
  const RaftPreviewCardRecipeStyle({
    required this.trigger,
    required this.positioner,
    required this.popup,
    required this.header,
    required this.separator,
    required this.title,
    required this.description,
    required this.arrow,
  });

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `positioner`.
  final RaftSlotStyle positioner;

  /// Slot `popup`.
  final RaftSlotStyle popup;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `separator`.
  final RaftSlotStyle separator;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `arrow`.
  final RaftSlotStyle arrow;

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'positioner': positioner,
    'popup': popup,
    'header': header,
    'separator': separator,
    'title': title,
    'description': description,
    'arrow': arrow,
  };
}

/// raft-ui recipe `previewCard` (`src/components/preview-card/preview-card.tsx`, index.mjs:4857).
///
/// Used by: PreviewCardArrow, PreviewCardContent, PreviewCardDescription, PreviewCardHeader, PreviewCardPopup, PreviewCardSeparator, PreviewCardTitle, PreviewCardTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPreviewCardRecipe {
  static const String recipeName = 'previewCard';
  static const List<String> slotNames = [
    'trigger',
    'positioner',
    'popup',
    'header',
    'separator',
    'title',
    'description',
    'arrow',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftPreviewCardRecipeStyle resolve({
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
    return RaftPreviewCardRecipeStyle(
      trigger: s[0],
      positioner: s[1],
      popup: s[2],
      header: s[3],
      separator: s[4],
      title: s[5],
      description: s[6],
      arrow: s[7],
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
    [],
    [1317, 1941, 1575],
    [
      1358,
      1494,
      1581,
      1575,
      1567,
      1875,
      1557,
      1932,
      1886,
      946,
      949,
      907,
      906,
      849,
      847,
      843,
      868,
      1503,
      1914,
      1707,
      602,
      1820,
      1735,
      1692,
      1696,
    ],
    [965, 1321, 1025, 1660, 1646, 1605, 1331],
    [639, 633],
    [1357, 1895, 1016, 1831, 1008, 1820],
    [1357, 1895, 1660, 1671, 1331, 1016, 1811, 1825],
    [1748, 1698, 630, 639, 634, 602],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
