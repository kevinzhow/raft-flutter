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
}
