// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `profilePanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftProfilePanelRecipe].
class RaftProfilePanelRecipeStyle {
  const RaftProfilePanelRecipeStyle({
    required this.root,
    required this.header,
    required this.headerContent,
    required this.section,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `headerContent`.
  final RaftSlotStyle headerContent;

  /// Slot `section`.
  final RaftSlotStyle section;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'headerContent': headerContent,
    'section': section,
  };
}

/// raft-ui recipe `profilePanel` (`src/components/profile-panel/profile-panel.recipe.ts`, index.mjs:14192).
///
/// Used by: ProfilePanel, ProfilePanelHeader, ProfilePanelHeaderContent, ProfilePanelSection.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftProfilePanelRecipe {
  static const String recipeName = 'profilePanel';
  static const List<String> slotNames = [
    'root',
    'header',
    'headerContent',
    'section',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftProfilePanelRecipeStyle resolve({
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
    return RaftProfilePanelRecipeStyle(
      root: s[0],
      header: s[1],
      headerContent: s[2],
      section: s[3],
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
    [965, 1198, 1468, 1484, 966, 967, 340, 1682, 595, 1016, 1822],
    [],
    [1322, 1019],
    [633, 1663, 1675],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
