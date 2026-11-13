// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `webSelectionPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `width` axis of `webSelectionPanel` (default `content`).
enum RaftWebSelectionPanelRecipeWidth {
  content('content'),
  trigger('trigger');

  const RaftWebSelectionPanelRecipeWidth(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftWebSelectionPanelRecipe].
class RaftWebSelectionPanelRecipeStyle {
  const RaftWebSelectionPanelRecipeStyle({
    required this.root,
    required this.header,
    required this.list,
    required this.content,
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

  /// Slot `content`.
  final RaftSlotStyle content;

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
    'content': content,
    'empty': empty,
    'title': title,
    'clear': clear,
    'search': search,
    'input': input,
    'searchIcon': searchIcon,
  };
}

/// raft-ui recipe `webSelectionPanel` (`Web src/components/ui/SelectionPopover.tsx sha256:70e0c0cd94cd4c04e8affb90ed7f5e8648870d49d6ce5293b0595876bc296fca`, index.mjs:1).
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
    'content',
    'empty',
    'title',
    'clear',
    'search',
    'input',
    'searchIcon',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('width', ['content', 'trigger'], 'content', false),
  ];

  static RaftWebSelectionPanelRecipeStyle resolve({
    RaftWebSelectionPanelRecipeWidth? width,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [width?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftWebSelectionPanelRecipeStyle(
      root: s[0],
      header: s[1],
      list: s[2],
      content: s[3],
      empty: s[4],
      title: s[5],
      clear: s[6],
      search: s[7],
      input: s[8],
      searchIcon: s[9],
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
      1911,
      2128,
      2252,
      2247,
      2462,
      915,
      2598,
      2496,
      2445,
      2449,
      1400,
      1952,
      1404,
    ],
    [1400, 2499, 1864, 1868, 1466, 2405, 2382, 2274],
    [1915, 2098],
    [2261],
    [2402, 2417, 2587, 2600],
    [2588, 1449, 2600],
    [2457, 1338, 2684, 2193, 2247, 1439, 1353, 1363, 1453, 2603, 1798, 2588],
    [1400, 1647, 2042, 2499, 1864, 1466, 942, 953, 2403, 2600, 1874],
    [1678, 2116, 1401, 933, 2587, 2598, 2247, 2311],
    [2499, 2525],
    [
      1911,
      2128,
      2252,
      2247,
      2462,
      915,
      2598,
      2496,
      2445,
      2449,
      1400,
      1952,
      1404,
      2685,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [10, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  ];
}
