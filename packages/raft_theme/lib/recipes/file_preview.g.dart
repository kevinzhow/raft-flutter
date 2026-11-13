// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `filePreview`.
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

/// raft-ui recipe `filePreview` (`dist/components/file-preview/file-preview.recipe.mjs`, index.mjs:15822).
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
    [2433, 1400, 1647, 2694, 2499, 1864, 1869],
    [2433, 1647, 2708, 2542, 2467, 2473, 2262, 2445, 911, 2497, 2448],
    [2433, 1400, 1647, 2708, 1864, 1869, 2467, 2473, 2445, 911, 2497, 2448],
    [1400, 1659, 1864, 1869],
    [2433, 192, 1400, 1404, 1864],
    [2544],
    [1400, 2252, 2466],
    [2506, 903],
    [2506, 901],
    [2144, 1646, 2698, 2470, 939, 949, 900],
    [192, 2544],
    [1400, 1864, 1463, 1892],
    [1400, 1864, 1463, 2297, 1892],
    [937, 2300],
    [1454, 2579, 1892, 2607],
    [1645, 2701, 2466, 903],
    [1645, 2698, 2466, 902],
    [1645, 2706, 2466, 900],
    [1645, 2697, 2466, 903],
    [
      2724,
      2729,
      2471,
      895,
      2399,
      2413,
      2445,
      2448,
      1454,
      2572,
      1892,
      1449,
      2603,
      691,
      184,
      966,
      2747,
    ],
    [2433, 1647, 2708, 2252, 2467, 2445, 895, 2497, 2448],
    [
      2729,
      2471,
      895,
      2445,
      2448,
      1454,
      2572,
      1892,
      1449,
      2603,
      1847,
      1653,
      2707,
      2499,
      1864,
      1869,
      2397,
      2412,
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
