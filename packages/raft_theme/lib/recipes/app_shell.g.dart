// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `appShell` (`src/components/app-shell/app-shell.tsx`, index.mjs:13730).
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
    RaftRecipeAxis('overlay', ['false', 'true'], 'false', false),
  ];

  static RaftAppShellRecipeStyle resolve({
    bool? overlay,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [overlay?.toString()],
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
    [965, 1467, 1926, 1582, 1461, 1380, 1391, 1016, 354, 383, 595, 1820],
    [1265, 1198, 1738, 967, 1439],
    [1265, 1467, 1738, 967, 1439],
    [965, 1467, 1483, 966, 967],
    [1265, 1467, 1483, 967, 1439],
    [422, 1307, 1938, 965, 1467, 1483],
    [965, 1467, 1483, 966, 967, 1680],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 6, 4, 5],
  ];
}
