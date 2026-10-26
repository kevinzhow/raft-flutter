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
    [1705, 602, 1818, 1733, 1690, 1694],
    [965, 1736, 1318, 1322, 1022, 1658, 1642, 1600],
    [1361, 1465, 1583, 1590],
    [1655, 1667, 1809, 1820],
    [1810, 1007, 1820],
    [1700, 1810, 1016, 1818, 1894, 915, 1896, 1573, 995],
    [965, 1172, 1736, 1318, 1022, 623, 633, 1656, 1820, 1000],
    [1197, 1481, 966, 615, 1809, 1818, 1573, 1624],
    [1736, 1756],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
