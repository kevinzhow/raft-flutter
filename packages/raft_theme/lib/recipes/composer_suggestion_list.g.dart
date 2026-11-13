// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `composerSuggestionList`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `iconVariant` axis of `composerSuggestionList` (default `avatar`).
enum RaftComposerSuggestionListRecipeIconVariant {
  avatar('avatar'),
  framed('framed'),
  auxiliary('auxiliary'),
  inline('inline');

  const RaftComposerSuggestionListRecipeIconVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `metaVariant` axis of `composerSuggestionList` (default `text`).
enum RaftComposerSuggestionListRecipeMetaVariant {
  text('text'),
  code('code');

  const RaftComposerSuggestionListRecipeMetaVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftComposerSuggestionListRecipe].
class RaftComposerSuggestionListRecipeStyle {
  const RaftComposerSuggestionListRecipeStyle({
    required this.root,
    required this.group,
    required this.groupLabel,
    required this.item,
    required this.content,
    required this.icon,
    required this.title,
    required this.aside,
    required this.meta,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `group`.
  final RaftSlotStyle group;

  /// Slot `groupLabel`.
  final RaftSlotStyle groupLabel;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `icon`.
  final RaftSlotStyle icon;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `aside`.
  final RaftSlotStyle aside;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'group': group,
    'groupLabel': groupLabel,
    'item': item,
    'content': content,
    'icon': icon,
    'title': title,
    'aside': aside,
    'meta': meta,
  };
}

/// raft-ui recipe `composerSuggestionList` (`dist/components/composer/composer-suggestion-list.mjs`, index.mjs:16691).
///
/// Used by: ComposerSuggestionAside, ComposerSuggestionContent, ComposerSuggestionGroup, ComposerSuggestionGroupLabel, ComposerSuggestionIcon, ComposerSuggestionList, ComposerSuggestionMeta, ComposerSuggestionOption, ComposerSuggestionTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerSuggestionListRecipe {
  static const String recipeName = 'composerSuggestionList';
  static const List<String> slotNames = [
    'root',
    'group',
    'groupLabel',
    'item',
    'content',
    'icon',
    'title',
    'aside',
    'meta',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('separated', ['true', 'false'], 'false', false),
    RaftRecipeAxis(
      'iconVariant',
      ['avatar', 'framed', 'auxiliary', 'inline'],
      'avatar',
      false,
    ),
    RaftRecipeAxis('metaVariant', ['text', 'code'], 'text', false),
  ];

  static RaftComposerSuggestionListRecipeStyle resolve({
    bool? separated,
    RaftComposerSuggestionListRecipeIconVariant? iconVariant,
    RaftComposerSuggestionListRecipeMetaVariant? metaVariant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [separated?.toString(), iconVariant?.css, metaVariant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftComposerSuggestionListRecipeStyle(
      root: s[0],
      group: s[1],
      groupLabel: s[2],
      item: s[3],
      content: s[4],
      icon: s[5],
      title: s[6],
      aside: s[7],
      meta: s[8],
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
      691,
      1858,
      974,
      2723,
      1989,
      1914,
      2255,
      2462,
      2261,
      915,
      2598,
      2445,
      2449,
      2496,
    ],
    [1400, 1404, 177, 2145, 960, 953, 2399, 2379],
    [2415, 2402, 2381, 2274, 1456, 2588, 1449, 2600],
    [
      1400,
      2725,
      1864,
      2613,
      2113,
      997,
      1467,
      2461,
      2402,
      2414,
      1456,
      2587,
      1453,
      2598,
      1783,
      1029,
      1009,
      1013,
      1010,
    ],
    [1400, 2116, 1401, 1864, 1465, 2613],
    [2499],
    [2116, 2681],
    [2132, 1400, 1966, 2116, 2499, 1864, 1870],
    [2588, 2600, 2116, 1401, 804, 2681],
    [2116, 2681, 1454, 2616, 2600],
    [2499, 1400, 2527, 1864, 1869, 2471, 895, 2603, 486],
    [2499, 172, 2515, 2600],
    [2499, 1400, 2516, 1864, 1869, 477, 2600],
    [1400, 1404],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [0, 1, 2, 3, 4, 5, 6, 7, 9],
    [0, 1, 2, 3, 4, 10, 6, 7, 8],
    [0, 1, 2, 3, 4, 10, 6, 7, 9],
    [0, 1, 2, 3, 4, 11, 6, 7, 8],
    [0, 1, 2, 3, 4, 11, 6, 7, 9],
    [0, 1, 2, 3, 4, 12, 6, 7, 8],
    [0, 1, 2, 3, 4, 12, 6, 7, 9],
    [0, 13, 2, 3, 4, 5, 6, 7, 8],
    [0, 13, 2, 3, 4, 5, 6, 7, 9],
    [0, 13, 2, 3, 4, 10, 6, 7, 8],
    [0, 13, 2, 3, 4, 10, 6, 7, 9],
    [0, 13, 2, 3, 4, 11, 6, 7, 8],
    [0, 13, 2, 3, 4, 11, 6, 7, 9],
    [0, 13, 2, 3, 4, 12, 6, 7, 8],
    [0, 13, 2, 3, 4, 12, 6, 7, 9],
  ];
}
