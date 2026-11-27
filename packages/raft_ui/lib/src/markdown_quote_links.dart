import 'package:markdown/markdown.dart' as md;

import 'lru_cache.dart';
import 'markdown_math.dart';
import 'message_markdown.dart';

final _quoteLinks = RaftLruCache<String, List<String>>(512);

Iterable<String> raftMarkdownQuoteLinks(String source) =>
    _quoteLinks.putIfAbsent(
      source,
      () => List.unmodifiable(
        _links(raftParseMarkdown(source, RaftMarkdownMode.message)),
      ),
    );

Iterable<String> _links(List<md.Node> nodes) sync* {
  for (final node in nodes.whereType<md.Element>()) {
    switch (node.tag) {
      case 'a':
        final address = node.textContent;
        if (!node.attributes.containsKey(raftLabelledLinkAttribute) &&
            (address.startsWith('https://') ||
                address.startsWith('http://') ||
                address.startsWith('raft://'))) {
          yield node.attributes['href'] ?? address;
        }
      case 'pre':
      case 'code':
      case raftMathDisplayTag:
        break;
      default:
        yield* _links(node.children ?? const []);
    }
  }
}
