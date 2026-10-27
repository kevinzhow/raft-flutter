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
      1151,
      1680,
      965,
      1197,
      1025,
      1267,
      1268,
      997,
      998,
      1262,
      1263,
      1467,
      1656,
      1669,
      1272,
      887,
      1264,
      1266,
      1261,
      1254,
      1255,
      1236,
      1237,
    ],
    [1680, 1738, 1730, 1915],
    [1680, 1738, 1729, 965, 1915, 1324, 220],
    [422, 1684, 1725, 1781, 1861, 1014, 1837, 1787],
    [1483, 966, 1808, 1820],
    [1434, 965, 1483, 1319, 1022, 1581],
    [1483, 1738, 1895, 766, 1843, 1008, 1820, 768, 767, 769, 1702, 1575, 996],
    [1305, 1738, 1319, 1021],
    [1483, 1895, 1812, 1822],
    [1738, 1930, 1497, 1014, 1837, 1781, 1822, 1560],
    [1738, 1812, 1822],
    [1935, 1726, 63, 1808, 1820, 1727],
    [418, 1009, 1714, 575, 1663, 650, 1842, 1310, 1313, 1693, 1697],
    [1483, 1511],
    [1775, 1511],
    [1510, 965, 971, 1319, 1022],
    [
      422,
      1938,
      965,
      1319,
      1555,
      421,
      1866,
      1687,
      1020,
      1582,
      1708,
      1598,
      602,
      1692,
      1696,
      1735,
    ],
    [
      1305,
      1738,
      1319,
      1324,
      277,
      1755,
      1708,
      621,
      615,
      1590,
      1825,
      1272,
      427,
      887,
      805,
      1575,
      996,
      290,
    ],
    [
      1151,
      1680,
      965,
      1197,
      1025,
      1267,
      1268,
      997,
      998,
      1262,
      1263,
      1467,
      1656,
      1669,
      1272,
      887,
      1264,
      1266,
      1261,
      1254,
      1255,
      1236,
      1237,
      1640,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
  ];
}
