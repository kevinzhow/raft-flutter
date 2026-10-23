import 'package:markdown/markdown.dart' as md;
import 'package:raft_ui/src/message_markdown.dart';
import 'package:raft_ui/src/message_tokens.dart';

/// The message passes' result for [source], written back as Markdown where a
/// reference is `[label](<href>)`. Prose only: block structure is kept to
/// paragraphs, quotes and code, which is what the token tests look at.
String tokenized(
  String source, {
  List<RaftTextReference> references = const [],
  String Function(int)? taskHref,
  bool Function(int)? knownTaskNumber,
  bool message = true,
}) {
  final tree = raftApplyMessageTokens(
    raftParseMarkdown(
      source,
      message ? RaftMarkdownMode.message : RaftMarkdownMode.compact,
    ),
    RaftTokenContext(
      references: references,
      taskHref: taskHref,
      knownTaskNumber: knownTaskNumber,
      message: message,
    ),
  );
  return _blocks(tree).trimRight();
}

String _blocks(List<md.Node> nodes) => nodes
    .map(
      (n) => switch (n) {
        md.Element(tag: 'p') => '${_inline(n.children ?? [])}\n\n',
        md.Element(tag: 'blockquote') =>
          _blocks(n.children ?? [])
                  .trimRight()
                  .split('\n')
                  .map((l) => '> $l')
                  .join('\n') +
              '\n\n',
        md.Element(tag: 'pre') =>
          '```${((n.children?.first as md.Element?)?.attributes['class'] ?? '').replaceFirst('language-', '')}\n${n.textContent}```\n\n',
        md.Element(tag: 'ul' || 'ol') =>
          (n.children ?? [])
              .map(
                (li) =>
                    '- ${_inline((li as md.Element).children ?? []).trim()}\n',
              )
              .join(),
        _ => _inline([n]),
      },
    )
    .join();

String _inline(List<md.Node> nodes) => nodes.map((n) {
  if (n is md.Text) return n.text;
  final e = n as md.Element;
  final inner = _inline(e.children ?? []);
  return switch (e.tag) {
    'a' when (e.attributes['href'] ?? '').startsWith('raft-ref:') =>
      '[$inner](<${e.attributes['href']}>)',
    'a' when (e.attributes['href'] ?? '').startsWith('mailto:') => inner,
    'a' when inner == e.attributes['href'] => inner,
    'a' => '[$inner](${e.attributes['href']})',
    'code' => '`$inner`',
    'img' => '![${e.attributes['alt'] ?? ''}](${e.attributes['src']})',
    'strong' => '**$inner**',
    'del' => '~~$inner~~',
    _ => inner,
  };
}).join();
