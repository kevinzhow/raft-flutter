// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `filePreview`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `badgeColor` axis of `filePreview` (default `rose`).
enum RaftFilePreviewRecipeBadgeColor {
  rose('rose'),
  blue('blue'),
  amber('amber'),
  emerald('emerald'),
  violet('violet'),
  neutral('neutral');

  const RaftFilePreviewRecipeBadgeColor(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftFilePreviewRecipe].
class RaftFilePreviewRecipeStyle {
  const RaftFilePreviewRecipeStyle({required this.root, required this.document, required this.file, required this.code, required this.fileZip, required this.fileZipStack, required this.fileZipTeeth, required this.fileZipRow, required this.fileZipDark, required this.fileZipLight, required this.fileZipPull, required this.codeStack, required this.codeRow, required this.codeRowIndent, required this.codeTextRow, required this.codeGlyph, required this.codeTagLine, required this.codeAttributeLine, required this.codeTextLine, required this.codeSelfClosingLine, required this.badge, required this.media});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'document': document, 'file': file, 'code': code, 'fileZip': fileZip, 'fileZipStack': fileZipStack, 'fileZipTeeth': fileZipTeeth, 'fileZipRow': fileZipRow, 'fileZipDark': fileZipDark, 'fileZipLight': fileZipLight, 'fileZipPull': fileZipPull, 'codeStack': codeStack, 'codeRow': codeRow, 'codeRowIndent': codeRowIndent, 'codeTextRow': codeTextRow, 'codeGlyph': codeGlyph, 'codeTagLine': codeTagLine, 'codeAttributeLine': codeAttributeLine, 'codeTextLine': codeTextLine, 'codeSelfClosingLine': codeSelfClosingLine, 'badge': badge, 'media': media};
}

/// raft-ui recipe `filePreview` (`src/components/file-preview/file-preview.recipe.ts`, index.mjs:12653).
///
/// Used by: FilePreview, FilePreviewBadge, FilePreviewCode, FilePreviewDocument, FilePreviewFile, FilePreviewMedia.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftFilePreviewRecipe {
  static const String recipeName = 'filePreview';
  static const List<String> slotNames = ['root', 'document', 'file', 'code', 'fileZip', 'fileZipStack', 'fileZipTeeth', 'fileZipRow', 'fileZipDark', 'fileZipLight', 'fileZipPull', 'codeStack', 'codeRow', 'codeRowIndent', 'codeTextRow', 'codeGlyph', 'codeTagLine', 'codeAttributeLine', 'codeTextLine', 'codeSelfClosingLine', 'badge', 'media'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('badgeColor', ['rose', 'blue', 'amber', 'emerald', 'violet', 'neutral'], 'rose', false),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftFilePreviewRecipeStyle resolve({RaftFilePreviewRecipeBadgeColor? badgeColor, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [badgeColor?.css, theme.name], states, tokens);
    return RaftFilePreviewRecipeStyle(root: s[0], document: s[1], file: s[2], code: s[3], fileZip: s[4], fileZipStack: s[5], fileZipTeeth: s[6], fileZipRow: s[7], fileZipDark: s[8], fileZipLight: s[9], fileZipPull: s[10], codeStack: s[11], codeRow: s[12], codeRowIndent: s[13], codeTextRow: s[14], codeGlyph: s[15], codeTagLine: s[16], codeAttributeLine: s[17], codeTextLine: s[18], codeSelfClosingLine: s[19], badge: s[20], media: s[21]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 1620, 1951, 3100, 2867, 2312, 2317],
    [2775, 1951, 3115, 2900, 2670, 2800, 1133, 2819, 866, 876, 856, 2863, 2790],
    [2775, 1620, 1951, 3115, 2312, 2317, 2800, 1133, 2819, 866, 876, 856, 2863, 2790],
    [1620, 1964, 2312, 2317],
    [2775, 154, 1620, 1622, 2312],
    [2906],
    [1620, 2656, 2815],
    [2868, 835],
    [2868, 760],
    [2597, 1949, 3106, 2822, 864, 903, 759],
    [154, 2906],
    [1620, 2312, 1695, 2344],
    [1620, 2312, 1695, 2698, 2344],
    [862, 2701],
    [1689, 2929, 2344, 2988],
    [1948, 3108, 2815, 835],
    [1948, 3106, 2815, 761],
    [1948, 3113, 2815, 805],
    [1948, 3105, 2815, 835],
    [580, 3138, 3126, 3131, 1689, 2918, 2344, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 745, 970, 1155, 141, 925, 2819, 866, 876, 2749, 2761, 1684, 2979, 2863, 3016, 622],
    [2775, 1951, 3115, 2656, 2800, 1133, 2819, 866, 876, 856, 2863, 2790],
    [2775, 1951, 3115, 2900, 2818, 2823, 825, 2670, 2863, 2791, 2800, 1133],
    [2775, 1620, 1951, 3115, 2312, 2317, 2818, 2823, 825, 2863, 2791, 2800, 1133],
    [580, 143, 925, 3138, 3126, 3131, 2822, 2761, 1689, 2918, 2344, 1692, 3026, 2843, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 745, 970, 1155, 2749],
    [2775, 1951, 3115, 2656, 2818, 825, 2863, 2791, 2800, 1133],
    [580, 3138, 3126, 3131, 1689, 2918, 2344, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 744, 975, 1152, 141, 925, 2819, 866, 876, 2749, 2761, 1684, 2979, 2863, 3016, 622],
    [580, 143, 925, 3138, 3126, 3131, 2822, 2761, 1689, 2918, 2344, 1692, 3026, 2843, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 744, 975, 1152, 2749],
    [580, 3138, 3126, 3131, 1689, 2918, 2344, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 741, 971, 1156, 141, 925, 2819, 866, 876, 2749, 2761, 1684, 2979, 2863, 3016, 622],
    [580, 143, 925, 3138, 3126, 3131, 2822, 2761, 1689, 2918, 2344, 1692, 3026, 2843, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 741, 971, 1156, 2749],
    [580, 3138, 3126, 3131, 1689, 2918, 2344, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 743, 974, 1151, 141, 925, 2819, 866, 876, 2749, 2761, 1684, 2979, 2863, 3016, 622],
    [580, 143, 925, 3138, 3126, 3131, 2822, 2761, 1689, 2918, 2344, 1692, 3026, 2843, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 743, 974, 1151, 2749],
    [580, 3138, 3126, 3131, 1689, 2918, 2344, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 742, 976, 1153, 141, 925, 2819, 866, 876, 2749, 2761, 1684, 2979, 2863, 3016, 622],
    [580, 143, 925, 3138, 3126, 3131, 2822, 2761, 1689, 2918, 2344, 1692, 3026, 2843, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 742, 976, 1153, 2749],
    [580, 3138, 3126, 3131, 1689, 2918, 2344, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 801, 984, 1168, 141, 925, 2819, 866, 876, 2749, 2761, 1684, 2979, 2863, 3016, 622],
    [580, 143, 925, 3138, 3126, 3131, 2822, 2761, 1689, 2918, 2344, 1692, 3026, 2843, 579, 626, 613, 623, 630, 615, 616, 618, 1144, 1174, 961, 801, 984, 1168, 2749],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], [0, 21, 22, 22, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 23, 24], [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 25, 20], [0, 21, 22, 22, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 26, 24], [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 27, 20], [0, 21, 22, 22, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 28, 24], [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 29, 20], [0, 21, 22, 22, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 30, 24], [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 31, 20], [0, 21, 22, 22, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 32, 24], [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 33, 20], [0, 21, 22, 22, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 34, 24],
  ];
}
