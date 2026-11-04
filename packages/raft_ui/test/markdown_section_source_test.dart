import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:raft_ui/src/message_markdown.dart';
import 'package:raft_ui/raft_ui.dart' show raftExtractMarkdownOutline;

void main() {
  test(
    'ATX source identity survives isolate parsing without HTML attributes',
    () async {
      const source =
          'Setext\n------\n\n## **Same** `API`\n\nBody\n\n## Same API';
      final nodes = await Isolate.run(
        () => raftParseMarkdown(source, RaftMarkdownMode.document),
      );
      final headings = nodes.whereType<RaftMarkdownHeadingElement>().toList();
      expect(headings.map((h) => h.sourceLine), [4, 8]);
      expect(headings.map((h) => h.textContent), ['Same API', 'Same API']);
      expect(headings.every((h) => h.attributes.isEmpty), isTrue);
      final copied = raftCopyElement(headings.last, headings.last.children!);
      expect(copied, isA<RaftMarkdownHeadingElement>());
      expect((copied as RaftMarkdownHeadingElement).sourceLine, 8);
      expect(md.renderToHtml(nodes), isNot(contains('sourceLine')));
    },
  );
  test('heading IDs match fixed Web NFKD results across scripts and duplicate formatting', () {
    final titles = [
      'Café API',
      'Déjà vu',
      'がっこう',
      'ガイド',
      '한글 제목',
      'ＡＰＩ　設定',
      '① Usage',
      'éa',
      'Łódź',
      'e\u0301a',
    ];
    final ids = [
      for (final title in titles)
        raftExtractMarkdownOutline('## $title').single.id,
    ];
    expect(ids, [
      'cafe-api',
      'de-ja-vu',
      'か-っこう',
      'カ-イト',
      '한글-제목',
      'api-設定',
      '1-usage',
      'e-a',
      'ło-dz',
      'e-a',
    ]);
    expect(
      raftExtractMarkdownOutline('## **ガイド**\n\n## ガイド').map((h) => h.id),
      ['カ-イト', 'カ-イト-2'],
    );
  });
}
