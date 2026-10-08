// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `appShell`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftAppShellRecipe].
class RaftAppShellRecipeStyle {
  const RaftAppShellRecipeStyle({required this.root, required this.railSlot, required this.sidebarSlot, required this.mainSlot, required this.panelSlot, required this.overlaySlot});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'railSlot': railSlot, 'sidebarSlot': sidebarSlot, 'mainSlot': mainSlot, 'panelSlot': panelSlot, 'overlaySlot': overlaySlot};
}

/// raft-ui recipe `appShell` (`src/components/app-shell/app-shell.tsx`, index.mjs:16366).
///
/// Used by: AppShellMainSlot, AppShellOverlaySlot, AppShellPanelSlot, AppShellRailSlot, AppShellRoot, AppShellSidebarSlot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAppShellRecipe {
  static const String recipeName = 'appShell';
  static const List<String> slotNames = ['root', 'railSlot', 'sidebarSlot', 'mainSlot', 'panelSlot', 'overlaySlot'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('overlay', ['false', 'true'], 'false', false),
  ];

  static RaftAppShellRecipeStyle resolve({required RaftRecipeTheme theme, bool? overlay, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, overlay?.toString()], states, tokens);
    return RaftAppShellRecipeStyle(root: s[0], railSlot: s[1], sidebarSlot: s[2], mainSlot: s[3], panelSlot: s[4], overlaySlot: s[5]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2560, 3127, 2657, 2541, 2404, 2447, 1691, 537, 770, 2956, 2397],
    [2174, 1978, 2867, 1622, 2513],
    [2174, 2560, 2867, 1622, 2513],
    [1620, 2560, 2574, 1621, 1622],
    [2174, 2560, 2574, 1622, 2513],
    [580, 2303, 3139, 1620, 2560, 2574],
    [1620, 2560, 2574, 1621, 1622, 2775],
    [1620, 2560, 3127, 2657, 2541, 2404, 2447, 1691, 2987, 536, 820],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5], [0, 1, 2, 6, 4, 5], [7, 1, 2, 3, 4, 5], [7, 1, 2, 6, 4, 5],
  ];
}
