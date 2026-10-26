// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `avatar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `type` axis of `avatar`.
enum RaftAvatarRecipeType {
  agent('agent'),
  human('human');

  const RaftAvatarRecipeType(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `avatar`.
enum RaftAvatarRecipeSize {
  xl('xl'),
  lg('lg'),
  md('md'),
  sm('sm'),
  xs('xs'),
  v2xs('2xs'),
  v3xs('3xs');

  const RaftAvatarRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftAvatarRecipe].
class RaftAvatarRecipeStyle {
  const RaftAvatarRecipeStyle({
    required this.root,
    required this.image,
    required this.fallback,
    required this.badge,
    required this.dot,
    required this.group,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `image`.
  final RaftSlotStyle image;

  /// Slot `fallback`.
  final RaftSlotStyle fallback;

  /// Slot `badge`.
  final RaftSlotStyle badge;

  /// Slot `dot`.
  final RaftSlotStyle dot;

  /// Slot `group`.
  final RaftSlotStyle group;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'image': image,
    'fallback': fallback,
    'badge': badge,
    'dot': dot,
    'group': group,
  };
}

/// raft-ui recipe `avatar` (`src/components/avatar/avatar.tsx`, index.mjs:6406).
///
/// Used by: Avatar, AvatarBadge, AvatarFallback, AvatarGroup, AvatarGroupCount, AvatarImage, LiveAgentActivityBarAvatar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAvatarRecipe {
  static const String recipeName = 'avatar';
  static const List<String> slotNames = [
    'root',
    'image',
    'fallback',
    'badge',
    'dot',
    'group',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('type', ['agent', 'human'], null, true),
    RaftRecipeAxis(
      'size',
      ['xl', 'lg', 'md', 'sm', 'xs', '2xs', '3xs'],
      null,
      true,
    ),
  ];

  static RaftAvatarRecipeStyle resolve({
    RaftAvatarRecipeType? type_,
    RaftAvatarRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [type_?.css, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftAvatarRecipeStyle(
      root: s[0],
      image: s[1],
      fallback: s[2],
      badge: s[3],
      dot: s[4],
      group: s[5],
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
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1731],
    [1766, 1550, 1700],
    [
      965,
      1766,
      1318,
      1323,
      180,
      1075,
      1083,
      1099,
      1579,
      1700,
      1015,
      1796,
      1345,
      1007,
      1868,
      1840,
      1098,
      1079,
      1089,
      1104,
      1065,
      1072,
      1094,
      1085,
      1060,
      1068,
    ],
    [
      422,
      1935,
      1723,
      1755,
      102,
      93,
      1700,
      1570,
      1575,
      1572,
      1097,
      1092,
      1091,
      1078,
      1077,
      1076,
      1084,
      1088,
      1087,
      1086,
      1103,
      1102,
      1100,
      1064,
      1063,
      1061,
      1071,
      1067,
      1066,
    ],
    [
      1304,
      1318,
      1323,
      1570,
      169,
      1095,
      1093,
      1074,
      1073,
      1082,
      1081,
      1101,
      1062,
      1070,
      1700,
      622,
      637,
      568,
      1840,
      1572,
      1096,
      1069,
    ],
    [1135, 965, 1318, 1769, 67, 65],
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1763, 1730],
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1731, 1762],
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1731, 1761],
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1731, 1760],
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1731, 1758],
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1731, 1748],
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1731, 590],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      590,
      1763,
      1730,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      590,
      1762,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      590,
      1761,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      590,
      1760,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      590,
      1758,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      590,
      1748,
    ],
    [1134, 1678, 965, 1736, 1318, 1323, 1723, 1712, 622, 637, 1840, 1731, 605],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      605,
      1763,
      1730,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      605,
      1762,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      605,
      1761,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      605,
      1760,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      605,
      1758,
    ],
    [
      1134,
      1678,
      965,
      1736,
      1318,
      1323,
      1723,
      1712,
      622,
      637,
      1840,
      1731,
      605,
      1748,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [8, 1, 2, 3, 4, 5],
    [9, 1, 2, 3, 4, 5],
    [10, 1, 2, 3, 4, 5],
    [10, 1, 2, 3, 4, 5],
    [11, 1, 2, 3, 4, 5],
    [12, 1, 2, 3, 4, 5],
    [13, 1, 2, 3, 4, 5],
    [14, 1, 2, 3, 4, 5],
    [15, 1, 2, 3, 4, 5],
    [16, 1, 2, 3, 4, 5],
    [17, 1, 2, 3, 4, 5],
    [17, 1, 2, 3, 4, 5],
    [18, 1, 2, 3, 4, 5],
    [19, 1, 2, 3, 4, 5],
    [20, 1, 2, 3, 4, 5],
    [21, 1, 2, 3, 4, 5],
    [22, 1, 2, 3, 4, 5],
    [23, 1, 2, 3, 4, 5],
    [24, 1, 2, 3, 4, 5],
    [24, 1, 2, 3, 4, 5],
    [25, 1, 2, 3, 4, 5],
  ];
}
