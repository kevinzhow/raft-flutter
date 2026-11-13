import 'package:markdown/markdown.dart' as md;

import 'markdown_cjk_ranges.dart';

// remark-cjk-friendly (Web v1.24 message, document, card and announcement
// Markdown): `**` next to CJK punctuation opens and closes emphasis
// (`中文**“重点”**中文`), which strict CommonMark refuses when the `**` sits
// between a CJK letter and punctuation.
//
// Source: micromark-extension-cjk-friendly 2.0.2 `ext/attention.js` and
// micromark-extension-cjk-friendly-util 3.0.1 (`classifyCharacter`,
// `classifyPrecedingCharacter`), as installed with Raft Web v1.24.0-source.1.
// botiverse/mobile ports the same rule (third_party/markdown-parser
// CjkFriendlyEmphasis.kt at 81fa32d) but treats characters outside the BMP as
// neither CJK nor punctuation; this port reads them as the Web does.

// micromark character groups (classifyCharacter.js `constantsEx`).
const _whitespace = 1;
const _punctuation = 2;
const _cjk = 4096;
const _cjkPunctuation = 4098;
const _ivs = 8192;
const _cjkOrIvs = 12288;
const _nonEmojiGeneralUseVs = 16384;

final _unicodePunctuation = RegExp(r'^[\p{P}\p{S}]$', unicode: true);
final _unicodeWhitespace = RegExp(r'^\s$');

/// Whether code point [c] is CJK (East Asian Wide but not emoji, Fullwidth,
/// Halfwidth, or Hangul).
bool raftIsCjkCodePoint(int c) {
  if (c < 0x1100) return false;
  var low = 0;
  var high = raftCjkRanges.length ~/ 2 - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (c < raftCjkRanges[mid * 2]) {
      high = mid - 1;
    } else if (c > raftCjkRanges[mid * 2 + 1]) {
      low = mid + 1;
    } else {
      return true;
    }
  }
  return false;
}

/// classifyCharacter: [c] null is the start or end of the text (whitespace).
int _classify(int? c) {
  if (c == null) return _whitespace;
  final s = String.fromCharCode(c);
  if (_unicodeWhitespace.hasMatch(s)) return _whitespace;
  var value = 0;
  if (c >= 0x1100) {
    if (c >= 0xFE00 && c <= 0xFE0E) return _nonEmojiGeneralUseVs;
    if (c >= 0xE0100 && c <= 0xE01EF) return _ivs;
    if (raftIsCjkCodePoint(c)) value |= _cjk;
  }
  if (_unicodePunctuation.hasMatch(s)) value |= _punctuation;
  return value;
}

bool _isNonCjkPunctuation(int category) =>
    (category & _cjkPunctuation) == _punctuation;
bool _isSpaceOrPunctuation(int category) =>
    category & (_whitespace | _punctuation) != 0;
bool _isUnicodeWhitespace(int category) => category & _whitespace != 0;

/// The code point that ends just before [index], or null at the start.
(int, int)? _codePointBefore(String s, int index) {
  if (index <= 0) return null;
  final low = s.codeUnitAt(index - 1);
  if (low >= 0xDC00 && low <= 0xDFFF && index >= 2) {
    final high = s.codeUnitAt(index - 2);
    if (high >= 0xD800 && high <= 0xDBFF) {
      return (0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00), 2);
    }
  }
  return (low, 1);
}

/// The code point that starts at [index], or null at the end.
int? _codePointAt(String s, int index) {
  if (index >= s.length) return null;
  final high = s.codeUnitAt(index);
  if (high >= 0xD800 && high <= 0xDBFF && index + 1 < s.length) {
    final low = s.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
    }
  }
  return high;
}

/// classifyPrecedingCharacter: a general-use variation selector is looked
/// through to the character it modifies.
int _classifyPreceding(String s, int runStart) {
  final previous = _codePointBefore(s, runStart);
  final before = _classify(previous?.$1);
  if (before != _nonEmojiGeneralUseVs) return before;
  final twoPrevious = _codePointBefore(s, runStart - previous!.$2);
  final twoBefore = _classify(twoPrevious?.$1);
  if (twoPrevious == null || _isUnicodeWhitespace(twoBefore)) return before;
  final main = twoPrevious.$1;
  // A quote with U+FE01 is the CJK (full-width) form of that quote.
  if (previous.$1 == 0xFE01 &&
      (main == 0x2018 || main == 0x2019 || main == 0x201C || main == 0x201D)) {
    return _cjkPunctuation;
  }
  return twoBefore & ~_ivs;
}

