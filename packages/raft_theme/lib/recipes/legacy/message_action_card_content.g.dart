// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageActionCardContent`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageActionCardContentRecipe].
class RaftMessageActionCardContentRecipeStyle {
  const RaftMessageActionCardContentRecipeStyle({
    required this.root,
    required this.properties,
    required this.property,
    required this.propertyLabel,
    required this.propertyValue,
    required this.scopeList,
    required this.scopeListLabel,
    required this.scope,
    required this.scopeName,
    required this.scopeDescription,
    required this.hint,
    required this.completion,
    required this.actions,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'properties': properties,
    'property': property,
    'propertyLabel': propertyLabel,
    'propertyValue': propertyValue,
    'scopeList': scopeList,
    'scopeListLabel': scopeListLabel,
    'scope': scope,
    'scopeName': scopeName,
    'scopeDescription': scopeDescription,
    'hint': hint,
    'completion': completion,
    'actions': actions,
  };
}

/// raft-ui recipe `messageActionCardContent` (`src/components/message-action-card/message-action-card-content.recipe.ts`, index.mjs:10734).
///
/// Used by: MessageActionCardActions, MessageActionCardCompletion, MessageActionCardContent, MessageActionCardHint, MessageActionCardProperties, MessageActionCardProperty, MessageActionCardPropertyLabel, MessageActionCardPropertyValue, MessageActionCardScope, MessageActionCardScopeDescription, MessageActionCardScopeList, MessageActionCardScopeListLabel, MessageActionCardScopeName.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageActionCardContentRecipe {
  static const String recipeName = 'messageActionCardContent';
  static const List<String> slotNames = [
    'root',
    'properties',
    'property',
    'propertyLabel',
    'propertyValue',
    'scopeList',
    'scopeListLabel',
    'scope',
    'scopeName',
    'scopeDescription',
    'hint',
    'completion',
    'actions',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageActionCardContentRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageActionCardContentRecipeStyle(
      root: s[0],
      properties: s[1],
      property: s[2],
      propertyLabel: s[3],
      propertyValue: s[4],
      scopeList: s[5],
      scopeListLabel: s[6],
      scope: s[7],
      scopeName: s[8],
      scopeDescription: s[9],
      hint: s[10],
      completion: s[11],
      actions: s[12],
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
    [2695, 2756],
    [2378, 1742, 1745, 2330, 2484, 2483, 2621, 1733, 1739],
    [958],
    [2487, 2597, 3177, 3073, 2999],
    [2378, 2597, 3177, 3073, 3002],
    [2625, 2935],
    [3073, 2352, 1715, 2999],
    [2597, 876, 2693, 894, 868],
    [945, 1714, 2958, 1709, 2999],
    [3073, 2365, 3000],
    [2621, 908, 895, 2722, 3073, 2329, 2999],
    [2621, 3073, 2999],
    [1644, 1650, 2331, 2624, 1725],
    [2695, 2782, 2761, 2709, 2930],
    [2378, 1742, 1745, 2330, 2484, 2483, 2623, 1736, 1741],
    [2487, 2597, 3177, 2962, 2354, 3020],
    [2378, 2597, 3177, 2962, 2354, 3024],
    [2625, 2936],
    [2962, 2354, 1713, 3024],
    [2597, 876, 2693, 2848, 912, 832, 2780, 2794, 2899, 1029, 1003],
    [945, 1716, 3073, 2352, 1713, 3018],
    [2620, 2962, 2354, 3042, 3020],
    [2624, 907, 912, 2723, 3073, 2352, 2329, 3020],
    [2624, 2962, 2354, 3018],
    [1644, 1650, 2331, 2625, 1723],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    [13, 14, 2, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24],
  ];
}
