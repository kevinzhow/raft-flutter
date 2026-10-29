import 'dart:convert' show HtmlEscape, HtmlEscapeMode, utf8;

import 'package:markdown/markdown.dart' as md;

/// Bare-URL linkification for message Markdown (Web: `remarkAutolinkBareUrls`
/// after remark-gfm's autolink literals).
///
/// The stock GFM autolink only fires at a line start or after whitespace and
/// runs to the next whitespace, so `链接：https://x`, `看这里https://x` and
/// `（https://x）` stayed text and `https://x。然后` swallowed the CJK text.
/// This syntax links `http(s)://` and `www.` URLs wherever they start and
/// ends the link at CJK punctuation, an unmatched closing bracket and
/// trailing ASCII punctuation. It is linear in the length of the source:
/// every position is looked at once and a URL is scanned once.

/// A bare URL found in a source string: the half-open range, the visible
/// text, and the destination handed to the link handler.
typedef RaftBareUrl = ({int start, int end, String text, String href});

/// Web `CJK_URL_BOUNDARY_PUNCTUATION`.
const _cjkBoundary = '，。、；：！？）》」』】》〉”’（《「『【〈“‘';

final _cjkBoundaryUnits = {for (final c in _cjkBoundary.codeUnits) c};

final _cjkTextOrSpace = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
  unicode: true,
);

final _wwwHost = RegExp(r'^www\.[a-z0-9_-]+\.[a-z0-9-]', caseSensitive: false);

final _trailingEntity = RegExp(r'&[0-9a-z]+;$', caseSensitive: false);

/// JavaScript `\s`: Dart's matches the same set, but the scan below works on
/// code units so the set is spelled out.
bool _isSpace(int c) =>
    (c >= 0x09 && c <= 0x0d) ||
    c == 0x20 ||
    c == 0xa0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200a) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202f ||
    c == 0x205f ||
    c == 0x3000 ||
    c == 0xfeff;

/// Web `isCjkTextOrWhitespace` on the character that starts [index].
bool _cjkTextOrSpaceAt(String source, int index) {
  if (index < 0 || index >= source.length) return false;
  final c = source.codeUnitAt(index);
  if (_isSpace(c)) return true;
  if (c < 0x2e80) return false;
  final end = (c >= 0xd800 && c <= 0xdbff && index + 1 < source.length)
      ? index + 2
      : index + 1;
  return _cjkTextOrSpace.hasMatch(source.substring(index, end));
}

bool _isAsciiAlnum(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x61 && c <= 0x7a);

/// Letters and digits of any script (a `www.` right after one is part of a
/// word, not a link; CJK punctuation before it is not).
bool _isWordBefore(String source, int index) {
  final c = source.codeUnitAt(index);
  if (_isAsciiAlnum(c)) return true;
  if (c < 0x80) return false;
  if (_isSpace(c) || _cjkBoundaryUnits.contains(c)) return false;
  return _letterOrNumber.hasMatch(
    c >= 0xdc00 && c <= 0xdfff && index > 0
        ? source.substring(index - 1, index + 1)
        : String.fromCharCode(c),
  );
}

final _letterOrNumber = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool _startsWithFold(String source, int index, String lower) {
  if (index + lower.length > source.length) return false;
  for (var i = 0; i < lower.length; i++) {
    if ((source.codeUnitAt(index + i) | 0x20) != lower.codeUnitAt(i)) {
      return false;
    }
  }
  return true;
}

int _bracketKind(int c) => switch (c) {
  0x28 || 0x29 => 0, // ( )
  0x5b || 0x5d => 1, // [ ]
  0x7b || 0x7d => 2, // { }
  _ => -1,
};

