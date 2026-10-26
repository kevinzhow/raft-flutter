// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageItem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageItemRecipe].
class RaftMessageItemRecipeStyle {
  const RaftMessageItemRecipeStyle({
    required this.root,
    required this.gutter,
    required this.avatarSlot,
    required this.continuationTime,
    required this.content,
    required this.header,
    required this.sender,
    required this.senderBadges,
    required this.meta,
    required this.time,
    required this.inlineStatus,
    required this.body,
    required this.searchMatch,
    required this.embedded,
    required this.attachments,
    required this.footer,
    required this.toolbar,
    required this.toolbarButton,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `gutter`.
  final RaftSlotStyle gutter;

  /// Slot `avatarSlot`.
  final RaftSlotStyle avatarSlot;

  /// Slot `continuationTime`.
  final RaftSlotStyle continuationTime;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `sender`.
  final RaftSlotStyle sender;

  /// Slot `senderBadges`.
  final RaftSlotStyle senderBadges;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `time`.
  final RaftSlotStyle time;

  /// Slot `inlineStatus`.
  final RaftSlotStyle inlineStatus;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `searchMatch`.
  final RaftSlotStyle searchMatch;

  /// Slot `embedded`.
  final RaftSlotStyle embedded;

  /// Slot `attachments`.
  final RaftSlotStyle attachments;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  /// Slot `toolbarButton`.
  final RaftSlotStyle toolbarButton;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'gutter': gutter,
    'avatarSlot': avatarSlot,
    'continuationTime': continuationTime,
    'content': content,
    'header': header,
    'sender': sender,
    'senderBadges': senderBadges,
    'meta': meta,
    'time': time,
    'inlineStatus': inlineStatus,
    'body': body,
    'searchMatch': searchMatch,
    'embedded': embedded,
    'attachments': attachments,
    'footer': footer,
    'toolbar': toolbar,
    'toolbarButton': toolbarButton,
  };
}

/// raft-ui recipe `messageItem` (`src/components/message-item/message-item.recipe.ts`, index.mjs:7069).
///
/// Used by: MessageItem, MessageItemAttachments, MessageItemAvatarSlot, MessageItemBody, MessageItemContent, MessageItemContinuationTime, MessageItemEmbedded, MessageItemFooter, MessageItemGutter, MessageItemHeader, MessageItemInlineStatus, MessageItemMeta, MessageItemSearchMatch, MessageItemSender, MessageItemSenderBadges, MessageItemSenderButton, MessageItemTime, MessageItemToolbar, MessageItemToolbarButton.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageItemRecipe {
  static const String recipeName = 'messageItem';
  static const List<String> slotNames = [
    'root',
    'gutter',
    'avatarSlot',
    'continuationTime',
    'content',
    'header',
    'sender',
    'senderBadges',
    'meta',
    'time',
    'inlineStatus',
    'body',
    'searchMatch',
    'embedded',
    'attachments',
    'footer',
    'toolbar',
    'toolbarButton',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('compact', ['true', 'false'], null, true),
  ];

  static RaftMessageItemRecipeStyle resolve({
    bool? compact,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [compact?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageItemRecipeStyle(
      root: s[0],
      gutter: s[1],
      avatarSlot: s[2],
      continuationTime: s[3],
      content: s[4],
      header: s[5],
      sender: s[6],
      senderBadges: s[7],
      meta: s[8],
      time: s[9],
      inlineStatus: s[10],
      body: s[11],
      searchMatch: s[12],
      embedded: s[13],
      attachments: s[14],
      footer: s[15],
      toolbar: s[16],
      toolbarButton: s[17],
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
    [
      1150,
      1678,
      965,
      1196,
      1024,
      1266,
      1267,
      996,
      997,
      1261,
      1262,
      1465,
      1654,
      1667,
      1271,
      887,
      1263,
      1265,
      1260,
      1253,
      1254,
      1235,
      1236,
    ],
    [1678, 1736, 1728, 1913],
    [1678, 1736, 1727, 965, 1913, 1323, 220],
    [422, 1682, 1723, 1779, 1859, 1013, 1835, 1785],
    [1481, 966, 1806, 1818],
    [1432, 965, 1481, 1318, 1021, 1579],
    [1481, 1736, 1893, 766, 1841, 1007, 1818, 768, 767, 769, 1700, 1573, 995],
    [1304, 1736, 1318, 1020],
    [1481, 1893, 1810, 1820],
    [1736, 1928, 1495, 1013, 1835, 1779, 1820, 1558],
    [1736, 1810, 1820],
    [1933, 1724, 63, 1806, 1818, 1725],
    [418, 1008, 1712, 575, 1661, 650, 1840, 1309, 1312, 1691, 1695],
    [1481, 1509],
    [1773, 1509],
    [1508, 965, 971, 1318, 1021],
    [
      422,
      1936,
      965,
      1318,
      1553,
      421,
      1864,
      1685,
      1019,
      1580,
      1706,
      1596,
      602,
      1690,
      1694,
      1733,
    ],
    [
      1304,
      1736,
      1318,
      1323,
      277,
      1753,
      1706,
      621,
      615,
      1588,
      1823,
      1271,
      427,
      887,
      805,
      1573,
      995,
      290,
    ],
    [
      1150,
      1678,
      965,
      1196,
      1024,
      1266,
      1267,
      996,
      997,
      1261,
      1262,
      1465,
      1654,
      1667,
      1271,
      887,
      1263,
      1265,
      1260,
      1253,
      1254,
      1235,
      1236,
      1638,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
  ];
}