bool _isCoreMarker(int? c) => c == 0x2a || c == 0x5f;

/// Whether the run of [marker] (`*` or `_`) from [runStart] to [runEnd] in
/// [source] can open and close emphasis under the CJK-friendly rule.
(bool, bool) raftCjkFriendlyFlanking(
  String source,
  int runStart,
  int runEnd,
  int marker,
) {
  final previous = _codePointBefore(source, runStart)?.$1;
  final next = _codePointAt(source, runEnd);
  final beforePrimary = _classifyPreceding(source, runStart);
  final after = _classify(next);
  final beforeNonCjkPunctuation = _isNonCjkPunctuation(beforePrimary);
  final beforeSpaceOrNonCjkPunctuation =
      beforeNonCjkPunctuation ||
      _isUnicodeWhitespace(beforePrimary) ||
      _isCoreMarker(previous);
  final afterNonCjkPunctuation = _isNonCjkPunctuation(after);
  final afterSpaceOrNonCjkPunctuation =
      afterNonCjkPunctuation ||
      _isUnicodeWhitespace(after) ||
      _isCoreMarker(next);
  final beforeCjkOrIvs = beforePrimary & _cjkOrIvs != 0;
  final afterCjk = after & _cjk != 0;
  // Other attention markers (GFM's `~`) next to the run count as text.
  final open =
      !afterSpaceOrNonCjkPunctuation ||
      afterNonCjkPunctuation &&
          (beforeSpaceOrNonCjkPunctuation || beforeCjkOrIvs) ||
      next == 0x7e;
  final close =
      !beforeSpaceOrNonCjkPunctuation ||
      beforeNonCjkPunctuation && (afterSpaceOrNonCjkPunctuation || afterCjk) ||
      previous == 0x7e;
  if (marker == 0x2a) return (open, close);
  return (
    open && (_isSpaceOrPunctuation(beforePrimary) || !close),
    close && (_isSpaceOrPunctuation(after) || !open),
  );
}

/// `*` / `**` and `_` / `__` emphasis with the CJK-friendly rule. Put it
/// before the default syntaxes (custom inline syntaxes are tried first).
class RaftCjkEmphasisSyntax extends md.DelimiterSyntax {
  RaftCjkEmphasisSyntax.asterisk()
    : super(
        r'\*+',
        requiresDelimiterRun: true,
        allowIntraWord: true,
        tags: _tags,
        startCharacter: 0x2a,
      );

  RaftCjkEmphasisSyntax.underscore()
    : super(
        '_+',
        requiresDelimiterRun: true,
        tags: _tags,
        startCharacter: 0x5f,
      );

  static final _tags = [md.DelimiterTag('em', 1), md.DelimiterTag('strong', 2)];

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final start = parser.pos;
    final end = start + match[0]!.length;
    final marker = parser.source.codeUnitAt(start);
    final text = md.Text(parser.source.substring(start, end));
    final (canOpen, canClose) = raftCjkFriendlyFlanking(
      parser.source,
      start,
      end,
      marker,
    );
    parser.pushDelimiter(
      _CjkDelimiterRun(
        node: text,
        char: marker,
        syntax: this,
        tags: _tags,
        allowIntraWord: allowIntraWord,
        canOpen: canOpen,
        canClose: canClose,
      ),
    );
    parser.addNode(text);
    return true;
  }
}

/// The two emphasis syntaxes, for a Markdown document's inline syntaxes.
List<md.InlineSyntax> raftCjkEmphasisSyntaxes() => [
  RaftCjkEmphasisSyntax.asterisk(),
  RaftCjkEmphasisSyntax.underscore(),
];

/// A delimiter run whose open/close was decided by [raftCjkFriendlyFlanking]
/// (the inline parser only resolves emphasis between [md.DelimiterRun]s).
class _CjkDelimiterRun implements md.DelimiterRun {
  _CjkDelimiterRun({
    required this.node,
    required this.char,
    required this.syntax,
    required this.tags,
    required this.allowIntraWord,
    required this.canOpen,
    required this.canClose,
  });

  @override
  md.Text node;

  @override
  final int char;

  @override
  int get length => node.text.length;

  @override
  bool isActive = true;

  @override
  final md.DelimiterSyntax syntax;

  @override
  final bool allowIntraWord;

  @override
  final bool canOpen;

  @override
  final bool canClose;

  @override
  final List<md.DelimiterTag> tags;
}
