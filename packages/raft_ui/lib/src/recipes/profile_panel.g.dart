// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `profilePanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftProfilePanelRecipe].
class RaftProfilePanelRecipeStyle {
  const RaftProfilePanelRecipeStyle({required this.root, required this.header, required this.headerContent, required this.section});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `headerContent`.
  final RaftSlotStyle headerContent;
  /// Slot `section`.
  final RaftSlotStyle section;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'headerContent': headerContent, 'section': section};
}

/// raft-ui recipe `profilePanel` (`src/components/profile-panel/profile-panel.recipe.ts`, index.mjs:16925).
///
/// Used by: ProfilePanel, ProfilePanelHeader, ProfilePanelHeaderContent, ProfilePanelSection.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftProfilePanelRecipe {
  static const String recipeName = 'profilePanel';
  static const List<String> slotNames = ['root', 'header', 'headerContent', 'section'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftProfilePanelRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftProfilePanelRecipeStyle(root: s[0], header: s[1], headerContent: s[2], section: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 1978, 2560, 2574, 1621, 1622, 508, 825],
    [],
    [1620, 1978, 2560, 2574, 1621, 1622, 508, 2775, 820, 1691, 2987],
    [2403, 2452, 2549],
    [2515, 2535, 2521],
    [896, 2757, 2770],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 1, 1], [2, 3, 4, 5],
  ];
}
