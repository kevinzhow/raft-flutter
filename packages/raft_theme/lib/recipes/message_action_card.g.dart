// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageActionCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `tone` axis of `messageActionCard`.
enum RaftMessageActionCardRecipeTone {
  neutral('neutral'),
  primary('primary'),
  information('information'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftMessageActionCardRecipeTone(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageActionCardRecipe].
class RaftMessageActionCardRecipeStyle {
  const RaftMessageActionCardRecipeStyle({
    required this.root,
    required this.header,
    required this.headerIcon,
    required this.headerTitle,
    required this.headerDescription,
    required this.headerMeta,
    required this.headerStatus,
    required this.status,
    required this.collapseTrigger,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `headerIcon`.
  final RaftSlotStyle headerIcon;

  /// Slot `headerTitle`.
  final RaftSlotStyle headerTitle;

  /// Slot `headerDescription`.
  final RaftSlotStyle headerDescription;

  /// Slot `headerMeta`.
  final RaftSlotStyle headerMeta;

  /// Slot `headerStatus`.
  final RaftSlotStyle headerStatus;

  /// Slot `status`.
  final RaftSlotStyle status;

  /// Slot `collapseTrigger`.
  final RaftSlotStyle collapseTrigger;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'headerIcon': headerIcon,
    'headerTitle': headerTitle,
    'headerDescription': headerDescription,
    'headerMeta': headerMeta,
    'headerStatus': headerStatus,
    'status': status,
    'collapseTrigger': collapseTrigger,
  };
}

/// raft-ui recipe `messageActionCard` (`dist/components/message-action-card/message-action-card.recipe.mjs`, index.mjs:13457).
///
/// Used by: MessageActionCard, MessageActionCardCollapseTrigger, MessageActionCardHeader, MessageActionCardHeaderDescription, MessageActionCardHeaderIcon, MessageActionCardHeaderMeta, MessageActionCardHeaderStatus, MessageActionCardHeaderTitle, MessageActionCardStatus.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageActionCardRecipe {
  static const String recipeName = 'messageActionCard';
  static const List<String> slotNames = [
    'root',
    'header',
    'headerIcon',
    'headerTitle',
    'headerDescription',
    'headerMeta',
    'headerStatus',
    'status',
    'collapseTrigger',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'tone',
      [
        'neutral',
        'primary',
        'information',
        'accent',
        'success',
        'warning',
        'danger',
      ],
      null,
      true,
    ),
  ];

  static RaftMessageActionCardRecipeStyle resolve({
    RaftMessageActionCardRecipeTone? tone,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [tone?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageActionCardRecipeStyle(
      root: s[0],
      header: s[1],
      headerIcon: s[2],
      headerTitle: s[3],
      headerDescription: s[4],
      headerMeta: s[5],
      headerStatus: s[6],
      status: s[7],
      collapseTrigger: s[8],
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
    [1593, 2147],
    [1400, 1866, 1466, 2275, 1559],
    [1400, 2499, 1864, 1869, 348, 2528, 2461, 895, 2603, 351],
    [2116, 1401, 2385],
    [937, 2144, 2597, 1455, 2603],
    [937, 1803, 2144, 1804, 1454, 2616, 1455, 2556, 2600],
    [2132, 2499, 2151, 2588, 1457, 2603],
    [
      1847,
      1673,
      1864,
      1465,
      2468,
      940,
      933,
      2260,
      2497,
      2588,
      1457,
      2603,
      859,
      858,
      854,
      822,
      824,
      828,
    ],
    [
      1400,
      2499,
      997,
      1864,
      1869,
      363,
      337,
      2134,
      1268,
      1424,
      1428,
      2157,
      173,
      2528,
      2461,
      2603,
      1785,
      1798,
      697,
      1432,
      1439,
      352,
    ],
    [
      1847,
      1673,
      1864,
      1465,
      2468,
      940,
      933,
      2260,
      2497,
      2588,
      1457,
      2603,
      859,
      858,
      854,
      822,
      824,
      828,
      813,
    ],
    [
      1847,
      1673,
      1864,
      1465,
      2468,
      940,
      933,
      2260,
      2497,
      2588,
      1457,
      2603,
      859,
      858,
      854,
      822,
      824,
      828,
      816,
    ],
    [
      1847,
      1673,
      1864,
      1465,
      2468,
      940,
      933,
      2260,
      2497,
      2588,
      1457,
      2603,
      859,
      858,
      854,
      822,
      824,
      828,
      814,
    ],
    [
      1847,
      1673,
      1864,
      1465,
      2468,
      940,
      933,
      2260,
      2497,
      2588,
      1457,
      2603,
      859,
      858,
      854,
      822,
      824,
      828,
      811,
    ],
    [
      1847,
      1673,
      1864,
      1465,
      2468,
      940,
      933,
      2260,
      2497,
      2588,
      1457,
      2603,
      859,
      858,
      854,
      822,
      824,
      828,
      817,
    ],
    [
      1847,
      1673,
      1864,
      1465,
      2468,
      940,
      933,
      2260,
      2497,
      2588,
      1457,
      2603,
      859,
      858,
      854,
      822,
      824,
      828,
      819,
    ],
    [
      1847,
      1673,
      1864,
      1465,
      2468,
      940,
      933,
      2260,
      2497,
      2588,
      1457,
      2603,
      859,
      858,
      854,
      822,
      824,
      828,
      812,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [0, 1, 2, 3, 4, 5, 6, 9, 8],
    [0, 1, 2, 3, 4, 5, 6, 10, 8],
    [0, 1, 2, 3, 4, 5, 6, 11, 8],
    [0, 1, 2, 3, 4, 5, 6, 12, 8],
    [0, 1, 2, 3, 4, 5, 6, 13, 8],
    [0, 1, 2, 3, 4, 5, 6, 14, 8],
    [0, 1, 2, 3, 4, 5, 6, 15, 8],
  ];
}
