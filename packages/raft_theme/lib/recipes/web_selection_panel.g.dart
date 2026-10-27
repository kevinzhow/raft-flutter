// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `webSelectionPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftWebSelectionPanelRecipe].
class RaftWebSelectionPanelRecipeStyle {
  const RaftWebSelectionPanelRecipeStyle({
    required this.root,
    required this.header,
    required this.list,
    required this.empty,
    required this.title,
    required this.clear,
    required this.search,
    required this.input,
    required this.searchIcon,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `empty`.
  final RaftSlotStyle empty;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `clear`.
  final RaftSlotStyle clear;

  /// Slot `search`.
  final RaftSlotStyle search;

  /// Slot `input`.
  final RaftSlotStyle input;

  /// Slot `searchIcon`.
  final RaftSlotStyle searchIcon;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'list': list,
    'empty': empty,
    'title': title,
    'clear': clear,
    'search': search,
    'input': input,
    'searchIcon': searchIcon,
  };
}

/// raft-ui recipe `webSelectionPanel` (`Web src/components/ui/SelectionPopover.tsx sha256:8af0b00698de999e8ec3c1d79e9427e6aa1ccd7c1097cc4e5943ba3d9b1228c6`, index.mjs:1).
///
/// Used by: SelectionPopoverSections.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftWebSelectionPanelRecipe {
  static const String recipeName = 'webSelectionPanel';
  static const List<String> slotNames = [
    'root',
    'header',
    'list',
    'empty',
    'title',
    'clear',
    'search',
    'input',
    'searchIcon',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftWebSelectionPanelRecipeStyle resolve({
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
    return RaftWebSelectionPanelRecipeStyle(
      root: s[0],
      header: s[1],
      list: s[2],
      empty: s[3],
      title: s[4],
      clear: s[5],
      search: s[6],
      input: s[7],
      searchIcon: s[8],
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
    [1707, 602, 1820, 1735, 1692, 1696],
    [965, 1738, 1319, 1323, 1023, 1660, 1644, 1602],
    [1363, 1467, 1585, 1592],
    [1657, 1669, 1811, 1822],
    [1812, 1008, 1822],
    [1702, 1812, 1017, 1820, 1896, 915, 1898, 1575, 996],
    [965, 1173, 1738, 1319, 1023, 623, 633, 1658, 1822, 1001],
    [1198, 1483, 966, 615, 1811, 1820, 1575, 1626],
    [1738, 1758],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
