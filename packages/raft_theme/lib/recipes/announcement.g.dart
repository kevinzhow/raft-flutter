// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `announcement`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftAnnouncementRecipe].
class RaftAnnouncementRecipeStyle {
  const RaftAnnouncementRecipeStyle({
    required this.content,
    required this.body,
    required this.header,
    required this.label,
    required this.dot,
    required this.title,
    required this.picture,
    required this.text,
    required this.footer,
    required this.action,
    required this.secondary,
  });

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `dot`.
  final RaftSlotStyle dot;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `picture`.
  final RaftSlotStyle picture;

  /// Slot `text`.
  final RaftSlotStyle text;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  /// Slot `action`.
  final RaftSlotStyle action;

  /// Slot `secondary`.
  final RaftSlotStyle secondary;

  Map<String, RaftSlotStyle> get slots => {
    'content': content,
    'body': body,
    'header': header,
    'label': label,
    'dot': dot,
    'title': title,
    'picture': picture,
    'text': text,
    'footer': footer,
    'action': action,
    'secondary': secondary,
  };
}

/// raft-ui recipe `announcement` (`dist/components/announcement-dialog/announcement-dialog.mjs`, index.mjs:26483).
///
/// Used by: AnnouncementDialogAction, AnnouncementDialogBody, AnnouncementDialogContent, AnnouncementDialogFooter, AnnouncementDialogHeader, AnnouncementDialogLabel, AnnouncementDialogPicture, AnnouncementDialogSecondaryAction, AnnouncementDialogText, AnnouncementDialogTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAnnouncementRecipe {
  static const String recipeName = 'announcement';
  static const List<String> slotNames = [
    'content',
    'body',
    'header',
    'label',
    'dot',
    'title',
    'picture',
    'text',
    'footer',
    'action',
    'secondary',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftAnnouncementRecipeStyle resolve({
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
    return RaftAnnouncementRecipeStyle(
      content: s[0],
      body: s[1],
      header: s[2],
      label: s[3],
      dot: s[4],
      title: s[5],
      picture: s[6],
      text: s[7],
      footer: s[8],
      action: s[9],
      secondary: s[10],
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
    [195, 1985, 1462, 2251, 2260],
    [2098, 1918, 2278, 394, 2396, 2377],
    [1400, 2116, 1864, 1868, 1468],
    [1400, 2116, 1864, 1466, 2734, 2588, 2603],
    [2499, 2514, 2457, 941, 958, 885],
    [2148, 2734, 2165, 2609, 1449, 2654],
    [2150, 1655, 2725, 2252, 939, 953, 432, 429, 2462, 895],
    [
      2148,
      2116,
      2734,
      435,
      497,
      433,
      498,
      434,
      422,
      424,
      426,
      421,
      423,
      425,
      438,
      440,
      2622,
      2603,
    ],
    [1400, 2499, 1408, 1864, 1868, 1468, 953, 2421, 204, 962, 2396, 2378, 2271],
    [2132, 1673, 2107, 2116, 1980, 2414, 2728, 2590, 1449, 205, 206],
    [2116, 1980, 2728, 206],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  ];
}
