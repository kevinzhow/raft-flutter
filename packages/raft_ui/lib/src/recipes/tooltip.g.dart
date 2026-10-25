// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `tooltip`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTooltipRecipe].
class RaftTooltipRecipeStyle {
  const RaftTooltipRecipeStyle({
    required this.trigger,
    required this.positioner,
    required this.content,
    required this.body,
    required this.bodyIcon,
    required this.bodyText,
    required this.arrow,
  });

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `positioner`.
  final RaftSlotStyle positioner;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `bodyIcon`.
  final RaftSlotStyle bodyIcon;

  /// Slot `bodyText`.
  final RaftSlotStyle bodyText;

  /// Slot `arrow`.
  final RaftSlotStyle arrow;

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'positioner': positioner,
    'content': content,
    'body': body,
    'bodyIcon': bodyIcon,
    'bodyText': bodyText,
    'arrow': arrow,
  };
}

/// raft-ui recipe `tooltip` (`src/components/tooltip/tooltip.tsx`, index.mjs:1404).
///
/// Used by: FloatButton, MessageReactionTooltipContent, TooltipContent, TooltipTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTooltipRecipe {
  static const String recipeName = 'tooltip';
  static const List<String> slotNames = [
    'trigger',
    'positioner',
    'content',
    'body',
    'bodyIcon',
    'bodyText',
    'arrow',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('hasLeadingIcon', ['true', 'false'], null, true),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTooltipRecipeStyle resolve({
    bool? hasLeadingIcon,
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [hasLeadingIcon?.toString(), theme.name],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftTooltipRecipeStyle(
      trigger: s[0],
      positioner: s[1],
      content: s[2],
      body: s[3],
      bodyIcon: s[4],
      bodyText: s[5],
      arrow: s[6],
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
    [2868],
    [2328, 3183, 2739, 2672],
    [
      2739,
      2804,
      2319,
      2500,
      2597,
      2780,
      2791,
      2662,
      2672,
      3119,
      1626,
      1635,
      1592,
      1590,
      1488,
      1486,
      1521,
      2616,
      2112,
      2111,
      878,
      916,
      836,
      1716,
      1709,
      3024,
      2897,
      40,
      38,
      45,
      43,
    ],
    [
      874,
      2597,
      2962,
      2353,
      3171,
      3177,
      42,
      47,
      381,
      379,
      380,
      382,
      383,
      44,
      378,
      41,
    ],
    [2902, 289, 300, 298],
    [2597, 1645],
    [
      2739,
      2680,
      1369,
      1356,
      1355,
      1365,
      1363,
      1367,
      1368,
      1362,
      1360,
      1358,
      1359,
      2189,
    ],
    [
      2739,
      2804,
      2319,
      2500,
      2597,
      2780,
      2791,
      2662,
      2672,
      3119,
      1626,
      1635,
      1592,
      1590,
      1488,
      1486,
      1521,
      2616,
      2112,
      2111,
      2848,
      827,
      3039,
      1017,
      1182,
      1716,
      2962,
      1713,
      3087,
      2895,
      39,
      46,
      43,
      966,
      967,
    ],
    [
      2739,
      1644,
      2680,
      1369,
      1356,
      1355,
      1365,
      1363,
      1367,
      1368,
      1362,
      1360,
      1358,
      1359,
      1081,
    ],
    [
      2597,
      2962,
      2353,
      3171,
      3177,
      42,
      47,
      381,
      379,
      380,
      382,
      383,
      44,
      378,
      41,
      1644,
      2331,
      1731,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 7, 3, 4, 5, 8],
    [0, 1, 2, 9, 4, 5, 6],
    [0, 1, 7, 9, 4, 5, 8],
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 7, 3, 4, 5, 8],
  ];
}
