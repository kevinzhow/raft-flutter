// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `previewCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPreviewCardRecipe].
class RaftPreviewCardRecipeStyle {
  const RaftPreviewCardRecipeStyle({required this.trigger, required this.positioner, required this.popup, required this.header, required this.separator, required this.title, required this.description, required this.arrow});

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

  Map<String, RaftSlotStyle> get slots => {'trigger': trigger, 'positioner': positioner, 'popup': popup, 'header': header, 'separator': separator, 'title': title, 'description': description, 'arrow': arrow};
}

/// raft-ui recipe `previewCard` (`src/components/preview-card/preview-card.tsx`, index.mjs:6047).
///
/// Used by: PreviewCardArrow, PreviewCardContent, PreviewCardDescription, PreviewCardHeader, PreviewCardPopup, PreviewCardSeparator, PreviewCardTitle, PreviewCardTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPreviewCardRecipe {
  static const String recipeName = 'previewCard';
  static const List<String> slotNames = ['trigger', 'positioner', 'popup', 'header', 'separator', 'title', 'description', 'arrow'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftPreviewCardRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftPreviewCardRecipeStyle(trigger: s[0], positioner: s[1], popup: s[2], header: s[3], separator: s[4], title: s[5], description: s[6], arrow: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [],
    [2309, 3142, 2649],
    [2361, 2583, 2656, 2649, 2639, 3060, 2627, 3133, 3078, 1608, 1611, 1568, 1566, 1466, 1464, 1461, 1497, 2593, 866, 900, 828, 2861],
    [1620, 2314, 1700, 2753, 2737, 2683],
    [911, 900],
    [2359, 3092, 3017, 2344, 1691, 1684, 2987],
    [2359, 3092, 2753, 2765, 3032, 2335, 1691, 2995],
    [2876, 2805, 2174],
    [2361, 2583, 2656, 2649, 2639, 3060, 2627, 3133, 3078, 1608, 1611, 1568, 1566, 1466, 1464, 1461, 1497, 2593, 2818, 828, 2864],
    [911, 896, 1007],
    [2359, 3092, 3017, 2344, 1691, 1688, 2976],
    [2359, 3092, 2753, 2765, 3032, 2335, 816, 1691, 1002, 2977],
    [2876, 2805, 891, 911, 895, 828],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7], [0, 1, 8, 3, 9, 10, 11, 12],
  ];
}