/// The bare URL that starts at [index] in [source], or null.
///
/// `http://` and `https://` link wherever they appear; `www.` only at a
/// start, after whitespace or after punctuation (so `见：www.example.com`
/// links and `awww.example.com` does not), as remark-gfm does.
RaftBareUrl? raftBareUrlAt(String source, int index) {
  if (index < 0 || index >= source.length) return null;
  final first = source.codeUnitAt(index) | 0x20;
  int schemeEnd;
  if (first == 0x68) {
    if (_startsWithFold(source, index, 'https://')) {
      schemeEnd = index + 8;
    } else if (_startsWithFold(source, index, 'http://')) {
      schemeEnd = index + 7;
    } else {
      return null;
    }
  } else if (first == 0x77 && _startsWithFold(source, index, 'www.')) {
    if (index > 0 && _isWordBefore(source, index - 1)) return null;
    schemeEnd = index + 4;
  } else {
    return null;
  }
  final www = first == 0x77;

  // The raw run: to whitespace, `<`/`>`, a CJK boundary punctuation mark or
  // a `]` with no `[` in the run (it closes an enclosing link label).
  var end = schemeEnd;
  var squareDepth = 0;
  while (end < source.length) {
    final c = source.codeUnitAt(end);
    if (_isSpace(c) || c == 0x3c || c == 0x3e) break;
    // Reference sentinels (message_references) are their own syntax.
    if (c >= 0xe000 && c <= 0xe002) break;
    if (_cjkBoundaryUnits.contains(c)) break;
    if (c == 0x5b) {
      squareDepth++;
    } else if (c == 0x5d) {
      if (squareDepth == 0) break;
      squareDepth--;
    }
    end++;
  }
  final after = end; // the character that ended the run (or the end)

  // An ASCII comma followed by CJK text or whitespace is a boundary.
  for (var i = schemeEnd; i < end; i++) {
    if (source.codeUnitAt(i) != 0x2c) continue;
    final next = i + 1 < end ? i + 1 : after;
    if (_cjkTextOrSpaceAt(source, next)) {
      end = i;
      break;
    }
  }

  // Trailing punctuation and unmatched closing brackets stay outside.
  final open = [0, 0, 0], close = [0, 0, 0];
  for (var i = schemeEnd; i < end; i++) {
    final c = source.codeUnitAt(i);
    final kind = _bracketKind(c);
    if (kind < 0) continue;
    // Opening brackets are the odd-numbered of each pair's code points.
    if (c == 0x28 || c == 0x5b || c == 0x7b) {
      open[kind]++;
    } else {
      close[kind]++;
    }
  }
  while (end > schemeEnd) {
    final c = source.codeUnitAt(end - 1);
    switch (c) {
      case 0x3f || 0x21 || 0x2e || 0x2c || 0x3a || 0x2a || 0x5f || 0x7e:
      case 0x27 || 0x22:
        end--;
        continue;
      case 0x3b:
        final entity = _trailingEntity.firstMatch(
          source.substring(schemeEnd, end),
        );
        end = entity == null ? end - 1 : schemeEnd + entity.start;
        continue;
      case 0x29 || 0x5d || 0x7d:
        final kind = _bracketKind(c);
        if (close[kind] > open[kind]) {
          close[kind]--;
          end--;
          continue;
        }
    }
    break;
  }
  if (end <= schemeEnd) return null;

  final text = source.substring(index, end);
  if (www && !_wwwHost.hasMatch(text)) return null;
  return (
    start: index,
    end: end,
    text: text,
    href: _destination(www ? 'http://$text' : text),
  );
}

/// Percent-encodes what a URL cannot carry (CJK, spaces, quotes) and keeps
/// existing `%XX` escapes, like the Web renderer's URI normalisation.
String _destination(String url) {
  var plain = true;
  for (final c in url.codeUnits) {
    if (c <= 0x20 || c >= 0x7f || c == 0x22 || c == 0x3c || c == 0x3e) {
      plain = false;
      break;
    }
  }
  if (plain) return url;
  final out = StringBuffer();
  final units = url.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    if (c > 0x20 && c < 0x7f && c != 0x22 && c != 0x3c && c != 0x3e) {
      out.writeCharCode(c);
      continue;
    }
    var rune = c;
    if (c >= 0xd800 && c <= 0xdbff && i + 1 < units.length) {
      rune = 0x10000 + ((c - 0xd800) << 10) + (units[++i] - 0xdc00);
    }
    for (final b in utf8.encode(String.fromCharCode(rune))) {
      out
        ..write('%')
        ..write(b.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return out.toString();
}

/// Every bare URL in [source], left to right. Callers that must agree with
/// the rendered links (message semantics) use this instead of a regex.
List<RaftBareUrl> raftBareUrls(String source) {
  final found = <RaftBareUrl>[];
  var i = 0;
  while (i < source.length) {
    final c = source.codeUnitAt(i) | 0x20;
    if (c == 0x68 || c == 0x77) {
      final url = raftBareUrlAt(source, i);
      if (url != null) {
        found.add(url);
        i = url.end;
        continue;
      }
    }
    i++;
  }
  return found;
}

/// Inline syntax for [raftBareUrlAt]. Registered as a custom syntax it runs
/// before the GFM autolink, so a URL is decided here wherever it starts.
class RaftBareUrlSyntax extends md.InlineSyntax {
  RaftBareUrlSyntax() : super(r'(?:https?://|www\.)', caseSensitive: false);

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final pos = startMatchPos ?? parser.pos;
    final url = raftBareUrlAt(parser.source, pos);
    if (url == null) return false;
    parser
      ..writeText()
      ..addNode(
        md.Element.text(
          'a',
          parser.encodeHtml ? _escape.convert(url.text) : url.text,
        )..attributes['href'] = url.href,
      )
      ..consume(url.end - pos);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;
}

/// Replaces a link nested in a link by its content: an explicit
/// `[text](url)` wins over a URL written in its label (Web skips link
/// children when it linkifies). Returns [nodes].
List<md.Node> raftFlattenNestedLinks(List<md.Node> nodes) {
  _flatten(nodes, false);
  return nodes;
}

bool _flatten(List<md.Node> nodes, bool inLink) {
  var changed = false;
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (node is! md.Element) continue;
    final children = node.children;
    if (children == null || children.isEmpty) continue;
    final isLink = node.tag == 'a';
    if (isLink && inLink) {
      _flatten(children, true);
      nodes
        ..removeAt(i)
        ..insertAll(i, children);
      i += children.length - 1;
      changed = true;
    } else {
      changed |= _flatten(children, inLink || isLink);
    }
  }
  return changed;
}

const _escape = HtmlEscape(HtmlEscapeMode.element);
