// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `previewCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `previewCard` (default `profile`).
enum RaftPreviewCardRecipeSize {
  profile('profile'),
  item('item');

  const RaftPreviewCardRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

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

/// raft-ui recipe `previewCard` (`dist/components/preview-card/preview-card.mjs`, index.mjs:7248).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['profile', 'item'], 'profile', false),
  ];

  static RaftPreviewCardRecipeStyle resolve({
    RaftPreviewCardRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css],
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
    [1862, 2746, 2247],
    [
      1911,
      2128,
      2252,
      2247,
      2239,
      2657,
      2229,
      2731,
      2669,
      1370,
      1375,
      1326,
      1325,
      1201,
      1199,
      1194,
      1248,
      2138,
      2462,
      915,
      2598,
      2496,
      2445,
      2449,
      2713,
    ],
    [1400, 1866, 1468, 2405, 2384, 2276, 1877],
    [960, 953],
    [1907, 2681, 1456, 2609, 1449, 2598],
    [1907, 2681, 2405, 2419, 1877, 1456, 2587, 2603],
    [2513, 2451, 950, 960, 954, 915],
    [
      1911,
      2128,
      2252,
      2247,
      2239,
      2657,
      2229,
      2731,
      2669,
      1370,
      1375,
      1326,
      1325,
      1201,
      1199,
      1194,
      1248,
      2138,
      2462,
      915,
      2598,
      2496,
      2445,
      2449,
      2716,
      1952,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 8, 3, 4, 5, 6, 7],
  ];
}
