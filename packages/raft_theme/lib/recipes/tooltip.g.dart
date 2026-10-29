// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `tooltip` (`src/components/tooltip/tooltip.tsx`, index.mjs:1295).
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
    [1727],
    [1317, 1944, 1630, 1577],
    [
      1630,
      1682,
      1304,
      1420,
      1484,
      1659,
      1668,
      1569,
      1577,
      1888,
      942,
      949,
      907,
      906,
      849,
      847,
      868,
      1505,
      1708,
      601,
      1829,
      1016,
      1013,
      1737,
      1235,
      1234,
    ],
    [
      618,
      1484,
      1799,
      1337,
      1932,
      1938,
      28,
      30,
      225,
      223,
      224,
      226,
      227,
      29,
      27,
      222,
    ],
    [1740, 166, 179, 177],
    [1484, 966],
    [1630, 965, 1584, 765, 752, 751, 761, 759, 763, 764, 758, 756, 754, 755],
    [
      1484,
      1799,
      1337,
      1932,
      1938,
      28,
      30,
      225,
      223,
      224,
      226,
      227,
      29,
      27,
      222,
      965,
      1319,
      1031,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 2, 7, 4, 5, 6],
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
