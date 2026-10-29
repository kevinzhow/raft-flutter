// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `previewCard`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `previewCard` (`src/components/preview-card/preview-card.tsx`, index.mjs:6059).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftPreviewCardRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
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
    [2328, 3183, 2672],
    [
      2380,
      2606,
      2679,
      2672,
      2662,
      3101,
      2650,
      3174,
      3119,
      1632,
      1635,
      1592,
      1590,
      1488,
      1486,
      1483,
      1521,
      2616,
      878,
      916,
      833,
      2895,
    ],
    [1644, 2333, 1725, 2781, 2762, 2706],
    [925, 916],
    [2378, 3133, 3053, 2363, 1716, 1709, 3024],
    [2378, 3133, 2781, 2794, 3073, 2354, 1716, 3032],
    [2911, 2835, 2189],
    [
      2380,
      2606,
      2679,
      2672,
      2662,
      3101,
      2650,
      3174,
      3119,
      1632,
      1635,
      1592,
      1590,
      1488,
      1486,
      1483,
      1521,
      2616,
      2848,
      833,
      2898,
    ],
    [925, 912, 1027],
    [2378, 3133, 3053, 2363, 1716, 1713, 3013],
    [2378, 3133, 2781, 2794, 3073, 2354, 822, 1716, 1022, 3014],
    [2911, 2835, 907, 925, 911, 833],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 8, 3, 9, 10, 11, 12],
  ];
}
