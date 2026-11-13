// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `lightbox`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftLightboxRecipe].
class RaftLightboxRecipeStyle {
  const RaftLightboxRecipeStyle({
    required this.portal,
    required this.backdrop,
    required this.content,
    required this.header,
    required this.toolbar,
    required this.headerMeta,
    required this.headerLabel,
    required this.title,
    required this.actions,
    required this.body,
    required this.bodyContent,
    required this.stage,
    required this.media,
    required this.navigationButton,
    required this.infoDock,
    required this.infoBar,
    required this.infoTitle,
    required this.infoActions,
    required this.thumbnailStrip,
    required this.thumbnail,
    required this.thumbnailOverlay,
    required this.close,
  });

  /// Slot `portal`.
  final RaftSlotStyle portal;

  /// Slot `backdrop`.
  final RaftSlotStyle backdrop;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  /// Slot `headerMeta`.
  final RaftSlotStyle headerMeta;

  /// Slot `headerLabel`.
  final RaftSlotStyle headerLabel;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `bodyContent`.
  final RaftSlotStyle bodyContent;

  /// Slot `stage`.
  final RaftSlotStyle stage;

  /// Slot `media`.
  final RaftSlotStyle media;

  /// Slot `navigationButton`.
  final RaftSlotStyle navigationButton;

  /// Slot `infoDock`.
  final RaftSlotStyle infoDock;

  /// Slot `infoBar`.
  final RaftSlotStyle infoBar;

  /// Slot `infoTitle`.
  final RaftSlotStyle infoTitle;

  /// Slot `infoActions`.
  final RaftSlotStyle infoActions;

  /// Slot `thumbnailStrip`.
  final RaftSlotStyle thumbnailStrip;

  /// Slot `thumbnail`.
  final RaftSlotStyle thumbnail;

  /// Slot `thumbnailOverlay`.
  final RaftSlotStyle thumbnailOverlay;

  /// Slot `close`.
  final RaftSlotStyle close;

  Map<String, RaftSlotStyle> get slots => {
    'portal': portal,
    'backdrop': backdrop,
    'content': content,
    'header': header,
    'toolbar': toolbar,
    'headerMeta': headerMeta,
    'headerLabel': headerLabel,
    'title': title,
    'actions': actions,
    'body': body,
    'bodyContent': bodyContent,
    'stage': stage,
    'media': media,
    'navigationButton': navigationButton,
    'infoDock': infoDock,
    'infoBar': infoBar,
    'infoTitle': infoTitle,
    'infoActions': infoActions,
    'thumbnailStrip': thumbnailStrip,
    'thumbnail': thumbnail,
    'thumbnailOverlay': thumbnailOverlay,
    'close': close,
  };
}

/// raft-ui recipe `lightbox` (`dist/components/lightbox/lightbox.mjs`, index.mjs:6176).
///
/// Used by: LightboxActions, LightboxBody, LightboxClose, LightboxContent, LightboxHeader, LightboxHeaderLabel, LightboxHeaderMeta, LightboxInfoActions, LightboxInfoBar, LightboxInfoDock, LightboxInfoTitle, LightboxMedia, LightboxNavigationButton, LightboxPortal, LightboxStage, LightboxThumbnail, LightboxThumbnailStrip, LightboxTitle, LightboxToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLightboxRecipe {
  static const String recipeName = 'lightbox';
  static const List<String> slotNames = [
    'portal',
    'backdrop',
    'content',
    'header',
    'toolbar',
    'headerMeta',
    'headerLabel',
    'title',
    'actions',
    'body',
    'bodyContent',
    'stage',
    'media',
    'navigationButton',
    'infoDock',
    'infoBar',
    'infoTitle',
    'infoActions',
    'thumbnailStrip',
    'thumbnail',
    'thumbnailOverlay',
    'close',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('nested', ['true', 'false'], null, true),
  ];

  static RaftLightboxRecipeStyle resolve({
    bool? nested,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [nested?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftLightboxRecipeStyle(
      portal: s[0],
      backdrop: s[1],
      content: s[2],
      header: s[3],
      toolbar: s[4],
      headerMeta: s[5],
      headerLabel: s[6],
      title: s[7],
      actions: s[8],
      body: s[9],
      bodyContent: s[10],
      stage: s[11],
      media: s[12],
      navigationButton: s[13],
      infoDock: s[14],
      infoBar: s[15],
      infoTitle: s[16],
      infoActions: s[17],
      thumbnailStrip: s[18],
      thumbnail: s[19],
      thumbnailOverlay: s[20],
      close: s[21],
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
    [2433, 1862, 2745],
    [1399, 1849, 908, 1168],
    [2346, 1399, 1849, 1400, 1404, 1168, 151, 150, 154, 153, 152],
    [2345, 2499, 1400, 1864, 1468, 2276, 2387, 2307, 2364, 933, 2497, 265, 267],
    [
      2345,
      2499,
      1400,
      1864,
      1468,
      1671,
      2390,
      2306,
      2363,
      77,
      75,
      78,
      76,
      942,
      954,
      910,
      2497,
      265,
      267,
    ],
    [1400, 2116, 1401, 1864, 1465],
    [
      1847,
      2499,
      1864,
      2400,
      1666,
      2461,
      895,
      2412,
      1456,
      2588,
      1457,
      2165,
      2654,
      2603,
    ],
    [2116, 1401, 2681, 2412, 1456, 2609, 1449, 2598],
    [1400, 2499, 1864, 1464, 267],
    [2345, 2098, 1401, 2258, 910, 1440, 1424, 1416, 1425],
    [2368, 2287, 2310],
    [2346, 2433, 1400, 2098, 1401, 1864, 1869, 2252],
    [2345, 1919, 1972, 940, 933, 2497],
    [
      2345,
      691,
      2747,
      1847,
      1864,
      1869,
      2663,
      1366,
      2245,
      2248,
      2250,
      1009,
      472,
      474,
      2510,
      2463,
      941,
      955,
      911,
      2598,
      2497,
      1794,
      699,
      1434,
      1439,
      481,
    ],
    [2346, 691, 2441, 968, 1898, 2747, 1400, 1869],
    [
      2345,
      1400,
      1864,
      2719,
      1974,
      2118,
      1466,
      2462,
      2414,
      2355,
      2299,
      915,
      2598,
      2496,
      2445,
      2449,
    ],
    [2116, 1401, 2681, 1456, 2597, 1457, 2598],
    [1400, 2499, 1864, 1464, 94, 101, 97, 99, 91, 93, 96, 2313],
    [2346, 691, 2437, 969, 1895, 2747, 1400, 1864, 1869, 1465],
    [
      1611,
      2345,
      2433,
      2511,
      2252,
      2665,
      1366,
      431,
      432,
      430,
      2463,
      941,
      2229,
      2497,
      959,
      1790,
      1132,
    ],
    [2346, 691, 1849, 937, 2675, 1366, 909, 1587, 1557],
    [2345],
    [1399, 1849, 1168, 909],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
    ],
    [
      0,
      22,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
    ],
    [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
    ],
  ];
}
