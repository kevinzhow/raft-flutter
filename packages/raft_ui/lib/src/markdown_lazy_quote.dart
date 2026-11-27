import 'package:markdown/markdown.dart' as md;

class RaftLazyQuote extends md.Element {
  RaftLazyQuote(List<md.Node> blocks, this.source, this.boundary)
    : super('blockquote', blocks);

  final String source;
  final int boundary;

  List<md.Node> split(md.Document document) {
    final parser = md.InlineParser(source, document);
    final marker = _QuoteBoundary(boundary);
    parser.syntaxes.insert(0, marker);
    final inline = parser.parse();
    final (inside, outside) = marker.partition(inline);
    final blocks = children!;
    blocks[blocks.length - 1] = md.Element('p', inside);
    if (outside.firstOrNull case final md.Text text) {
      final tail = text.text.replaceFirst(RegExp(r'^[ \t]*\n'), '');
      if (tail.isEmpty) {
        outside.removeAt(0);
      } else {
        outside[0] = md.Text(tail);
      }
    }
    return [
      md.Element('blockquote', blocks),
      if (outside.isNotEmpty) md.Element('p', outside),
    ];
  }
}

class _QuoteBoundary extends md.InlineSyntax {
  _QuoteBoundary(this.offset) : super('');

  final int offset;
  final marker = md.Element.empty('raft-quote-boundary');
  bool inserted = false;

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    if (inserted || parser.pos < offset) return false;
    inserted = true;
    parser.writeText();
    parser.addNode(marker);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;

  (List<md.Node>, List<md.Node>) partition(List<md.Node> nodes) {
    final inside = <md.Node>[];
    final outside = <md.Node>[];
    var crossed = false;
    for (final node in nodes) {
      if (crossed) {
        outside.add(node);
      } else if (identical(node, marker)) {
        crossed = true;
        if (inside.lastOrNull case final md.Text text
            when text.text.endsWith('\n')) {
          inside[inside.length - 1] = md.Text(
            text.text.substring(0, text.text.length - 1),
          );
        }
      } else if (node is md.Element &&
          node.children != null &&
          _containsBoundary(node)) {
        if (node.tag == 'a') {
          _removeBoundary(node.children!);
          inside.add(node);
        } else {
          final (head, tail) = partition(node.children!);
          if (head.isNotEmpty) inside.add(_withChildren(node, head));
          if (tail.isNotEmpty) outside.add(_withChildren(node, tail));
        }
        crossed = true;
      } else {
        inside.add(node);
      }
    }
    return (inside, outside);
  }

  bool _containsBoundary(md.Node node) =>
      identical(node, marker) ||
      node is md.Element && (node.children?.any(_containsBoundary) ?? false);

  void _removeBoundary(List<md.Node> nodes) {
    nodes.remove(marker);
    for (final node in nodes.whereType<md.Element>()) {
      final children = node.children;
      if (children != null) _removeBoundary(children);
    }
  }

  md.Element _withChildren(md.Element node, List<md.Node> children) =>
      md.Element(node.tag, children)..attributes.addAll(node.attributes);
}
