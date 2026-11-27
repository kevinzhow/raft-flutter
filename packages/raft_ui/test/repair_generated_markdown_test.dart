import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:raft_ui/src/message_markdown.dart';

void main() {
  List<md.Element> parse(String source) =>
      raftParseMarkdown(source, RaftMarkdownMode.message).cast<md.Element>();

  test('repairGeneratedMarkdown keeps a multiline atom in the quote', () {
    for (final (source, tag) in [
      ('> [first\nsecond](https://example.com) outside', 'a'),
      ('> [first](\nhttps://example.com) outside', 'a'),
      ('> `first\nsecond` outside', 'code'),
      (
        r'> formula $$first'
            '\n'
            r'second$$ outside',
        'code',
      ),
    ]) {
      final result = parse(source);
      expect(result.map((node) => node.tag), [
        'blockquote',
        'p',
      ], reason: source);
      final quote = result.first.children!.single as md.Element;
      expect(
        quote.children!.whereType<md.Element>().single.tag,
        tag,
        reason: source,
      );
      expect(result.last.textContent.trim(), 'outside', reason: source);
    }
  });

  test('repairGeneratedMarkdown splits emphasis at the lazy line', () {
    final result = parse('> **first\nsecond**');
    final inside = result.first.children!.single as md.Element;
    for (final (paragraph, expected) in [
      (inside, 'first'),
      (result.last, 'second'),
    ]) {
      final strong = paragraph.children!.single as md.Element;
      expect(strong.tag, 'strong');
      expect(strong.textContent, expected);
    }
  });
}
