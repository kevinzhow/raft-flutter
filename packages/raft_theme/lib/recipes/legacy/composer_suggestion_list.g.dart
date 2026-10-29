// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composerSuggestionList`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `composerSuggestionList` (`src/components/composer/composer-suggestion-list.tsx`, index.mjs:14035).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
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
    required RaftRecipeTheme theme,
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
      [theme.name, separated?.toString(), iconVariant?.css, metaVariant?.css],
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
    [586, 2323, 944, 3166, 2684, 2514, 2383, 878, 892, 868, 2896],
    [2621, 2758],
    [2781, 2792, 3073, 1709, 3098, 3137, 3000],
    [
      1644,
      3168,
      2331,
      1723,
      2781,
      2794,
      3040,
      962,
      3053,
      1713,
      2994,
      3125,
      1216,
      1249,
      1250,
      2248,
      1222,
      1217,
    ],
    [1644, 2597, 1645, 2331, 1722, 3040],
    [2902],
    [2597, 3133],
    [2608, 1644, 2494, 2597, 2902, 2331, 2337],
    [3073, 2998, 2597, 1645, 687, 3133],
    [3073, 2597, 3133, 1714, 2996],
    [2902, 1644, 2917, 2331, 2336, 876, 427, 892, 836, 2994],
    [2902, 130, 2913, 2996],
    [2902, 1644, 2914, 2331, 2336, 428, 2998],
    [],
    [
      586,
      2323,
      944,
      3166,
      2684,
      2512,
      2385,
      2682,
      2847,
      2692,
      833,
      2897,
      2821,
      2826,
      1152,
    ],
    [1644, 1646, 1720, 2621, 2758],
    [2511, 2781, 2794, 2958, 1713, 2363, 3087, 3028],
    [
      1644,
      3168,
      2331,
      2781,
      2794,
      3040,
      959,
      1724,
      2852,
      2962,
      1713,
      3087,
      3018,
      3110,
      1626,
      2240,
      2295,
      1248,
      1251,
      1220,
      1223,
    ],
    [3073, 3021, 2597, 1645, 687, 3133],
    [3073, 3021, 2597, 3133, 1714],
    [2902, 132, 1644, 2914, 2331, 2336, 3015, 428],
    [2902, 130, 2913, 3021],
    [2902, 1644, 2914, 2331, 2336, 428, 3021],
    [1644, 1646, 1720],
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
    [14, 15, 16, 17, 4, 5, 6, 7, 18],
    [14, 15, 16, 17, 4, 5, 6, 7, 19],
    [14, 15, 16, 17, 4, 20, 6, 7, 18],
    [14, 15, 16, 17, 4, 20, 6, 7, 19],
    [14, 15, 16, 17, 4, 21, 6, 7, 18],
    [14, 15, 16, 17, 4, 21, 6, 7, 19],
    [14, 15, 16, 17, 4, 22, 6, 7, 18],
    [14, 15, 16, 17, 4, 22, 6, 7, 19],
    [14, 23, 16, 17, 4, 5, 6, 7, 18],
    [14, 23, 16, 17, 4, 5, 6, 7, 19],
    [14, 23, 16, 17, 4, 20, 6, 7, 18],
    [14, 23, 16, 17, 4, 20, 6, 7, 19],
    [14, 23, 16, 17, 4, 21, 6, 7, 18],
    [14, 23, 16, 17, 4, 21, 6, 7, 19],
    [14, 23, 16, 17, 4, 22, 6, 7, 18],
    [14, 23, 16, 17, 4, 22, 6, 7, 19],
  ];
}
