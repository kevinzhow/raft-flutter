// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `tooltip`.
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

/// raft-ui recipe `tooltip` (`dist/components/tooltip/tooltip.mjs`, index.mjs:6812).
///
/// Used by: TooltipContent, TooltipTrigger.
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
  ];

  static RaftTooltipRecipeStyle resolve({
    bool? hasLeadingIcon,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [hasLeadingIcon?.toString()],
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
    [2483],
    [1862, 2746, 2346, 2247],
    [
      2346,
      2433,
      1846,
      1976,
      2116,
      2402,
      2414,
      2239,
      2247,
      2669,
      1366,
      1375,
      1326,
      1325,
      1201,
      1199,
      1248,
      2138,
      2461,
      914,
      2605,
      1456,
      1453,
      2496,
      1750,
      1749,
    ],
    [
      937,
      2116,
      2597,
      2728,
      2734,
      43,
      45,
      40,
      36,
      401,
      38,
      39,
      41,
      42,
      402,
      44,
      37,
    ],
    [2499, 335, 351, 348],
    [2116, 1401],
    [
      2346,
      1400,
      2253,
      1093,
      1080,
      1079,
      1089,
      1087,
      1091,
      1092,
      1086,
      1084,
      1082,
      1083,
    ],
    [
      2116,
      2597,
      2728,
      2734,
      43,
      45,
      40,
      36,
      401,
      38,
      39,
      41,
      42,
      402,
      44,
      37,
      1400,
      1864,
      1478,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 2, 7, 4, 5, 6],
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
