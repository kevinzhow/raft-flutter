import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/markdown_math.dart';
import 'package:raft_ui/src/message_markdown.dart';

/// Web v1.24 message Markdown: math (`remarkRaftMath`, shared
/// `markdownMath.ts`) and the CJK-friendly emphasis rule
/// (`remark-cjk-friendly`). Expected trees come from Web's own parser
/// (micromark + the same extensions) and `markdownMath.test.ts`.
void main() {
  String html(
    String source, [
    RaftMarkdownMode mode = RaftMarkdownMode.message,
  ]) => md.HtmlRenderer().render(raftParseMarkdown(source, mode)).trim();

  /// Every formula in [source] as `inline:` / `block:` plus its source.
  List<String> formulas(String source) {
    final found = <String>[];
    void visit(List<md.Node>? nodes) {
      for (final node in nodes ?? const <md.Node>[]) {
        if (node is! md.Element) continue;
        if (raftIsInlineMath(node)) found.add('inline:${node.textContent}');
        if (node.tag == raftMathDisplayTag) {
          found.add('block:${node.textContent}');
        }
        visit(node.children);
      }
    }

    visit(raftParseMarkdown(source, RaftMarkdownMode.message));
    return found;
  }

  group('math (markdownMath.test.ts)', () {
    test('a single-dollar pair is math when it hugs its content', () {
      expect(formulas(r'area $\pi r^2$ here'), [r'inline:\pi r^2']);
      expect(formulas(r'$x$, $y$.'), ['inline:x', 'inline:y']);
      expect(formulas(r'$x^2$'), ['inline:x^2']);
    });

    test('prices stay text', () {
      expect(formulas(r'从 $5 到 $10'), isEmpty);
      expect(formulas(r'$5 and $10 each'), isEmpty);
      expect(formulas(r'costs $ 5 and $6'), isEmpty);
      expect(formulas(r'a $ x$ b'), isEmpty);
      expect(formulas(r'a $x $ b'), isEmpty);
      expect(formulas(r'$5,$10'), isEmpty);
    });

    test('single-dollar math stays on one line; escaped dollars are text', () {
      expect(formulas('\$a\nb\$'), isEmpty);
      expect(formulas(r'\$x\$'), isEmpty);
    });

    test('double dollars are math inline and as a block', () {
      expect(formulas(r'then $$E = mc^2$$ holds'), ['inline:E = mc^2']);
      expect(formulas('\$\$\n\\int_0^1 x\\,dx\n\$\$'), [
        r'block:\int_0^1 x\,dx',
      ]);
      expect(formulas(r'$$ a + b $$'), ['inline:a + b']);
    });

    test('a block interrupts a paragraph and runs to the end unclosed', () {
      expect(formulas('text\n\$\$\nx^2\n\$\$\nmore'), ['block:x^2']);
      expect(formulas('\$\$\nx\ny'), ['block:x\ny']);
    });

    test('an @ or a link inside a formula is not read as one', () {
      final tree = html(r'see $a @alice <https://x.y>$ end');
      expect(
        tree,
        contains('<code class="language-math">a @alice <https://x.y></code>'),
      );
    });

    test('documents and compact text read math too', () {
      expect(
        html(r'$x$', RaftMarkdownMode.document),
        contains('language-math'),
      );
      expect(html(r'$x$', RaftMarkdownMode.compact), contains('language-math'));
    });
  });

  group('CJK-friendly emphasis (remark-cjk-friendly 2.3.2)', () {
    // [source, Web's HTML] from micromark + gfm + cjk-friendly.
    const cases = [
      ['中文**“重点”**中文', '<p>中文<strong>“重点”</strong>中文</p>'],
      ['**「テスト」**です', '<p><strong>「テスト」</strong>です</p>'],
      ['한국어**(강조)**입니다', '<p>한국어<strong>(강조)</strong>입니다</p>'],
      ['a**"b"**c', '<p>a**&quot;b&quot;**c</p>'],
      ['**foo**bar', '<p><strong>foo</strong>bar</p>'],
      ['说**“重点”**。', '<p>说<strong>“重点”</strong>。</p>'],
      ['日本語の*「強調」*です', '<p>日本語の<em>「強調」</em>です</p>'],
      ['中文__“重点”__中文', '<p>中文__“重点”__中文</p>'],
      ['这是**加粗**的', '<p>这是<strong>加粗</strong>的</p>'],
      ['a**b**c', '<p>a<strong>b</strong>c</p>'],
      ['𠀀**“x”**𠀀', '<p>𠀀<strong>“x”</strong>𠀀</p>'],
      ['😀**“x”**😀', '<p>😀<strong>“x”</strong>😀</p>'],
      ['中文*~~删除~~*中文', '<p>中文<em><del>删除</del></em>中文</p>'],
    ];
    for (final [source, expected] in cases) {
      test(source, () {
        expect(
          html(source, RaftMarkdownMode.compact).replaceAll('"', '&quot;'),
          expected.replaceAll('"', '&quot;'),
        );
      });
    }

    test('message bodies and documents use the same rule', () {
      expect(html('中文**“重点”**中文'), contains('<strong>“重点”</strong>'));
      expect(
        html('中文**“重点”**中文', RaftMarkdownMode.document),
        contains('<strong>“重点”</strong>'),
      );
    });
  });

  group('rendering', () {
    Future<void> pump(WidgetTester tester, String content) => tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false),
        home: Scaffold(
          body: RaftMessageBody(content: content, messagePipeline: true),
        ),
      ),
    );

    testWidgets('an inline formula renders in the line, not as code', (
      tester,
    ) async {
      await pump(tester, r'area $\pi r^2$ here');
      expect(find.byType(RaftInlineMath), findsOneWidget);
      expect(find.byType(Math), findsOneWidget);
      expect(find.textContaining(r'\pi'), findsNothing);
    });

    testWidgets('a block formula renders on its own, centred', (tester) async {
      await pump(tester, 'before\n\n\$\$\n\\frac{a}{b}\n\$\$\n\nafter');
      expect(find.byType(RaftDisplayMath), findsOneWidget);
      final math = tester.getRect(find.byType(Math));
      final body = tester.getRect(find.byType(RaftDisplayMath));
      expect(math.center.dx, closeTo(body.center.dx, 1));
    });

    testWidgets('a formula KaTeX cannot read shows its source in red', (
      tester,
    ) async {
      await pump(tester, r'bad $\frac{a$ here');
      final error = tester.widget<Text>(find.text(r'\frac{a'));
      expect(error.style?.color, raftMathErrorColor);
    });

    testWidgets('CJK emphasis renders bold', (tester) async {
      await pump(tester, '中文**“重点”**中文');
      expect(find.textContaining('**'), findsNothing);
    });
  });
}
