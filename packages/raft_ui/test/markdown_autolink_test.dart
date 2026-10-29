import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/markdown_autolink.dart';

// Bare-URL linkification of message Markdown: a port of Web's
// markdownAutolink.test.ts (remark-gfm + remarkAutolinkBareUrls) plus the
// CJK cases the stock GFM autolink got wrong.

String _html(List<md.Node> nodes) => nodes.map(_node).join();

String _node(md.Node node) {
  if (node is md.Text) return node.text;
  final e = node as md.Element;
  final attrs = e.attributes.entries
      .map((a) => ' ${a.key}="${a.value}"')
      .join();
  final inner = _html(e.children ?? const []);
  return e.isEmpty ? '<${e.tag}$attrs/>' : '<${e.tag}$attrs>$inner</${e.tag}>';
}

/// The parser configuration of the message body.
List<md.Node> _parse(String source) => raftFlattenNestedLinks(
  md.Document(
    inlineSyntaxes: [RaftBareUrlSyntax()],
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parseLines(source.split('\n')),
);

String _render(String source) => _html(_parse(source));

/// `<p>` contents with links shown as `[text](href)` for compact asserts.
String _flat(String source) => _render(source)
    .replaceAllMapped(
      RegExp(r'<a href="([^"]*)">([^<]*)</a>'),
      (m) => m[1] == m[2] ? '⟦${m[2]}⟧' : '⟦${m[2]} → ${m[1]}⟧',
    )
    .replaceAll(RegExp(r'^<p>|</p>$'), '');

/// Fastest of [samples] parses, each repeating [repeats] times.
/// One sample lies when the machine stalls mid-measurement; the minimum
/// does not. Repeats keep a short input above one scheduling slice.
int _fastestParse(String source, {int samples = 5, int repeats = 1}) {
  var best = 1 << 62;
  for (var i = 0; i < samples; i++) {
    final watch = Stopwatch()..start();
    for (var n = 0; n < repeats; n++) {
      _parse(source);
    }
    watch.stop();
    final micros = watch.elapsedMicroseconds;
    if (micros < best) best = micros;
  }
  return best;
}

/// How many parses put [source] near 10ms on its fastest probe.
int _repeatsFor(String source) {
  final probe = _fastestParse(source, samples: 3);
  if (probe >= 10000) return 1;
  return (10000 / (probe == 0 ? 1 : probe)).ceil().clamp(1, 200);
}

List<({String text, String href})> _links(List<md.Node> nodes) => [
  for (final n in nodes)
    if (n is md.Element) ...[
      if (n.tag == 'a')
        (text: n.textContent, href: n.attributes['href']!)
      else
        ..._links(n.children ?? const []),
    ],
];

void main() {
  group('Web markdownAutolink vectors', () {
    test('keeps explicit markdown links ahead of bare-url linkification', () {
      final html = _render(
        '来源：[Meta 官方建广告账户](https://www.facebook.com/business/help/407323696966570)、2026 Business Manager 教程',
      );
      expect(
        html,
        contains(
          '<a href="https://www.facebook.com/business/help/407323696966570">',
        ),
      );
      expect(html, contains('>Meta 官方建广告账户</a>、2026 Business Manager 教程'));
      expect(html, isNot(contains('[Meta')));
      expect(html, isNot(contains('407323696966570)"')));
    });

    test('keeps CJK comma outside bare URL autolinks', () {
      final html = _render('slock 深度用户 https://x.com/Trader_Pheneck，给了些反馈，在');
      expect(html, contains('<a href="https://x.com/Trader_Pheneck">'));
      expect(html, contains('>https://x.com/Trader_Pheneck</a>，给了些反馈，在'));
      expect(html, isNot(contains('href="https://x.com/Trader_Pheneck，')));
    });

    test('keeps URL-internal ASCII punctuation, splits on CJK punctuation', () {
      final html = _render('see https://example.com/a,b?x=1&y=2，后续');
      expect(html, contains('href="https://example.com/a,b?x=1&y=2"'));
      expect(html, contains('>https://example.com/a,b?x=1&y=2</a>，后续'));
    });

    test('keeps unmatched ASCII closing parens outside bare URL autolinks', () {
      const url = 'https://www.facebook.com/business/help/407323696966570';
      final html = _render('来源：（$url）、教程');
      expect(html, contains('（<a href="$url">'));
      expect(html, contains('>$url</a>）、教程'));
      expect(html, isNot(contains('href="$url)')));
      expect(html, isNot(contains('href="$url）')));
      // A real ASCII paren is excluded too.
      expect(_flat('来源：($url)、教程'), '来源：(⟦$url⟧)、教程');
    });

    test('preserves balanced ASCII parens inside bare URL autolinks', () {
      final html = _render('read https://example.com/foo_(bar)、then');
      expect(html, contains('<a href="https://example.com/foo_(bar)">'));
      expect(html, contains('>https://example.com/foo_(bar)</a>、then'));
    });

    test('keeps ASCII comma outside when followed by CJK text', () {
      final html = _render('https://cua.ai, 稍后输出机会评分卡。');
      expect(html, contains('<a href="https://cua.ai">'));
      expect(html, contains('>https://cua.ai</a>, 稍后输出机会评分卡。'));
      expect(html, isNot(contains('href="https://cua.ai,')));
    });
  });

  group('bare URLs in CJK prose', () {
    test(
      'after a CJK colon, directly after CJK text, inside full-width parens',
      () {
        expect(
          _flat('链接：https://docs.raft.build/x'),
          '链接：⟦https://docs.raft.build/x⟧',
        );
        expect(
          _flat('看这里https://docs.raft.build/x'),
          '看这里⟦https://docs.raft.build/x⟧',
        );
        expect(
          _flat('地址（https://docs.raft.build/x）'),
          '地址（⟦https://docs.raft.build/x⟧）',
        );
      },
    );

    test('www. links after CJK punctuation, not glued to a word', () {
      expect(
        _flat('见：www.example.com/a'),
        '见：⟦www.example.com/a → http://www.example.com/a⟧',
      );
      expect(
        _flat('see www.example.com/a'),
        'see ⟦www.example.com/a → http://www.example.com/a⟧',
      );
      expect(_flat('看www.example.com/a'), '看www.example.com/a');
      expect(_flat('awww.example.com'), 'awww.example.com');
    });

    test('the link stops at CJK punctuation and the text after it stays', () {
      expect(
        _flat('打开 https://docs.raft.build/x。然后'),
        '打开 ⟦https://docs.raft.build/x⟧。然后',
      );
      expect(
        _flat('www.example.com/a。然后'),
        '⟦www.example.com/a → http://www.example.com/a⟧。然后',
      );
      for (final p in '，。、；：！？）》」』】〉”’'.split('')) {
        expect(
          _flat('https://a.com/x${p}后'),
          '⟦https://a.com/x⟧$p后',
          reason: p,
        );
      }
    });

    test('CJK text without punctuation stays in the URL (Web keeps it)', () {
      expect(_flat('https://a.com/一二三 好'), startsWith('⟦https://a.com/一二三'));
      expect(
        _links(_parse('https://a.com/一二三 好')).single.href,
        'https://a.com/%E4%B8%80%E4%BA%8C%E4%B8%89',
      );
    });

    test('an ASCII comma before CJK text ends the link, one inside stays', () {
      expect(_flat('https://cua.ai,稍后'), '⟦https://cua.ai⟧,稍后');
      expect(_flat('https://a.com/a,b好'), startsWith('⟦https://a.com/a,b'));
      expect(
        _flat('see https://a.com/x,\nnext'),
        contains('⟦https://a.com/x⟧,'),
      );
    });

    test('trailing ASCII punctuation and unmatched closers stay outside', () {
      expect(_flat('看https://a.com/x.'), '看⟦https://a.com/x⟧.');
      expect(_flat('see https://a.com/x?'), 'see ⟦https://a.com/x⟧?');
      expect(_flat('(https://a.com/x)'), '(⟦https://a.com/x⟧)');
      expect(_flat('https://a.com/foo_(bar)).'), '⟦https://a.com/foo_(bar)⟧).');
      expect(
        _flat('**https://a.com/x**，好'),
        '<strong>⟦https://a.com/x⟧</strong>，好',
      );
      expect(_flat('https://a.com/x&amp;'), '⟦https://a.com/x⟧&');
    });

    test('a full-width space ends the link', () {
      expect(_flat('https://a.com/x　后'), '⟦https://a.com/x⟧　后');
    });

    test('schemes: only http, https and www. are bare links', () {
      expect(_flat('javascript:alert(1)'), 'javascript:alert(1)');
      expect(_flat('https://'), 'https://');
      expect(_flat('https://，x'), 'https://，x');
      expect(_flat('HTTP://A.com/x，'), '⟦HTTP://A.com/x⟧，');
    });

    test('explicit links, angle autolinks and code win', () {
      expect(
        _flat('[https://a.com](https://b.com)'),
        '⟦https://a.com → https://b.com⟧',
      );
      expect(
        _flat('[看 https://a.com/z](https://b.com)'),
        '⟦看 https://a.com/z → https://b.com⟧',
      );
      expect(_flat('[看 https://a.com/z]'), '[看 ⟦https://a.com/z⟧]');
      expect(_flat('<https://a.com>，x'), '⟦https://a.com⟧，x');
      expect(_flat('`https://a.com`'), '<code>https://a.com</code>');
      expect(
        _render('```\nhttps://a.com\n```'),
        '<pre><code>https://a.com\n</code></pre>',
      );
      expect(_render('![x](https://a.com/i.png)'), isNot(contains('<a ')));
    });

    test('URLs with underscores, tildes and CJK hosts stay whole', () {
      expect(_flat('a https://a.com/x_y_z b'), 'a ⟦https://a.com/x_y_z⟧ b');
      expect(_flat('a https://a.com/~u/x b'), 'a ⟦https://a.com/~u/x⟧ b');
      expect(_links(_parse('https://中文.com/路径，好')).single, (
        text: 'https://中文.com/路径',
        href: 'https://%E4%B8%AD%E6%96%87.com/%E8%B7%AF%E5%BE%84',
      ));
    });

    test('several URLs in one paragraph', () {
      expect(
        _links(_parse('一https://a.com/1，二（https://b.com/2）三 www.c.com/3。')),
        [
          (text: 'https://a.com/1', href: 'https://a.com/1'),
          (text: 'https://b.com/2', href: 'https://b.com/2'),
          (text: 'www.c.com/3', href: 'http://www.c.com/3'),
        ],
      );
    });
  });

  test('a long CJK paragraph with many URLs parses in linear time', () {
    final unit =
        '链接：https://docs.raft.build/p/xyz?a=1&b=2。再看（www.example.com/a）和https://a.com/x_(y)，好。';
    const copies = 1500;
    expect(
      _links(_parse(List.filled(copies, unit).join())),
      hasLength(copies * 3),
    );
    // 4x input. Quadratic would be about 16x. Keep the fastest sample of
    // each size so a stall on one run is not the measurement.
    final n = _fastestParse(List.filled(copies, unit).join());
    final four = _fastestParse(List.filled(copies * 4, unit).join());
    print('autolink-linear N=$n us 4N=$four us');
    expect(n, greaterThan(0));
    expect(four, lessThan(n * 8), reason: '4N ${four}us, N ${n}us');
  });

  test('pathological runs do not blow up', () {
    for (final s in [
      'https://${')' * 50000}',
      'https://${'[' * 50000}',
      'www.${'a.' * 30000}',
      'https://,' * 20000,
      'https://${',' * 50000}好',
      '${'https://，' * 20000}',
    ]) {
      final quarter = s.substring(0, s.length ~/ 4);
      final repeats = _repeatsFor(quarter);
      final n = _fastestParse(quarter, repeats: repeats);
      final four = _fastestParse(s, repeats: repeats);
      print(
        'autolink-pathological ${s.substring(0, 12)} '
        'x$repeats N=$n us 4N=$four us',
      );
      expect(n, greaterThan(0), reason: s.substring(0, 20));
      expect(
        four,
        lessThan(n * 8),
        reason: '${s.substring(0, 20)} 4N ${four}us, N ${n}us',
      );
    }
  });

  group('semantics links agree with the rendered links', () {
    const corpus = [
      '链接：https://docs.raft.build/x',
      '看这里https://docs.raft.build/x',
      '地址（https://docs.raft.build/x）',
      '见：www.example.com/a',
      '打开 https://docs.raft.build/x。然后',
      'https://cua.ai, 稍后输出机会评分卡。',
      'read https://example.com/foo_(bar)、then',
      'see https://example.com/a,b?x=1&y=2，后续',
      '[https://a.com](https://b.com) and https://c.com/1.',
      'Not `https://code.invalid` but https://yes.invalid/a!',
      '![x](https://a.com/i.png) https://b.com/z',
      '<https://a.com>，https://b.com',
    ];
    for (final source in corpus) {
      test(source, () {
        final rendered = _links(_parse(source));
        final semantic = raftMessageSemanticsLinks(source);
        // Semantics skips images; compare hrefs and labels of links.
        expect(
          [for (final l in semantic) (text: l.label, href: l.href)],
          [for (final l in rendered) (text: l.text, href: l.href)],
        );
      });
    }
  });

  testWidgets('the message body hands the trimmed href to onLink', (t) async {
    String? opened;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftMessageBody(
            content: '看这里https://docs.raft.build/x。然后',
            onLink: (href) => opened = href,
          ),
        ),
      ),
    );
    final finder = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('docs.raft.build'),
    );
    expect(finder, findsOneWidget);
    final rich = t.renderObject<RenderParagraph>(finder);
    final text = rich.text.toPlainText();
    final at = text.indexOf('docs.raft');
    final box = rich.getBoxesForSelection(
      TextSelection(baseOffset: at, extentOffset: at + 4),
    );
    await t.tapAt(rich.localToGlobal(box.first.toRect().center));
    await t.pump(const Duration(milliseconds: 400));
    expect(opened, 'https://docs.raft.build/x');
    expect(text, contains('。然后'));
  });

  test('inline previews link bare URLs the same way', () {
    const link = Color(0xff0000ff);
    final span = raftInlineMarkdownSpan(
      '链接：https://docs.raft.build/x。然后',
      const TextStyle(color: Color(0xff000000)),
      linkColor: link,
      code: const TextStyle(),
    );
    final linked = <String>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.style?.color == link && s.text != null) {
        linked.add(s.text!);
      }
      return true;
    });
    expect(span.toPlainText(), '链接：https://docs.raft.build/x。然后');
    expect(linked, ['https://docs.raft.build/x']);
  });
}
