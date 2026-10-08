// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `card`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `card` (default `default`).
enum RaftCardRecipeVariant {
  default_('default'),
  option('option'),
  inset('inset');

  const RaftCardRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftCardRecipe].
class RaftCardRecipeStyle {
  const RaftCardRecipeStyle({required this.root, required this.header, required this.title, required this.leading, required this.description, required this.trailing, required this.content, required this.footer});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `title`.
  final RaftSlotStyle title;
  /// Slot `leading`.
  final RaftSlotStyle leading;
  /// Slot `description`.
  final RaftSlotStyle description;
  /// Slot `trailing`.
  final RaftSlotStyle trailing;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'title': title, 'leading': leading, 'description': description, 'trailing': trailing, 'content': content, 'footer': footer};
}

/// raft-ui recipe `card` (`src/components/card/card.recipe.ts`, index.mjs:1740).
///
/// Used by: Card, CardContent, CardDescription, CardFooter, CardHeader, CardLeading, CardTitle, CardTrailing, MessageAttachmentCard.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCardRecipe {
  static const String recipeName = 'card';
  static const List<String> slotNames = ['root', 'header', 'title', 'leading', 'description', 'trailing', 'content', 'footer'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['default', 'option', 'inset'], 'default', false),
  ];

  static RaftCardRecipeStyle resolve({required RaftRecipeTheme theme, RaftCardRecipeVariant? variant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, variant?.css], states, tokens);
    return RaftCardRecipeStyle(root: s[0], header: s[1], title: s[2], leading: s[3], description: s[4], trailing: s[5], content: s[6], footer: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2574, 1622, 2656, 2976, 866, 900, 825, 2862],
    [1913, 1717, 2574, 676, 1718, 2314, 1710, 1714, 1994, 1996, 1995, 875, 900, 2673],
    [936, 2826, 2574, 1865, 1687, 2969, 1685],
    [936, 2825, 2826, 1620, 2867, 2312, 2837, 305, 302, 2558],
    [936, 2827, 2574, 1865, 1691, 3017, 2335, 2993],
    [937, 2826, 1620, 2867, 2312, 2836, 2319, 1866],
    [2574, 2673],
    [1620, 2574, 1698, 1624, 2312, 1691, 3032, 2333, 2981, 304, 302, 221, 913, 900, 824, 2755, 2767],
    [1620, 2574, 1622, 2656, 2976, 866, 900, 825, 2863],
    [1913, 1717, 2574, 676, 1718, 2314, 1714, 1994, 1996, 1995, 1709, 2672],
    [936, 2826, 2574, 1865, 1687, 3017, 2335, 1684],
    [936, 2827, 2574, 1865, 2993, 1691, 3032, 2333],
    [2574, 2753, 2685],
    [1620, 2574, 1698, 1624, 2312, 1691, 3032, 2333, 2981, 304, 302, 221],
    [1620, 2574, 1622, 2656, 2976, 866, 900, 825, 2751, 2862],
    [1913, 1717, 2574, 676, 1718, 2314, 1710, 1714, 1994, 1996, 1995, 2755, 2767],
    [2574, 139, 922, 900, 825, 2757, 2769],
    [1620, 2574, 1698, 1624, 2312, 1691, 3032, 2333, 2981, 304, 302, 221, 2755, 2767],
    [1620, 2574, 1622, 2656, 2976, 2817, 867, 896, 825, 2865, 1009],
    [1913, 1717, 2574, 676, 1718, 2314, 1710, 1714, 1994, 1996, 1995, 2674, 1981],
    [936, 2826, 2574, 1865, 1691, 2969, 1685],
    [936, 2827, 2574, 1865, 1691, 3032, 2333, 3048, 3005, 2981],
    [2574, 2674],
    [1620, 2574, 1698, 1624, 2312, 1691, 3032, 2333, 2977, 304, 302, 221, 911, 895, 824, 2756, 2768, 1009, 1002],
    [1620, 2574, 1622, 2656, 2976, 2818, 864, 894, 825, 2860],
    [936, 2826, 2574, 1865, 1691, 3017, 2335, 1692],
    [936, 2827, 2574, 1865, 3048, 3005, 2981, 1691, 3032, 2333],
    [1620, 2574, 1698, 1624, 2312, 1691, 3032, 2333, 2977, 304, 302, 221],
    [1620, 2574, 1622, 2656, 2976, 2817, 867, 896, 821, 2675, 2865, 1009],
    [1913, 1717, 2574, 676, 1718, 2314, 1710, 1714, 1994, 1996, 1995, 2756, 2768],
    [2574, 2655, 2809, 867, 895, 825, 2674, 1009, 1138],
    [1620, 2574, 1698, 1624, 2312, 1691, 3032, 2333, 2977, 304, 302, 221, 2756, 2767],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7], [8, 9, 10, 3, 11, 5, 12, 13], [14, 15, 2, 3, 4, 5, 16, 17], [18, 19, 20, 3, 21, 5, 22, 23], [24, 9, 25, 3, 26, 5, 12, 27], [28, 29, 20, 3, 21, 5, 30, 31],
  ];
}
