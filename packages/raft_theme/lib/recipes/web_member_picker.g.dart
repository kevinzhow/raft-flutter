// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `webMemberPicker`.
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

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'group': group,
    'row': row,
    'label': label,
    'empty': empty,
  };
}

/// raft-ui recipe `webMemberPicker` (`Web src/components/channel/CreateChannelDialog.tsx sha256:63ca5d6eb0050347255f9d637df2e0ce49cb5636279a254e4a9c52f79287348d; src/components/channel/memberPickerClasses.ts sha256:bd095e7c89107c9ce5dde28aceae30bb96c0eb12d1dc6dad80f9702198d848b1; src/components/ui/SectionEyebrow.tsx sha256:842e6ec0e8cfcd3948d384ef8a9cde6fd2b41be4db8dfd8ccd0321c12c4555b0`, index.mjs:1).
///
/// Used by: CreateChannelDialogMemberPicker.
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
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftWebMemberPickerRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
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
    [1361, 1587, 1594],
    [1821, 1008, 1824, 1659, 1645, 1604],
    [
      965,
      1480,
      1929,
      1319,
      1024,
      1710,
      1659,
      1836,
      1813,
      1013,
      1822,
      1577,
      1270,
      978,
      995,
    ],
    [1484, 966, 1897],
    [1659, 1671, 1813, 1824],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
  ];
}
