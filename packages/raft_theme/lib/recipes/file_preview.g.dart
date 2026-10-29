// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `filePreview`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `placement` axis of `filePreview` (default `corner`).
enum RaftFilePreviewRecipePlacement {
  corner('corner'),
  inline('inline');

  const RaftFilePreviewRecipePlacement(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftFilePreviewRecipe].
class RaftFilePreviewRecipeStyle {
  const RaftFilePreviewRecipeStyle({
    required this.root,
    required this.document,
    required this.file,
    required this.code,
    required this.fileZip,
    required this.fileZipStack,
    required this.fileZipTeeth,
    required this.fileZipRow,
    required this.fileZipDark,
    required this.fileZipLight,
    required this.fileZipPull,
    required this.codeStack,
    required this.codeRow,
    required this.codeRowIndent,
    required this.codeTextRow,
    required this.codeGlyph,
    required this.codeTagLine,
    required this.codeAttributeLine,
    required this.codeTextLine,
    required this.codeSelfClosingLine,
    required this.badge,
    required this.media,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `document`.
  final RaftSlotStyle document;

  /// Slot `file`.
  final RaftSlotStyle file;

  /// Slot `code`.
  final RaftSlotStyle code;

  /// Slot `fileZip`.
  final RaftSlotStyle fileZip;

  /// Slot `fileZipStack`.
  final RaftSlotStyle fileZipStack;

  /// Slot `fileZipTeeth`.
  final RaftSlotStyle fileZipTeeth;

  /// Slot `fileZipRow`.
  final RaftSlotStyle fileZipRow;

  /// Slot `fileZipDark`.
  final RaftSlotStyle fileZipDark;

  /// Slot `fileZipLight`.
  final RaftSlotStyle fileZipLight;

  /// Slot `fileZipPull`.
  final RaftSlotStyle fileZipPull;

  /// Slot `codeStack`.
  final RaftSlotStyle codeStack;

  /// Slot `codeRow`.
  final RaftSlotStyle codeRow;

  /// Slot `codeRowIndent`.
  final RaftSlotStyle codeRowIndent;

  /// Slot `codeTextRow`.
  final RaftSlotStyle codeTextRow;

  /// Slot `codeGlyph`.
  final RaftSlotStyle codeGlyph;

  /// Slot `codeTagLine`.
  final RaftSlotStyle codeTagLine;

  /// Slot `codeAttributeLine`.
  final RaftSlotStyle codeAttributeLine;

  /// Slot `codeTextLine`.
  final RaftSlotStyle codeTextLine;

  /// Slot `codeSelfClosingLine`.
  final RaftSlotStyle codeSelfClosingLine;

  /// Slot `badge`.
  final RaftSlotStyle badge;

  /// Slot `media`.
  final RaftSlotStyle media;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'document': document,
    'file': file,
    'code': code,
    'fileZip': fileZip,
    'fileZipStack': fileZipStack,
    'fileZipTeeth': fileZipTeeth,
    'fileZipRow': fileZipRow,
    'fileZipDark': fileZipDark,
    'fileZipLight': fileZipLight,
    'fileZipPull': fileZipPull,
    'codeStack': codeStack,
    'codeRow': codeRow,
    'codeRowIndent': codeRowIndent,
    'codeTextRow': codeTextRow,
    'codeGlyph': codeGlyph,
    'codeTagLine': codeTagLine,
    'codeAttributeLine': codeAttributeLine,
    'codeTextLine': codeTextLine,
    'codeSelfClosingLine': codeSelfClosingLine,
    'badge': badge,
    'media': media,
  };
}

/// raft-ui recipe `filePreview` (`src/components/file-preview/file-preview.recipe.ts`, index.mjs:10780).
///
/// Used by: FilePreview, FilePreviewBadge, FilePreviewCode, FilePreviewDocument, FilePreviewFile, FilePreviewMedia.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftFilePreviewRecipe {
  static const String recipeName = 'filePreview';
  static const List<String> slotNames = [
    'root',
    'document',
    'file',
    'code',
    'fileZip',
    'fileZipStack',
    'fileZipTeeth',
    'fileZipRow',
    'fileZipDark',
    'fileZipLight',
    'fileZipPull',
    'codeStack',
    'codeRow',
    'codeRowIndent',
    'codeTextRow',
    'codeGlyph',
    'codeTagLine',
    'codeAttributeLine',
    'codeTextLine',
    'codeSelfClosingLine',
    'badge',
    'media',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('placement', ['corner', 'inline'], 'corner', false),
  ];

  static RaftFilePreviewRecipeStyle resolve({
    RaftFilePreviewRecipePlacement? placement,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [placement?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftFilePreviewRecipeStyle(
      root: s[0],
      document: s[1],
      file: s[2],
      code: s[3],
      fileZip: s[4],
      fileZipStack: s[5],
      fileZipTeeth: s[6],
      fileZipRow: s[7],
      fileZipDark: s[8],
      fileZipLight: s[9],
      fileZipPull: s[10],
      codeStack: s[11],
      codeRow: s[12],
      codeRowIndent: s[13],
      codeTextRow: s[14],
      codeGlyph: s[15],
      codeTagLine: s[16],
      codeAttributeLine: s[17],
      codeTextLine: s[18],
      codeSelfClosingLine: s[19],
      badge: s[20],
      media: s[21],
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
    [1682, 965, 1173, 1902, 1740, 1319, 1324],
    [1682, 1173, 1914, 1776, 1713, 1718, 1594, 1694, 596, 1738, 1697],
    [1682, 965, 1173, 1914, 1319, 1324, 1713, 1718, 1694, 596, 1738, 1697],
    [965, 1186, 1319, 1324],
    [1682, 109, 965, 967, 1319],
    [1780],
    [965, 1583, 1712],
    [1743, 589],
    [1743, 586],
    [1510, 1172, 1906, 1715, 620, 629, 585],
    [109, 1780],
    [965, 1319, 1020, 1346],
    [965, 1319, 1020, 1617, 1346],
    [618, 1620],
    [1014, 1804, 1346, 1831],
    [1171, 1908, 1712, 589],
    [1171, 1906, 1712, 587],
    [1171, 1912, 1712, 585],
    [1171, 1905, 1712, 589],
    [
      1928,
      1933,
      1716,
      581,
      1656,
      1667,
      1694,
      1697,
      1014,
      1796,
      1346,
      1008,
      1827,
      422,
      103,
      644,
      1940,
    ],
    [1682, 1173, 1914, 1583, 1713, 1694, 581, 1738, 1697],
    [
      1933,
      1716,
      581,
      1694,
      1697,
      1014,
      1796,
      1346,
      1008,
      1827,
      1305,
      1181,
      1913,
      1740,
      1319,
      1324,
      1654,
      1666,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [
      0,
      1,
      2,
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
    ],
    [
      0,
      1,
      2,
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
      21,
      20,
    ],
  ];
}
