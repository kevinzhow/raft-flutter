// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composerSuggestionList`.
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
  const RaftComposerSuggestionListRecipeStyle({required this.root, required this.group, required this.groupLabel, required this.item, required this.content, required this.icon, required this.title, required this.aside, required this.meta});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'group': group, 'groupLabel': groupLabel, 'item': item, 'content': content, 'icon': icon, 'title': title, 'aside': aside, 'meta': meta};
}

/// raft-ui recipe `composerSuggestionList` (`src/components/composer/composer-suggestion-list.tsx`, index.mjs:13809).
///
/// Used by: ComposerSuggestionAside, ComposerSuggestionContent, ComposerSuggestionGroup, ComposerSuggestionGroupLabel, ComposerSuggestionIcon, ComposerSuggestionList, ComposerSuggestionMeta, ComposerSuggestionOption, ComposerSuggestionTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerSuggestionListRecipe {
  static const String recipeName = 'composerSuggestionList';
  static const List<String> slotNames = ['root', 'group', 'groupLabel', 'item', 'content', 'icon', 'title', 'aside', 'meta'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('separated', ['true', 'false'], 'false', false),
    RaftRecipeAxis('iconVariant', ['avatar', 'framed', 'auxiliary', 'inline'], 'avatar', false),
    RaftRecipeAxis('metaVariant', ['text', 'code'], 'text', false),
  ];

  static RaftComposerSuggestionListRecipeStyle resolve({required RaftRecipeTheme theme, bool? separated, RaftComposerSuggestionListRecipeIconVariant? iconVariant, RaftComposerSuggestionListRecipeMetaVariant? metaVariant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, separated?.toString(), iconVariant?.css, metaVariant?.css], states, tokens);
    return RaftComposerSuggestionListRecipeStyle(root: s[0], group: s[1], groupLabel: s[2], item: s[3], content: s[4], icon: s[5], title: s[6], aside: s[7], meta: s[8]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [580, 2304, 931, 3125, 2661, 2493, 2364, 866, 876, 856, 2862],
    [2598, 2733],
    [2753, 2763, 3032, 1684, 3057, 3096, 2963],
    [1620, 3127, 2312, 1698, 2753, 2765, 3003, 942, 3017, 1688, 2956, 3084, 1197, 1228, 1229, 2229, 1203, 1198],
    [1620, 2574, 1621, 2312, 1697, 3003],
    [2867],
    [2574, 3092],
    [2585, 1620, 2473, 2574, 2867, 2312, 2318],
    [3032, 2961, 2574, 1621, 681, 3092],
    [3032, 2574, 3092, 1689, 2959],
    [2867, 1620, 2882, 2312, 2317, 864, 429, 876, 831, 2956],
    [2867, 130, 2878, 2959],
    [2867, 1620, 2879, 2312, 2317, 430, 2961],
    [],
    [580, 2304, 931, 3125, 2661, 2491, 2366, 2659, 2817, 2669, 828, 2863, 2791, 2796, 1133],
    [1620, 1622, 1695, 2598, 2733],
    [2490, 2753, 2765, 2920, 1688, 2344, 3046, 2991],
    [1620, 3127, 2312, 2753, 2765, 3003, 939, 1699, 2822, 2924, 1688, 3046, 2981, 3069, 1602, 2221, 2276, 1227, 1230, 1201, 1204],
    [3032, 2984, 2574, 1621, 681, 3092],
    [3032, 2984, 2574, 3092, 1689],
    [2867, 132, 1620, 2879, 2312, 2317, 2978, 430],
    [2867, 130, 2878, 2984],
    [2867, 1620, 2879, 2312, 2317, 430, 2984],
    [1620, 1622, 1695],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8], [0, 1, 2, 3, 4, 5, 6, 7, 9], [0, 1, 2, 3, 4, 10, 6, 7, 8], [0, 1, 2, 3, 4, 10, 6, 7, 9], [0, 1, 2, 3, 4, 11, 6, 7, 8], [0, 1, 2, 3, 4, 11, 6, 7, 9], [0, 1, 2, 3, 4, 12, 6, 7, 8], [0, 1, 2, 3, 4, 12, 6, 7, 9], [0, 13, 2, 3, 4, 5, 6, 7, 8], [0, 13, 2, 3, 4, 5, 6, 7, 9], [0, 13, 2, 3, 4, 10, 6, 7, 8], [0, 13, 2, 3, 4, 10, 6, 7, 9], [0, 13, 2, 3, 4, 11, 6, 7, 8], [0, 13, 2, 3, 4, 11, 6, 7, 9], [0, 13, 2, 3, 4, 12, 6, 7, 8], [0, 13, 2, 3, 4, 12, 6, 7, 9],
    [14, 15, 16, 17, 4, 5, 6, 7, 18], [14, 15, 16, 17, 4, 5, 6, 7, 19], [14, 15, 16, 17, 4, 20, 6, 7, 18], [14, 15, 16, 17, 4, 20, 6, 7, 19], [14, 15, 16, 17, 4, 21, 6, 7, 18], [14, 15, 16, 17, 4, 21, 6, 7, 19], [14, 15, 16, 17, 4, 22, 6, 7, 18], [14, 15, 16, 17, 4, 22, 6, 7, 19], [14, 23, 16, 17, 4, 5, 6, 7, 18], [14, 23, 16, 17, 4, 5, 6, 7, 19], [14, 23, 16, 17, 4, 20, 6, 7, 18], [14, 23, 16, 17, 4, 20, 6, 7, 19], [14, 23, 16, 17, 4, 21, 6, 7, 18], [14, 23, 16, 17, 4, 21, 6, 7, 19], [14, 23, 16, 17, 4, 22, 6, 7, 18], [14, 23, 16, 17, 4, 22, 6, 7, 19],
  ];
}
