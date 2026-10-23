import 'dart:convert' show LineSplitter;

import 'package:markdown/markdown.dart' as md;

import 'markdown_autolink.dart';
import 'message_ref_target.dart';

/// How a Markdown source is parsed (Web `MarkdownContent` density and the
/// `MessageItem` pipeline).
enum RaftMarkdownMode {
  /// Documents keep CommonMark indented code blocks.
  document,

  /// Compact prose: an indented line is prose, not code (Web
  /// `remarkDisableIndentedCode`).
  compact,

  /// A message body: compact, plus the syntaxes the message passes need to
  /// tell escapes, angle-bracket refs, single-tilde strikethrough and lazy
  /// block quote lines apart (Web `remarkMessageTokens`,
  /// `repairGeneratedMarkdown`).
  message,
}

/// Stands before a character that was written as a backslash escape (`\<`).
/// The parser drops the backslash and merges the pieces of text around it, so
/// the message passes find the escape through this private-use mark and remove
/// it ([raftStripEscapeMarks]).
const raftEscapeMark = '\uE7A1';

String raftStripEscapeMarks(String text) =>
    text.contains(raftEscapeMark) ? text.replaceAll(raftEscapeMark, '') : text;

/// Text a message pass has already decided about (Web `messageToken` span):
/// later passes do not match inside it.
class RaftClaimedText extends md.Text {
  RaftClaimedText(super.text);
}

/// Attribute set on a link written as `[label](<target>)` or `<scheme:target>`:
/// only these forms are refs (`[x](#general)` is not).
const raftAngleLinkAttribute = 'raft-angle';

/// Attribute set on `del` written with a single tilde.
const raftSingleTildeAttribute = 'raft-single-tilde';

const _splitTag = 'raft-split';

class _RaftEscapeSyntax extends md.InlineSyntax {
  _RaftEscapeSyntax() : super(r'\\([!-/:-@\[-`{-~])', startCharacter: 0x5c);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Text('$raftEscapeMark${match[1]!}'));
    return true;
  }
}

class _RaftStrikethroughSyntax extends md.DelimiterSyntax {
  _RaftStrikethroughSyntax()
    : super(
        '~+',
        requiresDelimiterRun: true,
        allowIntraWord: true,
        startCharacter: 0x7e,
        tags: [md.DelimiterTag('del-single', 1), md.DelimiterTag('del', 2)],
      );

  @override
  Iterable<md.Node>? close(
    md.InlineParser parser,
    md.Delimiter opener,
    md.Delimiter closer, {
    required String tag,
    required List<md.Node> Function() getChildren,
  }) {
    final element = md.Element('del', getChildren());
    if (tag == 'del-single') element.attributes[raftSingleTildeAttribute] = '1';
    return [element];
  }
}

final _labelledAngle = RegExp(r'\]\(<[^<>\n]+>\)?$');

class _RaftLinkSyntax extends md.LinkSyntax {
  @override
  Iterable<md.Node>? close(
    md.InlineParser parser,
    covariant md.SimpleDelimiter opener,
    md.Delimiter? closer, {
    String? tag,
    required List<md.Node> Function() getChildren,
  }) {
    final nodes = super.close(
      parser,
      opener,
      closer,
      tag: tag,
      getChildren: getChildren,
    );
    if (nodes == null) return null;
    final end = (parser.pos + 1).clamp(0, parser.source.length);
    final raw = parser.source.substring(opener.endPos, end);
    if (_labelledAngle.hasMatch(raw)) {
      for (final node in nodes) {
        if (node is md.Element && node.tag == 'a') {
          node.attributes[raftAngleLinkAttribute] = '1';
        }
      }
    }
    return nodes;
  }
}

class _RaftAutolinkSyntax extends md.AutolinkSyntax {
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final url = match[1]!;
    if (raftParseRefTarget(url) == null) return super.onMatch(parser, match);
    parser.addNode(
      md.Element.text('a', url)
        ..attributes['href'] = url
        ..attributes[raftAngleLinkAttribute] = '1',
    );
    return true;
  }
}

final _fenceLine = RegExp(r'^ {0,3}(?:`{3,}[^`]*|~{3,}.*)$');

/// Block quote that ends where Web's `splitLazyBlockquoteContinuation` ends
/// it: `> quote` followed by an unquoted line. CommonMark pulls that line into
/// the quote; writers (and LLMs) mean a new paragraph, so the lines from the
/// first unquoted one on leave the quote.
class _RaftBlockquoteSyntax extends md.BlockSyntax {
  const _RaftBlockquoteSyntax();

  @override
  RegExp get pattern => const md.BlockquoteSyntax().pattern;

