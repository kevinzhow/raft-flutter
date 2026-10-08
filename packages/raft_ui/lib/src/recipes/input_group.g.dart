// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `inputGroup`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `align` axis of `inputGroup` (default `inline-start`).
enum RaftInputGroupRecipeAlign {
  inlineStart('inline-start'),
  inlineEnd('inline-end');

  const RaftInputGroupRecipeAlign(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `inputGroup` (default `default`).
enum RaftInputGroupRecipeVariant {
  default_('default'),
  container('container');

  const RaftInputGroupRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftInputGroupRecipe].
class RaftInputGroupRecipeStyle {
  const RaftInputGroupRecipeStyle({required this.root, required this.addon, required this.text, required this.control});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `addon`.
  final RaftSlotStyle addon;
  /// Slot `text`.
  final RaftSlotStyle text;
  /// Slot `control`.
  final RaftSlotStyle control;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'addon': addon, 'text': text, 'control': control};
}

/// raft-ui recipe `inputGroup` (`src/components/input-group/input-group.tsx`, index.mjs:6428).
///
/// Used by: ComboboxInputGroup, InputGroup, InputGroupAddon, InputGroupInput.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInputGroupRecipe {
  static const String recipeName = 'inputGroup';
  static const List<String> slotNames = ['root', 'addon', 'text', 'control'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('align', ['inline-start', 'inline-end'], 'inline-start', false),
    RaftRecipeAxis('variant', ['default', 'container'], 'default', false),
  ];

  static RaftInputGroupRecipeStyle resolve({required RaftRecipeTheme theme, RaftInputGroupRecipeAlign? align, RaftInputGroupRecipeVariant? variant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, align?.css, variant?.css], states, tokens);
    return RaftInputGroupRecipeStyle(root: s[0], addon: s[1], text: s[2], control: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1923, 2775, 1620, 3127, 2574, 2312, 2072, 866, 900, 825, 2863, 2088, 2095, 2094, 2100, 2098, 2099],
    [1620, 2867, 2312, 2317, 1698, 2753, 2834, 288, 2992, 2636, 463],
    [1620, 2867, 2312, 2753, 3017, 2834, 3131, 1687, 2992, 2636, 463],
    [2574, 1621, 850, 2753, 2765, 3017, 2649, 1687],
    [1620, 2867, 2312, 2317, 1698, 2753, 2834, 288, 2636, 2838, 1007, 994, 787, 1684, 2995, 907, 900],
    [1620, 2867, 2312, 2753, 3017, 2834, 3131, 1687, 2636, 2838, 1007, 994, 787, 1684, 2995, 907, 900],
    [1620, 2867, 2312, 2317, 1698, 2753, 2834, 288, 2992, 2637],
    [1620, 2867, 2312, 2753, 3017, 2834, 3131, 1687, 2992, 2637],
    [1620, 2867, 2312, 2317, 1698, 2753, 2834, 288, 2637, 2838, 1007, 994, 787, 1684, 2995, 892, 900],
    [1620, 2867, 2312, 2753, 3017, 2834, 3131, 1687, 2637, 2838, 1007, 994, 787, 1684, 2995, 892, 900],
    [1923, 2775, 1620, 3127, 2574, 2312, 2072, 2656, 2818, 864, 894, 825, 2860, 993, 1128, 1142, 1111, 2976, 3061, 1605, 1613, 1168, 2245, 2087, 1090, 2085, 2086, 1088, 1089, 2096, 2097, 2093, 2091, 2092, 2083, 2082, 2081, 2084, 2089, 2090],
    [1620, 2867, 2312, 2317, 1698, 2753, 2834, 288, 2981, 3061, 1605, 1613, 1876, 1874, 2636, 463],
    [1620, 2867, 2312, 2753, 3017, 2834, 3131, 2984, 3061, 1605, 1613, 1875, 1874, 2636, 463],
    [2574, 1621, 850, 2753, 2765, 3017, 2649, 2976, 2712, 1168, 3061, 1605, 1613, 2714, 2708, 2709, 1584, 1593, 1589],
    [1620, 2867, 2312, 2317, 1698, 2753, 2834, 288, 3061, 1605, 1613, 1876, 1874, 2636, 2838, 899, 796, 1007, 994, 2984, 906],
    [1620, 2867, 2312, 2753, 3017, 2834, 3131, 3061, 1605, 1613, 1875, 1874, 2636, 2838, 899, 796, 1007, 994, 2984, 906],
    [1620, 2867, 2312, 2317, 1698, 2753, 2834, 288, 2981, 3061, 1605, 1613, 1876, 1874, 2637],
    [1620, 2867, 2312, 2753, 3017, 2834, 3131, 2984, 3061, 1605, 1613, 1875, 1874, 2637],
    [1620, 2867, 2312, 2317, 1698, 2753, 2834, 288, 3061, 1605, 1613, 1876, 1874, 2637, 2838, 899, 796, 1007, 994, 2984, 891],
    [1620, 2867, 2312, 2753, 3017, 2834, 3131, 3061, 1605, 1613, 1875, 1874, 2637, 2838, 899, 796, 1007, 994, 2984, 891],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [0, 4, 5, 3], [0, 6, 7, 3], [0, 8, 9, 3], [10, 11, 12, 13], [10, 14, 15, 13], [10, 16, 17, 13], [10, 18, 19, 13],
  ];
}
