// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `lightbox`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftLightboxRecipe].
class RaftLightboxRecipeStyle {
  const RaftLightboxRecipeStyle({
    required this.backdrop,
    required this.content,
    required this.header,
    required this.toolbar,
    required this.headerMeta,
    required this.headerLabel,
    required this.title,
    required this.actions,
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
    'backdrop': backdrop,
    'content': content,
    'header': header,
    'toolbar': toolbar,
    'headerMeta': headerMeta,
    'headerLabel': headerLabel,
    'title': title,
    'actions': actions,
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

/// raft-ui recipe `lightbox` (`src/components/lightbox/lightbox.tsx`, index.mjs:4271).
///
/// Used by: LightboxActions, LightboxClose, LightboxContent, LightboxHeader, LightboxHeaderLabel, LightboxHeaderMeta, LightboxInfoActions, LightboxInfoBar, LightboxInfoDock, LightboxInfoTitle, LightboxMedia, LightboxNavigationButton, LightboxStage, LightboxThumbnail, LightboxThumbnailStrip, LightboxTitle, LightboxToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLightboxRecipe {
  static const String recipeName = 'lightbox';
  static const List<String> slotNames = [
    'backdrop',
    'content',
    'header',
    'toolbar',
    'headerMeta',
    'headerLabel',
    'title',
    'actions',
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftLightboxRecipeStyle resolve({
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
    return RaftLightboxRecipeStyle(
      backdrop: s[0],
      content: s[1],
      header: s[2],
      toolbar: s[3],
      headerMeta: s[4],
      headerLabel: s[5],
      title: s[6],
      actions: s[7],
      stage: s[8],
      media: s[9],
      navigationButton: s[10],
      infoDock: s[11],
      infoBar: s[12],
      infoTitle: s[13],
      infoActions: s[14],
      thumbnailStrip: s[15],
      thumbnail: s[16],
      thumbnailOverlay: s[17],
      close: s[18],
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
    [964, 1307, 1946, 594, 822],
    [1630, 964, 1307, 1947, 965, 967, 822, 87, 86, 90, 89, 88],
    [1629, 1740, 965, 1319, 1025, 1607, 1651, 1627, 1641, 615, 1738],
    [
      1629,
      1740,
      965,
      1319,
      1025,
      1194,
      1652,
      1626,
      1640,
      58,
      56,
      59,
      57,
      623,
      634,
      595,
      1738,
    ],
    [965, 1484, 966, 1319, 1022],
    [
      1305,
      1740,
      1319,
      1657,
      1191,
      1708,
      581,
      1666,
      1016,
      1814,
      1017,
      1529,
      1873,
      1827,
    ],
    [1484, 966, 1897, 1666, 1016, 1833, 1008, 1822],
    [965, 1740, 1319, 1021],
    [1630, 1682, 965, 1468, 966, 1319, 1324, 1583],
    [1629, 1365, 1418, 621, 615, 1738],
    [
      1629,
      422,
      1940,
      1305,
      1319,
      1324,
      1882,
      942,
      1575,
      1578,
      1580,
      677,
      275,
      277,
      1747,
      1710,
      622,
      635,
      596,
      1822,
      1738,
      1274,
      1283,
      429,
      989,
      996,
      283,
    ],
    [1630, 422, 1691, 646, 1352, 1940, 965, 1324],
    [
      1629,
      965,
      1319,
      1923,
      1419,
      1487,
      1023,
      1709,
      1667,
      1633,
      1619,
      602,
      1822,
      1737,
      1694,
      1698,
    ],
    [1484, 966, 1897, 1016, 1821, 1017, 1822],
    [1630, 422, 1686, 647, 1349, 1940, 965, 1319, 1324, 1022],
    [
      1149,
      1629,
      1682,
      1748,
      1583,
      1884,
      942,
      244,
      245,
      243,
      1710,
      622,
      1559,
      1738,
      638,
      1277,
      797,
    ],
    [1630, 422, 1307, 618, 1893, 942, 574, 1128, 1111],
    [1629],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 7, 14, 15, 16, 17],
  ];
}
