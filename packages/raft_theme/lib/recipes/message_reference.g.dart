// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageReference`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `messageReference` (default `muted`).
enum RaftMessageReferenceRecipeVariant {
  primary('primary'),
  secondary('secondary'),
  accent('accent'),
  muted('muted'),
  info('info'),
  link('link'),
  pending('pending'),
  unavailable('unavailable');

  const RaftMessageReferenceRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageReferenceRecipe].
class RaftMessageReferenceRecipeStyle {
  const RaftMessageReferenceRecipeStyle({
    required this.root,
    required this.chipLabel,
    required this.indicator,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `chipLabel`.
  final RaftSlotStyle chipLabel;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'chipLabel': chipLabel,
    'indicator': indicator,
  };
}

/// raft-ui recipe `messageReference` (`src/components/message-item/message-reference.recipe.ts`, index.mjs:7705).
///
/// Used by: MessageReferenceChip, MessageReferenceIndicator, MessageReferenceLabel, MessageReferencePending, MessageReferenceText, MessageReferenceUnavailable.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageReferenceRecipe {
  static const String recipeName = 'messageReference';
  static const List<String> slotNames = ['root', 'chipLabel', 'indicator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'variant',
      [
        'primary',
        'secondary',
        'accent',
        'muted',
        'info',
        'link',
        'pending',
        'unavailable',
      ],
      'muted',
      false,
    ),
  ];

  static RaftMessageReferenceRecipeStyle resolve({
    RaftMessageReferenceRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageReferenceRecipeStyle(
      root: s[0],
      chipLabel: s[1],
      indicator: s[2],
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
    [
      1318,
      1021,
      1666,
      468,
      417,
      1342,
      1424,
      1897,
      1728,
      1577,
      996,
      286,
      277,
      276,
      1210,
      1208,
      1207,
      1209,
      1305,
      664,
      1716,
      1665,
      1017,
      1844,
      1528,
      575,
      1310,
      1313,
      1695,
      1699,
      1284,
    ],
    [1484, 1897],
    [1630, 422, 103, 1862, 1305, 1750, 1740, 1319, 1324, 82],
    [
      1318,
      1021,
      1666,
      468,
      417,
      1342,
      1424,
      1897,
      1728,
      1577,
      996,
      286,
      277,
      276,
      1210,
      1208,
      1207,
      1209,
      1303,
      664,
      1008,
      1822,
      1898,
      916,
      915,
      1900,
      1282,
    ],
    [
      1305,
      1666,
      1424,
      1897,
      1728,
      1528,
      1577,
      996,
      277,
      276,
      1210,
      1208,
      1207,
      1209,
      1191,
      1319,
      1020,
      1716,
      1657,
      1219,
      467,
      416,
      1338,
      1017,
      279,
      294,
      572,
      1822,
      664,
      1283,
      429,
    ],
    [
      1305,
      1666,
      1424,
      1897,
      1728,
      1528,
      1577,
      996,
      277,
      276,
      1210,
      1208,
      1207,
      1209,
      1191,
      1319,
      1020,
      1716,
      1657,
      1219,
      467,
      416,
      1338,
      1017,
      279,
      294,
      591,
      1822,
      664,
      1283,
      429,
    ],
    [
      1305,
      1666,
      1424,
      1897,
      1728,
      1528,
      1577,
      996,
      277,
      276,
      1210,
      1208,
      1207,
      1209,
      1191,
      1319,
      1020,
      1716,
      1657,
      1219,
      467,
      416,
      1338,
      1017,
      279,
      294,
      593,
      1822,
      664,
      1283,
      429,
    ],
    [
      1305,
      1666,
      1424,
      1897,
      1728,
      1528,
      1577,
      996,
      277,
      276,
      1210,
      1208,
      1207,
      1209,
      1191,
      1319,
      1020,
      1716,
      1657,
      1219,
      467,
      416,
      1338,
      1017,
      279,
      294,
      665,
      591,
      1827,
    ],
    [
      1305,
      1666,
      1424,
      1897,
      1728,
      1528,
      1577,
      996,
      277,
      276,
      1210,
      1208,
      1207,
      1209,
      1191,
      1319,
      1020,
      1716,
      1657,
      1219,
      467,
      416,
      1338,
      1017,
      279,
      294,
      660,
      591,
      1824,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 1, 2],
    [4, 1, 2],
    [5, 1, 2],
    [6, 1, 2],
    [6, 1, 2],
    [7, 1, 2],
    [8, 1, 2],
  ];
}
