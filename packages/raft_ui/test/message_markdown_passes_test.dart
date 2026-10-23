import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_markdown.dart';

import 'support/message_tokens.dart';

/// Web v1.21.23 `remarkMessageTokens`, `repairGeneratedMarkdown` and
/// `remarkRawHtmlAsText`: message refs and repairs are recognised on the parsed
/// tree, not by rewriting the source (task #762). Fixtures come from Web's
/// `raftRefs.test.ts`, `messageMarkdownSecurity.test.ts` and
/// `repairGeneratedMarkdown.ts` doc comments.
void main() {
  const refs = [
    RaftTextReference(text: '@Yes', href: 'raft-ref://mention/user/yes'),
    RaftTextReference(text: '@Dave', href: 'raft-ref://mention/user/dave'),
    RaftTextReference(text: '#general', href: 'raft-ref://channel/general'),
    RaftTextReference(text: 'dm:@peer', href: 'raft-ref://channel/dm-peer'),
  ];
  String run(String source) => tokenized(source, references: refs);
  const yes = '[@Yes](<raft-ref://mention/user/yes>)';

  group('code and links are where the parser says they are', () {
    test('~~~ fences, longer fences and ``` on one line are code', () {
      expect(run('~~~\n@Yes\n~~~\nthen @Yes'), '```\n@Yes\n```\n\nthen $yes');
      expect(
        run('````\n```\n@Yes\n```\n````\n@Yes'),
        contains('```\n@Yes\n```'),
      );
      expect(run('``` code @Yes ``` and @Yes'), '`code @Yes` and $yes');
    });

    test('an unclosed fence is code to the end', () {
      expect(
        run('@Yes\n```\nunclosed @Yes'),
        '$yes\n\n```\nunclosed @Yes\n```',
      );
    });

    test('an indented line is prose, not code', () {
      expect(run('text\n\n    @Yes'), 'text\n\n$yes');
    });

    test('link labels and URLs are not mentions', () {
      expect(
        run('[hi @Yes](https://e.com) and @Yes'),
        '[hi @Yes](https://e.com) and $yes',
      );
      expect(
        run('see https://x.com/@Yes and @Yes'),
        'see https://x.com/@Yes and $yes',
      );
      expect(
        run('glued seehttps://x.com/@Yes and @Yes'),
        'glued seehttps://x.com/@Yes and $yes',
      );
      expect(
        run('<https://x.com/@Yes> and @Yes'),
        'https://x.com/@Yes and $yes',
      );
    });

    test('raw HTML is the text the user typed, refs in it still apply', () {
      expect(run('<b>hi</b> @Yes'), '<b>hi</b> $yes');
      expect(run('<div>\nhello @Yes\n</div>'), '<div>\nhello $yes\n</div>');
    });
  });

  group('<target> refs', () {
    test('an angle ref is one chip labelled with the target', () {
      expect(run('<@Dave> hi'), '[@Dave](<raft-ref://mention/user/dave>) hi');
      expect(run('<#general>'), '[#general](<raft-ref://channel/general>)');
      expect(run('<dm:@peer>'), '[dm:@peer](<raft-ref://channel/dm-peer>)');
    });

    test('a ref nothing resolves reads as its label without brackets', () {
      expect(run('<#nowhere> and <@ghost>'), '#nowhere and @ghost');
    });

    test('\\<target> stays literal and no matcher claims part of it', () {
      expect(run(r'hi \<@Dave> there'), 'hi <@Dave> there');
    });

    test('[label](<target>) is a ref, [label](#target) is not', () {
      expect(
        run('[Boss](<@Dave>) [x](#general)'),
        '[Boss](<raft-ref://mention/user/dave>) [x](#general)',
      );
      expect(run('[who](<@ghost>)'), 'who');
    });

    test('a ref inside code or a link label is left alone', () {
      expect(run('`<@Dave>`'), '`<@Dave>`');
      expect(run('[<@Dave> z](https://e.com)'), '[<@Dave> z](https://e.com)');
    });

    test('dm:@peer~agent is not a strikethrough', () {
      expect(
        run('dm:@Twin~agent and dm:@Twin~human'),
        'dm:@Twin~agent and dm:@Twin~human',
      );
      expect(run('~~gone~~ ~one~'), '~~gone~~ ~~one~~');
    });
  });

  group('generated Markdown is repaired', () {
    test('a literal backslash-n becomes a line break, outside code', () {
      expect(run(r'line1\nline2'), 'line1\nline2');
      expect(run(r'`a\nb`'), r'`a\nb`');
      expect(run(r'[a\nb](https://e.com)'), r'[a\nb](https://e.com)');
    });

    test('**label: **value is the strong span the writer meant', () {
      expect(
        run('- **Registration: **203 users'),
        '- **Registration:** 203 users',
      );
      expect(run(r'\**x **'), r'**x **');
      expect(run('`**a **`'), '`**a **`');
    });

    test('an unquoted line after a quote is a new paragraph', () {
      expect(run('> quote\nlazy line'), '> quote\n\nlazy line');
      expect(run('> a\nb\n> c\n\nd'), '> a\n\nb\nc\n\nd');
      expect(run('> # h\ntext'), contains('text'));
    });

    test('the same text outside the message pipeline is unchanged', () {
      expect(
        tokenized('> quote\nlazy line', message: false),
        '> quote\n> lazy line',
      );
      expect(tokenized(r'a\nb', message: false), r'a\nb');
    });
  });

  test('a mention reads the display name, however the handle was typed', () {
    const named = [
      RaftTextReference(
        text: '@ada',
        href: 'raft-ref://mention/agent/ada',
        label: '@Ada Lovelace',
      ),
    ];
    const chip = '[@Ada Lovelace](<raft-ref://mention/agent/ada>)';
    expect(tokenized('hi @ada', references: named), 'hi $chip');
    expect(tokenized('hi <@ada>', references: named), 'hi $chip');
    // An authored label stays the author's.
    expect(
      tokenized('[the boss](<@ada>)', references: named),
      '[the boss](<raft-ref://mention/agent/ada>)',
    );
  });

  test('compact Markdown has no indented code, documents keep it', () {
    expect(
      raftParseMarkdown('x\n\n    code', RaftMarkdownMode.compact).length,
      2,
    );
    final document = raftParseMarkdown(
      'x\n\n    code',
      RaftMarkdownMode.document,
    );
    expect(document.last.textContent, contains('code'));
    expect((document.last as dynamic).tag, 'pre');
  });

  for (final theme in [raftTheme(RaftFamily.elegant)]) {
    testWidgets('a message shows an escaped angle ref, repairs and marks', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: RaftMessageBody(
              content: r'hi \<@Dave> and [link text](https://e.com)\n- **Registration: **203 users',
              mountedMessage: true,
              messagePipeline: true,
              searchHighlight: 'link',
              references: refs,
            ),
          ),
        ),
      );
      final text = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text.toPlainText())
          .join('|');
      expect(text, contains('hi <@Dave> and link text'));
      expect(text, contains('Registration: 203 users'));
      expect(text, isNot(contains('**')));
      // The search mark sits inside the link label, and the label stays a link.
      var marked = false;
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan &&
              span.text == 'link' &&
              span.recognizer != null &&
              span.style?.backgroundColor != null) {
            marked = true;
          }
          return true;
        });
      }
      expect(marked, isTrue);
    });
  }
}
