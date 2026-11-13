// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `appShell`.
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

/// raft-ui recipe `appShell` (`dist/components/app-shell/app-shell.mjs`, index.mjs:19751).
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
    [1400, 2098, 2725, 2253, 2007, 1934, 1944, 1456, 577, 607, 910, 2598],
    [1776, 1678, 2499, 1404, 1998],
    [1776, 2098, 2499, 1404, 1998],
    [1400, 2098, 2116, 1401, 1404],
    [1776, 2098, 2116, 1404, 1998],
    [691, 1849, 2740, 1400, 2098, 2116],
    [1400, 2098, 2116, 1401, 1404, 2433],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 6, 4, 5],
  ];
}
