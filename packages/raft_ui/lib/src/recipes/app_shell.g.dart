// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `appShell`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftAppShellRecipe].
class RaftAppShellRecipeStyle {
  const RaftAppShellRecipeStyle({
    required this.root,
    required this.railSlot,
    required this.sidebarSlot,
    required this.mainSlot,
    required this.panelSlot,
    required this.overlaySlot,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `railSlot`.
  final RaftSlotStyle railSlot;

  /// Slot `sidebarSlot`.
  final RaftSlotStyle sidebarSlot;

  /// Slot `mainSlot`.
  final RaftSlotStyle mainSlot;

  /// Slot `panelSlot`.
  final RaftSlotStyle panelSlot;

  /// Slot `overlaySlot`.
  final RaftSlotStyle overlaySlot;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'railSlot': railSlot,
    'sidebarSlot': sidebarSlot,
    'mainSlot': mainSlot,
    'panelSlot': panelSlot,
    'overlaySlot': overlaySlot,
  };
}

/// raft-ui recipe `appShell` (`src/components/app-shell/app-shell.tsx`, index.mjs:16620).
///
/// Used by: AppShellMainSlot, AppShellOverlaySlot, AppShellPanelSlot, AppShellRailSlot, AppShellRoot, AppShellSidebarSlot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAppShellRecipe {
  static const String recipeName = 'appShell';
  static const List<String> slotNames = [
    'root',
    'railSlot',
    'sidebarSlot',
    'mainSlot',
    'panelSlot',
    'overlaySlot',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('overlay', ['false', 'true'], 'false', false),
  ];

  static RaftAppShellRecipeStyle resolve({
    required RaftRecipeTheme theme,
    bool? overlay,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, overlay?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftAppShellRecipeStyle(
      root: s[0],
      railSlot: s[1],
      sidebarSlot: s[2],
      mainSlot: s[3],
      panelSlot: s[4],
      overlaySlot: s[5],
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
    [1644, 2583, 3168, 2680, 2564, 2425, 2467, 1716, 538, 776, 2994, 2419],
    [2189, 1980, 2902, 1646, 2535],
    [2189, 2583, 2902, 1646, 2535],
    [1644, 2583, 2597, 1645, 1646],
    [2189, 2583, 2597, 1646, 2535],
    [586, 2322, 3180, 1644, 2583, 2597],
    [1644, 2583, 2597, 1645, 1646, 2804],
    [1644, 2583, 3168, 2680, 2564, 2425, 2467, 1716, 3024, 537, 825],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 6, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [7, 1, 2, 6, 4, 5],
  ];
}
