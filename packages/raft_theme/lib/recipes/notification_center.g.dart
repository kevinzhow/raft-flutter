// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `notificationCenter`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `viewport` axis of `notificationCenter` (default `desktop`).
enum RaftNotificationCenterRecipeViewport {
  desktop('desktop'),
  mobile('mobile');

  const RaftNotificationCenterRecipeViewport(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `notificationCenter` (default `md`).
enum RaftNotificationCenterRecipeSize {
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftNotificationCenterRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `status` axis of `notificationCenter` (default `info`).
enum RaftNotificationCenterRecipeStatus {
  error('error'),
  warning('warning'),
  info('info'),
  success('success');

  const RaftNotificationCenterRecipeStatus(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftNotificationCenterRecipe].
class RaftNotificationCenterRecipeStyle {
  const RaftNotificationCenterRecipeStyle({
    required this.trigger,
    required this.triggerIcon,
    required this.triggerBell,
    required this.triggerDot,
    required this.popup,
    required this.header,
    required this.title,
    required this.count,
    required this.scroller,
    required this.list,
    required this.item,
    required this.itemRow,
    required this.itemIcon,
    required this.itemContent,
    required this.itemTitle,
    required this.itemBody,
    required this.itemActions,
    required this.actionButton,
  });

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `triggerIcon`.
  final RaftSlotStyle triggerIcon;

  /// Slot `triggerBell`.
  final RaftSlotStyle triggerBell;

  /// Slot `triggerDot`.
  final RaftSlotStyle triggerDot;

  /// Slot `popup`.
  final RaftSlotStyle popup;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `count`.
  final RaftSlotStyle count;

  /// Slot `scroller`.
  final RaftSlotStyle scroller;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `itemRow`.
  final RaftSlotStyle itemRow;

  /// Slot `itemIcon`.
  final RaftSlotStyle itemIcon;

  /// Slot `itemContent`.
  final RaftSlotStyle itemContent;

  /// Slot `itemTitle`.
  final RaftSlotStyle itemTitle;

  /// Slot `itemBody`.
  final RaftSlotStyle itemBody;

  /// Slot `itemActions`.
  final RaftSlotStyle itemActions;

  /// Slot `actionButton`.
  final RaftSlotStyle actionButton;

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'triggerIcon': triggerIcon,
    'triggerBell': triggerBell,
    'triggerDot': triggerDot,
    'popup': popup,
    'header': header,
    'title': title,
    'count': count,
    'scroller': scroller,
    'list': list,
    'item': item,
    'itemRow': itemRow,
    'itemIcon': itemIcon,
    'itemContent': itemContent,
    'itemTitle': itemTitle,
    'itemBody': itemBody,
    'itemActions': itemActions,
    'actionButton': actionButton,
  };
}

/// raft-ui recipe `notificationCenter` (`src/components/notification-center/notification-center.tsx`, index.mjs:12441).
///
/// Used by: NotificationCenterActionButton, NotificationCenterCount, NotificationCenterHeader, NotificationCenterItem, NotificationCenterItemActions, NotificationCenterItemBody, NotificationCenterItemContent, NotificationCenterItemIcon, NotificationCenterItemRow, NotificationCenterItemTitle, NotificationCenterList, NotificationCenterPopup, NotificationCenterScroller, NotificationCenterTitle, NotificationCenterTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftNotificationCenterRecipe {
  static const String recipeName = 'notificationCenter';
  static const List<String> slotNames = [
    'trigger',
    'triggerIcon',
    'triggerBell',
    'triggerDot',
    'popup',
    'header',
    'title',
    'count',
    'scroller',
    'list',
    'item',
    'itemRow',
    'itemIcon',
    'itemContent',
    'itemTitle',
    'itemBody',
    'itemActions',
    'actionButton',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('viewport', ['desktop', 'mobile'], 'desktop', false),
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'md', false),
    RaftRecipeAxis('read', ['true', 'false'], 'false', false),
    RaftRecipeAxis(
      'status',
      ['error', 'warning', 'info', 'success'],
      'info',
      false,
    ),
  ];

  static RaftNotificationCenterRecipeStyle resolve({
    RaftNotificationCenterRecipeViewport? viewport,
    RaftNotificationCenterRecipeSize? size,
    bool? read,
    RaftNotificationCenterRecipeStatus? status,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [viewport?.css, size?.css, read?.toString(), status?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftNotificationCenterRecipeStyle(
      trigger: s[0],
      triggerIcon: s[1],
      triggerBell: s[2],
      triggerDot: s[3],
      popup: s[4],
      header: s[5],
      title: s[6],
      count: s[7],
      scroller: s[8],
      list: s[9],
      item: s[10],
      itemRow: s[11],
      itemIcon: s[12],
      itemContent: s[13],
      itemTitle: s[14],
      itemBody: s[15],
      itemActions: s[16],
      actionButton: s[17],
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
      1682,
      1305,
      1746,
      1319,
      1324,
      1584,
      1592,
      1710,
      622,
      641,
      615,
      1828,
      1727,
      1577,
      1271,
      426,
      886,
      996,
      282,
      277,
    ],
    [1682, 1305, 1754, 1319, 1324],
    [1754, 1740, 1817],
    [1630, 422, 1864, 1687],
    [965, 967, 1583, 1709, 602, 1822, 1737, 1694, 1698, 1919, 1184],
    [965, 1319, 1662, 1471, 1023, 623, 634, 1666, 1636, 1622],
    [1016, 1833, 1822],
    [1499, 1014, 1839, 1824],
    [1468, 966, 1587, 1589],
    [940],
    [
      1153,
      1682,
      1662,
      1673,
      545,
      513,
      554,
      546,
      541,
      536,
      526,
      524,
      1544,
      1257,
      1559,
    ],
    [965, 1321, 1025],
    [965, 1740, 1319, 1324, 1509, 1765, 1716, 290, 617, 1822],
    [1484, 966],
    [1938, 1016, 1845, 1008, 1822, 1122, 1123],
    [1510, 1938, 1353, 1016, 1813, 1827],
    [965, 1319, 1513, 1498, 971, 1328, 1023],
    [],
    [965, 1740, 1319, 1324, 1509, 1765, 1716, 290, 593, 1822],
    [965, 1740, 1319, 1324, 1509, 1765, 1716, 581, 1827, 290],
    [
      1153,
      1682,
      1662,
      1673,
      545,
      513,
      554,
      546,
      541,
      536,
      526,
      524,
      1544,
      1257,
      1639,
      458,
      442,
      465,
      459,
      463,
      460,
      445,
      447,
      443,
    ],
    [965, 967, 1583, 1709, 602, 1822, 1737, 1694, 1698, 1919, 1187],
    [965, 967, 1583, 1709, 602, 1822, 1737, 1694, 1698, 1919, 1190],
    [965, 967, 1583, 1709, 602, 1822, 1737, 1694, 1698, 1926, 1184],
    [965, 967, 1583, 1709, 602, 1822, 1737, 1694, 1698, 1926, 1187],
    [965, 967, 1583, 1709, 602, 1822, 1737, 1694, 1698, 1926, 1190],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 20, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 20, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 10, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 20, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 20, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 10, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 20, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 20, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 10, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 20, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 20, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 10, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 20, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 20, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 25, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 25, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 25, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 25, 5, 6, 7, 8, 9, 10, 11, 19, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 25, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 25, 5, 6, 7, 8, 9, 20, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 25, 5, 6, 7, 8, 9, 20, 11, 18, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 25, 5, 6, 7, 8, 9, 20, 11, 19, 13, 14, 15, 16, 17],
  ];
}