  @override
  md.Node parse(md.BlockParser parser) {
    final childLines = <md.Line>[];
    int? lazyStart;
    var lazyTail = false;
    while (!parser.isDone) {
      final line = parser.current;
      final match = pattern.firstMatch(line.content);
      if (match != null) {
        final markerStart = line.content.indexOf('>');
        var markerEnd = markerStart + 1;
        if (markerStart < line.content.length - 1) {
          final next = line.content.codeUnitAt(markerStart + 1);
          if (next == 0x20 || next == 0x09) markerEnd += 1;
        }
        childLines.add(md.Line(line.content.substring(markerEnd)));
        parser.advance();
        lazyTail = false;
        continue;
      }
      final last = childLines.last;
      final other = parser.blockSyntaxes.firstWhere((s) => s.canParse(parser));
      if (other is md.ParagraphSyntax &&
          !last.isBlankLine &&
          !_fenceLine.hasMatch(last.content)) {
        lazyStart ??= childLines.length;
        lazyTail = true;
        childLines.add(line);
        parser.advance();
      } else {
        break;
      }
    }
    if (lazyStart != null) {
      final before = md.BlockParser(
        childLines.sublist(0, lazyStart),
        parser.document,
      ).parseLines(parentSyntax: this);
      final last = before.isEmpty ? null : before.last;
      if (last is md.Element && last.tag == 'p') {
        final after = md.BlockParser(
          childLines.sublist(lazyStart),
          parser.document,
        ).parseLines();
        return md.Element(_splitTag, [
          md.Element('blockquote', before),
          ...after,
        ]);
      }
    }
    final children = md.BlockParser(
      childLines,
      parser.document,
    ).parseLines(disabledSetextHeading: lazyTail, parentSyntax: this);
    return md.Element('blockquote', children);
  }
}

md.ExtensionSet _extensions(RaftMarkdownMode mode) {
  final gfm = md.ExtensionSet.gitHubFlavored;
  final inline = <md.InlineSyntax>[
    if (mode == RaftMarkdownMode.message) ...[
      _RaftEscapeSyntax(),
      _RaftLinkSyntax(),
      _RaftAutolinkSyntax(),
      _RaftStrikethroughSyntax(),
    ],
    RaftBareUrlSyntax(),
    ...gfm.inlineSyntaxes,
  ];
  if (mode == RaftMarkdownMode.document) {
    return md.ExtensionSet(gfm.blockSyntaxes, inline);
  }
  // The standard block syntaxes without the indented code block.
  return md.ExtensionSet([
    ...gfm.blockSyntaxes,
    const md.EmptyBlockSyntax(),
    const md.HtmlBlockSyntax(),
    const md.SetextHeaderSyntax(),
    const md.HeaderSyntax(),
    if (mode == RaftMarkdownMode.message)
      const _RaftBlockquoteSyntax()
    else
      const md.BlockquoteSyntax(),
    const md.HorizontalRuleSyntax(),
    const md.UnorderedListSyntax(),
    const md.OrderedListSyntax(),
    const md.LinkReferenceDefinitionSyntax(),
    const md.ParagraphSyntax(),
  ], inline);
}

/// Parses [source] into the base tree: before any ref or search pass.
List<md.Node> raftParseMarkdown(String source, RaftMarkdownMode mode) {
  final nodes = md.Document(
    extensionSet: _extensions(mode),
    withDefaultBlockSyntaxes: mode == RaftMarkdownMode.document,
    encodeHtml: false,
  ).parseLines(const LineSplitter().convert(source));
  raftFlattenNestedLinks(nodes);
  if (mode == RaftMarkdownMode.document) return nodes;
  if (mode == RaftMarkdownMode.compact) return _dedentProse(nodes);
  return _htmlAsParagraphs(_unwrapSplits(_dedentProse(nodes)), true);
}

/// An element with the same tag and attributes over [children].
md.Element raftCopyElement(md.Element element, List<md.Node> children) =>
    md.Element(element.tag, children)..attributes.addAll(element.attributes);

List<md.Node> _unwrapSplits(List<md.Node> nodes) {
  final out = <md.Node>[];
  for (final node in nodes) {
    if (node is md.Element && node.children != null) {
      final children = _unwrapSplits(node.children!);
      if (node.tag == _splitTag) {
        out.addAll(children);
      } else {
        out.add(raftCopyElement(node, children));
      }
    } else {
      out.add(node);
    }
  }
  return out;
}

/// Raw HTML a user typed is shown as the text they typed (Web
/// `remarkRawHtmlAsText`); a block of HTML becomes a paragraph.
List<md.Node> _htmlAsParagraphs(List<md.Node> nodes, bool blockLevel) {
  final out = <md.Node>[];
  for (final node in nodes) {
    if (node is md.Text && blockLevel) {
      out.add(md.Element('p', [md.Text(node.text.trimRight())]));
    } else if (node is md.Element && node.children != null) {
      out.add(
        raftCopyElement(
          node,
          _htmlAsParagraphs(node.children!, node.tag == 'blockquote'),
        ),
      );
    } else {
      out.add(node);
    }
  }
  return out;
}

final _lineIndent = RegExp(r'\n[ \t]+');

/// With indented code off, an indented line is a paragraph line: the spaces
/// that would have made it code are not text (CommonMark strips them).
List<md.Node> _dedentProse(List<md.Node> nodes, [bool prose = false]) => [
  for (final (i, node) in nodes.indexed)
    if (node is md.Text && prose)
      md.Text(
        i == 0
            ? node.text.replaceAll(_lineIndent, '\n').trimLeft()
            : node.text.replaceAll(_lineIndent, '\n'),
      )
    else if (node is md.Element && node.children != null)
      raftCopyElement(
        node,
        _dedentProse(node.children!, node.tag == 'p' || node.tag == 'li'),
      )
    else
      node,
];
