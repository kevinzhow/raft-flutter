import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  String doc(int sections) => [
    for (var i = 1; i <= sections; i++)
      '## Section $i\n\n${'Words and more words. ' * 20}\n\n- a\n- b\n',
  ].join('\n');

  test('a short document is one block', () {
    expect(raftSplitMarkdownBlocks('# T\n\nbody'), ['# T\n\nbody']);
  });

  test('cuts only at headings: no content lost, none repeated', () {
    final source = doc(60);
    final blocks = raftSplitMarkdownBlocks(source, target: 2000);
    expect(blocks.length, greaterThan(5));
    for (final block in blocks) {
      expect(block.startsWith('## Section'), isTrue, reason: block);
    }
    expect(
      blocks.join('\n\n').replaceAll('\n\n\n', '\n\n'),
      contains('Section 60'),
    );
    expect(RegExp('## Section').allMatches(blocks.join('\n')).length, 60);
  });

  test('a fenced block is never cut, even with headings inside it', () {
    final code = List.filled(300, '# not a heading, just code').join('\n');
    final source = 'intro\n\n```sh\n$code\n```\n\n## After\n\ntext';
    final blocks = raftSplitMarkdownBlocks(source, target: 500);
    final holder = blocks.where((b) => b.contains('```sh')).single;
    expect(holder.contains('```\n') || holder.endsWith('```'), isTrue);
    expect(
      RegExp('```').allMatches(holder).length,
      2,
      reason: 'both fences stay in one block',
    );
  });

  test('lists, tables and setext headings are not split mid-way', () {
    final items = List.generate(400, (i) => '- item $i').join('\n');
    final table =
        '| a | b |\n|---|---|\n${List.filled(200, '| 1 | 2 |').join('\n')}';
    final source = 'Title\n=====\n\n$items\n\n$table\n\n## End\n';
    final blocks = raftSplitMarkdownBlocks(source, target: 300);
    for (final block in blocks) {
      expect(
        block.contains('- item 1') == block.contains('- item 399'),
        isTrue,
        reason: 'the list stays whole',
      );
    }
    final withTable = blocks.where((b) => b.contains('|---|---|')).single;
    expect(RegExp(r'\| 1 \| 2 \|').allMatches(withTable).length, 200);
    expect(blocks.first.startsWith('Title\n====='), isTrue);
  });

  test('link reference definitions reach every block', () {
    final source = '${doc(30)}\n[ref]: https://example.com/page\n';
    final blocks = raftSplitMarkdownBlocks(source, target: 1500);
    expect(blocks.length, greaterThan(2));
    for (final block in blocks) {
      expect(block, contains('[ref]: https://example.com/page'));
    }
  });
}
