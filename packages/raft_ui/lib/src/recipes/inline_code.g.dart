// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `inlineCode`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `appearance` axis of `inlineCode` (default `default`).
enum RaftInlineCodeRecipeAppearance {
  default_('default'),
  message('message');

  const RaftInlineCodeRecipeAppearance(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftInlineCodeRecipe].
class RaftInlineCodeRecipeStyle {
  const RaftInlineCodeRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `inlineCode` (`src/components/inline-code/inline-code.tsx`, index.mjs:8666).
///
/// Used by: InlineCode, MarkdownInlineCode.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInlineCodeRecipe {
  static const String recipeName = 'inlineCode';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('appearance', ['default', 'message'], 'default', false),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftInlineCodeRecipeStyle resolve({RaftInlineCodeRecipeAppearance? appearance, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [appearance?.css, theme.name], states, tokens);
    return RaftInlineCodeRecipeStyle(root: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [864, 900, 788, 2750, 1689, 3017, 1688, 2987, 3135],
    [2301, 2312, 2818, 2752, 2771, 1689, 3017, 1688, 750, 2939, 983, 1163, 1146],
    [900, 1689, 3017, 2299, 2819, 865, 2749, 2760, 635, 575, 2341, 1690, 3135, 769, 2956],
    [2312, 1689, 3017, 983, 1163, 2299, 2819, 865, 2749, 2760, 635, 575, 2341, 1690, 3135, 795, 2987, 1144],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1], [2], [3],
  ];
}
