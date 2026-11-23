import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

int elements(Element element) {
  var count = 1;
  element.visitChildren((child) => count += elements(child));
  return count;
}

void main() {
  testWidgets('measure a mounted plain touch message row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftInteractionScope(
            interaction: RaftInteraction.touchMode,
            child: RaftMessageTile(
              author: 'Alice',
              timestamp: '10:00',
              content: 'A plain message',
              compactSemantics: true,
              coarsePointer: true,
              onAuthor: () {},
              onActions: () {},
              onTouchTap: () {},
              body: const RaftMessageBody(
                content: 'A plain message',
                mountedMessage: true,
                compactSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
    final row = find.byType(RaftMessageRow);
    expect(find.text('A plain message'), findsOneWidget);
    debugPrint(
      'Plain touch message row elements: ${elements(tester.element(row))}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(856, 944), const Size(390, 844)]) {
    testWidgets('message chrome follows input mode at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final invocations = <String>[];
      Widget view(bool touch) => MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftInteractionScope(
            interaction: touch
                ? RaftInteraction.touchMode
                : RaftInteraction.pointerMode,
            child: RaftMessageTile(
              author: 'Alice',
              content: 'A plain message',
              timestamp: '10:00',
              compactSemantics: true,
              coarsePointer: touch,
              modelLabel: 'Model',
              subtitle: 'Model details',
              onAuthor: () => invocations.add('author'),
              onReaction: invocations.add,
              reactions: const [
                {'emoji': '👍', 'count': 1},
              ],
            ),
          ),
        ),
      );
      final row = find.byType(RaftMessageRow);
      final tooltips = find.descendant(
        of: row,
        matching: find.byType(RaftTooltip),
      );
      try {
        await tester.pumpWidget(view(false));
        expect(tooltips, findsAtLeastNWidgets(2));
        final pointer = elements(tester.element(row));
        await tester.pumpWidget(view(true));
        final touch = elements(tester.element(row));
        debugPrint(
          'Message row elements at $size: pointer=$pointer touch=$touch',
        );
        expect(tooltips, findsNothing);
        expect(
          find.descendant(
            of: row,
            matching: find.byType(RaftReactionReactorsHover),
          ),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('message-author')));
        await tester.tap(find.byKey(const ValueKey('reaction-👍')));
        expect(invocations, ['author', '👍']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('touch links and reactions are actions on one message node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final links = <String>[];
    final reactions = <String>[];
    const content = '[Open docs](https://example.com/docs) @Mona';
    Widget view(ValueChanged<String> onLink) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftInteractionScope(
          interaction: RaftInteraction.touchMode,
          child: RaftMessageTile(
            author: 'Alice',
            timestamp: '10:00',
            content: content,
            coarsePointer: true,
            compactSemantics: true,
            body: RaftMessageBody(
              content: content,
              mountedMessage: true,
              compactSemantics: true,
              onLink: onLink,
              references: const [
                RaftTextReference(
                  text: '@Mona',
                  href: 'raft-ref://mention/user/mona',
                ),
              ],
            ),
            reactions: const [
              {'emoji': '👍', 'count': 1},
            ],
            onReaction: reactions.add,
          ),
        ),
      ),
    );
    try {
      await tester.pumpWidget(view(links.add));
      final row = tester.getSemantics(find.byType(RaftMessageRow));
      final semanticsTree = row.toStringDeep();
      debugPrint(semanticsTree);
      expect(row.label, contains('Alice, 10:00'));
      expect(row.label, contains('👍: 1'));
      expect(row.childrenCount, 0, reason: semanticsTree);
      final actions = {
        for (final id in row.getSemanticsData().customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label: id,
      };
      final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
      owner.performAction(
        row.id,
        SemanticsAction.customAction,
        actions['Open docs'],
      );
      owner.performAction(
        row.id,
        SemanticsAction.customAction,
        actions['👍: 1'],
      );
      final paragraphFinder = find.descendant(
        of: find.byType(RaftMessageBody),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().startsWith('Open docs'),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
      expect(
        paragraph.text.visitChildren(
          (span) => span is! TextSpan || span.recognizer == null,
        ),
        isTrue,
      );
      final linkBox = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 9),
          )
          .single;
      final linkCenter = paragraph.localToGlobal(linkBox.toRect().center);
      await tester.tapAt(linkCenter);
      await tester.tap(find.text('@Mona'));
      await tester.pumpWidget(view((href) => links.add('updated $href')));
      await tester.tapAt(linkCenter);
      expect(links, [
        'https://example.com/docs',
        'https://example.com/docs',
        'raft-ref://mention/user/mona',
        'updated https://example.com/docs',
      ]);
      expect(reactions, ['👍']);
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }
  });
}
