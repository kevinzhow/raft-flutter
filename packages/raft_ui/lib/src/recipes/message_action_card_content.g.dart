// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageActionCardContent`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageActionCardContentRecipe].
class RaftMessageActionCardContentRecipeStyle {
  const RaftMessageActionCardContentRecipeStyle({required this.root, required this.properties, required this.property, required this.propertyLabel, required this.propertyValue, required this.scopeList, required this.scopeListLabel, required this.scope, required this.scopeName, required this.scopeDescription, required this.hint, required this.completion, required this.actions});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `properties`.
  final RaftSlotStyle properties;
  /// Slot `property`.
  final RaftSlotStyle property;
  /// Slot `propertyLabel`.
  final RaftSlotStyle propertyLabel;
  /// Slot `propertyValue`.
  final RaftSlotStyle propertyValue;
  /// Slot `scopeList`.
  final RaftSlotStyle scopeList;
  /// Slot `scopeListLabel`.
  final RaftSlotStyle scopeListLabel;
  /// Slot `scope`.
  final RaftSlotStyle scope;
  /// Slot `scopeName`.
  final RaftSlotStyle scopeName;
  /// Slot `scopeDescription`.
  final RaftSlotStyle scopeDescription;
  /// Slot `hint`.
  final RaftSlotStyle hint;
  /// Slot `completion`.
  final RaftSlotStyle completion;
  /// Slot `actions`.
  final RaftSlotStyle actions;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'properties': properties, 'property': property, 'propertyLabel': propertyLabel, 'propertyValue': propertyValue, 'scopeList': scopeList, 'scopeListLabel': scopeListLabel, 'scope': scope, 'scopeName': scopeName, 'scopeDescription': scopeDescription, 'hint': hint, 'completion': completion, 'actions': actions};
}

/// raft-ui recipe `messageActionCardContent` (`src/components/message-action-card/message-action-card-content.recipe.ts`, index.mjs:10691).
///
/// Used by: MessageActionCardActions, MessageActionCardCompletion, MessageActionCardContent, MessageActionCardHint, MessageActionCardProperties, MessageActionCardProperty, MessageActionCardPropertyLabel, MessageActionCardPropertyValue, MessageActionCardScope, MessageActionCardScopeDescription, MessageActionCardScopeList, MessageActionCardScopeListLabel, MessageActionCardScopeName.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageActionCardContentRecipe {
  static const String recipeName = 'messageActionCardContent';
  static const List<String> slotNames = ['root', 'properties', 'property', 'propertyLabel', 'propertyValue', 'scopeList', 'scopeListLabel', 'scope', 'scopeName', 'scopeDescription', 'hint', 'completion', 'actions'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageActionCardContentRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageActionCardContentRecipeStyle(root: s[0], properties: s[1], property: s[2], propertyLabel: s[3], propertyValue: s[4], scopeList: s[5], scopeListLabel: s[6], scope: s[7], scopeName: s[8], scopeDescription: s[9], hint: s[10], completion: s[11], actions: s[12]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2672, 2731],
    [2359, 1717, 1720, 2311, 2464, 2463, 2598, 1708, 1714],
    [938],
    [2466, 2574, 3136, 3032, 2962],
    [2359, 2574, 3136, 3032, 2965],
    [2602, 2900],
    [3032, 2333, 1690, 2962],
    [2574, 864, 2670, 878, 856],
    [932, 1689, 2920, 1684, 2962],
    [3032, 2346, 2963],
    [2598, 892, 879, 2699, 3032, 2310, 2962],
    [2598, 3032, 2962],
    [1620, 1626, 2312, 2601, 1700],
    [2672, 2754, 2736, 2686, 2895],
    [2359, 1717, 1720, 2311, 2464, 2463, 2600, 1711, 1716],
    [2466, 2574, 3136, 2924, 2335, 2983],
    [2359, 2574, 3136, 2924, 2335, 2987],
    [2602, 2901],
    [2924, 2335, 1688, 2987],
    [2574, 864, 2670, 2818, 896, 827, 2752, 2765, 2865, 1009, 983],
    [932, 1691, 3032, 2333, 1688, 2981],
    [2597, 2924, 2335, 3005, 2983],
    [2601, 891, 896, 2700, 3032, 2333, 2310, 2983],
    [2601, 2924, 2335, 2981],
    [1620, 1626, 2312, 2602, 1698],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [13, 14, 2, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24],
  ];
}
