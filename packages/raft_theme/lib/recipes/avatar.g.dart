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
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1733],
    [1768, 1552, 1702],
    [
      965,
      1768,
      1319,
      1324,
      180,
      1076,
      1084,
      1100,
      1581,
      1702,
      1016,
      1798,
      1346,
      1008,
      1870,
      1842,
      1099,
      1080,
      1090,
      1105,
      1066,
      1073,
      1095,
      1086,
      1061,
      1069,
    ],
    [
      422,
      1937,
      1725,
      1757,
      102,
      93,
      1702,
      1572,
      1577,
      1574,
      1098,
      1093,
      1092,
      1079,
      1078,
      1077,
      1085,
      1089,
      1088,
      1087,
      1104,
      1103,
      1101,
      1065,
      1064,
      1062,
      1072,
      1068,
      1067,
    ],
    [
      1305,
      1319,
      1324,
      1572,
      169,
      1096,
      1094,
      1075,
      1074,
      1083,
      1082,
      1102,
      1063,
      1071,
      1702,
      622,
      637,
      568,
      1842,
      1574,
      1097,
      1070,
    ],
    [1136, 965, 1319, 1771, 67, 65],
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1765, 1732],
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1733, 1764],
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1733, 1763],
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1733, 1762],
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1733, 1760],
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1733, 1750],
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1733, 590],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      590,
      1765,
      1732,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      590,
      1764,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      590,
      1763,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      590,
      1762,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      590,
      1760,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      590,
      1750,
    ],
    [1135, 1680, 965, 1738, 1319, 1324, 1725, 1714, 622, 637, 1842, 1733, 605],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      605,
      1765,
      1732,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      605,
      1764,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      605,
      1763,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      605,
      1762,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      605,
      1760,
    ],
    [
      1135,
      1680,
      965,
      1738,
      1319,
      1324,
      1725,
      1714,
      622,
      637,
      1842,
      1733,
      605,
      1750,
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
