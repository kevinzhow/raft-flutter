import 'package:markdown/markdown.dart' as md;

import 'message_markdown.dart' show RaftClaimedText;

// Math in Markdown (Web 1.24 task #775): `$$…$$` and Obsidian-style `$…$`,
// with the rules the server reads when it decides who a message notifies.
//
// Source: packages/shared/src/markdownMath.ts (raftMath) and
// micromark-extension-math 3.1.0 `math-flow.js` at v1.24.0-source.1.

/// Element tag of a block formula (`$$` on its own lines). Its one child is
/// the formula source as [RaftClaimedText], so no message pass reads into it.
const raftMathDisplayTag = 'math-display';

/// The `class` of the `<code>` an inline formula becomes (Web
/// `<code class="language-math">`). Message passes already skip `code`.
const raftMathInlineClass = 'language-math';

/// Whether [element] is an inline formula.
bool raftIsInlineMath(md.Element element) =>
    element.tag == 'code' && element.attributes['class'] == raftMathInlineClass;

const _dollar = 0x24;

bool _isLineEnding(int c) => c == 0x0a || c == 0x0d;

// micromark: line endings, tab, virtual space and space.
bool _isWhitespace(int c) => c == 0x20 || c == 0x09 || _isLineEnding(c);

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// Inline math: `$$…$$` anywhere, `$…$` only when it reads as math rather
/// than money (the opening `$` is not followed by a space; the closing one is
/// not preceded by a space and not followed by a digit; it stays on one line).
/// So `$x^2$` is math, while `$5 到 $10` and `$5 and $ 10` stay text.
class RaftMathTextSyntax extends md.InlineSyntax {
  RaftMathTextSyntax() : super(r'\$', startCharacter: _dollar);

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final source = parser.source;
    final start = startMatchPos ?? parser.pos;
    if (source.codeUnitAt(start) != _dollar) return false;
    // A `$` right after another `$` is part of that sequence, unless that one
    // was escaped (`\$$x$`).
    if (start > 0 && source.codeUnitAt(start - 1) == _dollar) {
      var slashes = 0;
      for (var i = start - 2; i >= 0 && source.codeUnitAt(i) == 0x5c; i--) {
        slashes++;
      }
      if (slashes.isEven) return false;
    }
    final end = source.length;
    var i = start;
    while (i < end && source.codeUnitAt(i) == _dollar) {
      i++;
    }
    final sizeOpen = i - start;
    // A single `$` opens only when text follows it at once.
    if (sizeOpen == 1 && (i == end || _isWhitespace(source.codeUnitAt(i)))) {
      return false;
    }
    final contentStart = i;
    var lastWasWhitespace = false;
    while (i < end) {
      final c = source.codeUnitAt(i);
      if (c == _dollar) {
        final runStart = i;
        while (i < end && source.codeUnitAt(i) == _dollar) {
          i++;
        }
        final size = i - runStart;
        final closes =
            size == sizeOpen &&
            // A single closing `$` must hug the math and not start a number.
            (sizeOpen != 1 ||
                (!lastWasWhitespace &&
                    (i == end || !_isDigit(source.codeUnitAt(i)))));
        if (closes) {
          parser.writeText();
          parser.addNode(
            md.Element('code', [
              md.Text(_inlineValue(source.substring(contentStart, runStart))),
            ])..attributes['class'] = raftMathInlineClass,
          );
          parser.consume(i - start);
          return true;
        }
        // Not the closing sequence: these dollars are part of the math.
        lastWasWhitespace = false;
        continue;
      }
      if (_isLineEnding(c)) {
        // Single-dollar math stays on one line, as in Obsidian.
        if (sizeOpen == 1) return false;
        lastWasWhitespace = true;
      } else {
        lastWasWhitespace = _isWhitespace(c);
      }
      i++;
    }
    return false;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;
}

/// micromark-extension-math `resolveMathText`: one space (or line ending) of
/// padding goes from each side when both are there and something else is
/// inside.
String _inlineValue(String raw) {
  if (raw.length >= 2 &&
      _isPadding(raw.codeUnitAt(0)) &&
      _isPadding(raw.codeUnitAt(raw.length - 1)) &&
      raw.codeUnits.any((c) => !_isPadding(c))) {
    return raw.substring(1, raw.length - 1);
  }
  return raw;
}

bool _isPadding(int c) => c == 0x20 || _isLineEnding(c);

final _fenceOpen = RegExp(r'^( {0,3})(\${2,})[ \t]*([^$]*)$');

/// A block formula: a fence of two or more `$` (optionally followed by a
/// meta that has no `$`) on its own line, the formula, and a closing fence at
/// least as long. An unclosed one runs to the end of its container, as a
/// fenced code block does. It can interrupt a paragraph.
class RaftMathFlowSyntax extends md.BlockSyntax {
  const RaftMathFlowSyntax();

  @override
  RegExp get pattern => _fenceOpen;

  @override
  bool canEndBlock(md.BlockParser parser) => true;

  @override
  md.Node parse(md.BlockParser parser) {
    final open = pattern.firstMatch(parser.current.content)!;
    final indent = open[1]!.length;
    final size = open[2]!.length;
    final close = RegExp('^ *\\\${$size,}[ \\t]*\$');
    parser.advance();
    final lines = <String>[];
    while (!parser.isDone) {
      final line = parser.current.content;
      if (close.hasMatch(line)) {
        parser.advance();
        break;
      }
      lines.add(_stripIndent(line, indent));
      parser.advance();
    }
    return md.Element(raftMathDisplayTag, [RaftClaimedText(lines.join('\n'))]);
  }
}

String _stripIndent(String line, int indent) {
  var i = 0;
  while (i < indent && i < line.length && line.codeUnitAt(i) == 0x20) {
    i++;
  }
  return line.substring(i);
}
