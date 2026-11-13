// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `webMemberPicker`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftWebMemberPickerRecipe].
class RaftWebMemberPickerRecipeStyle {
  const RaftWebMemberPickerRecipeStyle({
    required this.root,
    required this.group,
    required this.row,
    required this.label,
    required this.empty,
    required this.badge,
    required this.scroller,
    required this.rows,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `group`.
  final RaftSlotStyle group;

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `empty`.
  final RaftSlotStyle empty;

  /// Slot `badge`.
  final RaftSlotStyle badge;

  /// Slot `scroller`.
  final RaftSlotStyle scroller;

  /// Slot `rows`.
  final RaftSlotStyle rows;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'group': group,
    'row': row,
    'label': label,
    'empty': empty,
    'badge': badge,
    'scroller': scroller,
    'rows': rows,
  };
}

/// raft-ui recipe `webMemberPicker` (`Web src/components/channel/MemberChoiceList.tsx sha256:448a0c9562300397725e5f96956e7fd8f667f6516a88e8720cf25bc87889f539`, index.mjs:1).
///
/// Used by: MemberChoiceList.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftWebMemberPickerRecipe {
  static const String recipeName = 'webMemberPicker';
  static const List<String> slotNames = [
    'root',
    'group',
    'row',
    'label',
    'empty',
    'badge',
    'scroller',
    'rows',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('fill', ['false', 'true'], 'false', false),
  ];

  static RaftWebMemberPickerRecipeStyle resolve({
    bool? fill,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [fill?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftWebMemberPickerRecipeStyle(
      root: s[0],
      group: s[1],
      row: s[2],
      label: s[3],
      empty: s[4],
      badge: s[5],
      scroller: s[6],
      rows: s[7],
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
    [1400, 2116, 1404, 2252, 2462, 939, 953, 911],
    [983, 2402, 2381, 2274, 1456, 2588, 1449, 2600],
    [
      983,
      1400,
      2116,
      1866,
      1467,
      2461,
      2402,
      2113,
      2430,
      2335,
      2343,
      2613,
      1456,
      2622,
      2186,
      2184,
      1181,
    ],
    [1457, 2598, 1820, 2116, 2681],
    [2402, 2417, 1456, 2587, 2600],
    [1400, 2116, 1864, 1465],
    [2098, 2116, 2261, 1916],
    [1489, 1495, 1476, 1485],
    [1400, 2116, 1404, 2252, 2462, 939, 953, 911, 2098, 1401],
    [2098, 2116, 2261, 1401],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 1, 2, 3, 4, 5, 9, 7],
  ];
}
