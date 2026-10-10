import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Compact message-row semantics: one node per message, interactive content
// only as children (links, code, toggles, reactions).

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

List<SemanticsNode> _below(SemanticsNode node) {
  final out = <SemanticsNode>[];
  void visit(SemanticsNode n) => n.visitChildren((c) {
    out.add(c);
    visit(c);
    return true;
  });
  visit(node);
  return out;
}

void main() {
  testWidgets('a compact tile is one labelled node with custom actions', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    final invoked = <String>[];
    var menu = 0;
    String? opened;
    await t.pumpWidget(
      _host(
        RaftMessageTile(
          author: 'Alice',
          timestamp: '10:01 AM',
          departureLabel: 'Left',
          content: 'Hello **there**, see [the spec](https://example.invalid).',
          compactSemantics: true,
          onLink: (href) => opened = href,
          onActions: () => menu++,
          onAuthor: () => invoked.add('mention'),
          semanticsActions: [
            RaftMessageSemanticsAction('Save message', (_) {
              invoked.add('save');
            }),
          ],
          reactions: const [
            {'emoji': '👍', 'count': 1},
          ],
        ),
      ),
    );
    final row = t.getSemantics(find.byType(RaftMessageRow));
    expect(row.label, 'Alice, Left, 10:01 AM\nHello there, see the spec.');
    final data = row.getSemanticsData();
    expect(
      [
        for (final id in data.customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label,
      ],
      ['Save message', 'Mention Alice'],
    );
    expect(_below(row).map((n) => n.label), ['the spec', '👍: 1']);

    final owner = t.binding.renderViews.first.owner!.semanticsOwner!;
    for (final id in data.customSemanticsActionIds!) {
      owner.performAction(row.id, SemanticsAction.customAction, id);
    }
    owner.performAction(row.id, SemanticsAction.longPress);
    owner.performAction(
      _below(row).firstWhere((n) => n.label == 'the spec').id,
      SemanticsAction.tap,
    );
    expect(invoked, ['save', 'mention']);
    expect(menu, 1);
    expect(opened, 'https://example.invalid');
    semantics.dispose();
  });

  testWidgets('a code block is announced by size and language, not source', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    String? copied;
    await t.pumpWidget(
      _host(
        RaftCodeBlock(
          code: 'a\nb',
          language: 'python',
          onCopy: (code) async => copied = code,
        ),
      ),
    );
    final node = t.getSemantics(find.byType(RaftCodeBlock));
    expect(node.label, 'Code block, 2 lines, python');
    expect(_below(node), isEmpty);
    final owner = t.binding.renderViews.first.owner!.semanticsOwner!;
    owner.performAction(node.id, SemanticsAction.tap);
    await t.pump();
    expect(copied, 'a\nb');
    expect(t.getSemantics(find.byType(RaftCodeBlock)).value, 'Copied');
    await t.pump(const Duration(seconds: 3));
    semantics.dispose();
  });

  testWidgets('compact prose keeps links but not text; others are unchanged', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    for (final compact in [true, false]) {
      await t.pumpWidget(
        _host(
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: RaftMessageBody(
              key: ValueKey(compact),
              compactSemantics: compact,
              content: 'Plain words and [a link](https://example.invalid).',
              onLink: (_) {},
            ),
          ),
        ),
      );
      final labels = [
        for (final n in _below(t.getSemantics(find.byType(RaftMessageBody))))
          n.label,
      ];
      expect(labels, contains('a link'));
      expect(
        labels.any((l) => l.contains('Plain words')),
        !compact,
        reason: 'compact=$compact',
      );
    }
    semantics.dispose();
  });

  testWidgets('day header announces its date once, in reading case', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      _host(const RaftConversationDateHeader(label: 'Thursday, October 1')),
    );
    expect(
      t.getSemantics(find.byType(RaftConversationDateHeader)),
      matchesSemantics(label: 'Thursday, October 1', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('show more toggle announces its label once', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      _host(RaftShowMoreToggle(label: 'Show more', onPressed: () {})),
    );
    expect(find.bySemanticsLabel(RegExp(r'^Show more$')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('message text and links drop Markdown syntax', (t) async {
    late BuildContext context;
    await t.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    expect(
      raftMessageSemanticsText(
        context,
        '## Title\n\n> **Quoted** _text_ with `a*b`\n\n'
        '- [x] done item\n1. first\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n'
        '---\nsnake_case and ![alt](img.png) and <https://x.invalid>\n\n'
        '```js\nlet a\n```',
      ),
      'Title\nQuoted text with a*b\ndone item\nfirst\nA B\n1 2\n'
      'snake_case and alt and https://x.invalid\nCode block, 1 line, js',
    );
    expect(
      raftMessageSemanticsLinks(
        'Go to https://a.invalid/x. Not `https://code.invalid`; '
        '[\u{E000}raft-ref://mention/user/c\u{E001}@c\u{E002} notes](https://n.invalid) '
        'and \u{E000}raft-ref://channel/1\u{E001}#gen\u{E002}',
      ),
      [
        (label: 'https://a.invalid/x', href: 'https://a.invalid/x'),
        (label: '@c notes', href: 'https://n.invalid'),
        (label: '@c', href: 'raft-ref://mention/user/c'),
        (label: '#gen', href: 'raft-ref://channel/1'),
      ],
    );
  });
}
