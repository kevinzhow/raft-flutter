import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

int elements(Element element) {
  var count = 1;
  element.visitChildren((child) => count += elements(child));
  return count;
}

/// A compact touch row with a linked text body and one interactive slot.
RaftMessageTile touchRow(
  Widget text, {
  Widget? card,
  Widget? gallery,
  Widget? threadPreview,
  Widget? taskReference,
  Widget? savedIndicator,
  Widget? threadRepliesBadge,
  List<Map<String, dynamic>> attachments = const [],
  ValueChanged<Map<String, dynamic>>? onAttachment,
  VoidCallback? onThread,
}) => RaftMessageTile(
  author: 'Alice',
  timestamp: '10:00',
  content: 'Docs',
  coarsePointer: true,
  compactSemantics: true,
  onAuthor: () {},
  body: card == null
      ? text
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [text, card],
        ),
  attachments: gallery == null
      ? attachments
      : const [
          {'filename': 'gallery'},
        ],
  attachmentGallery: gallery,
  onAttachment: onAttachment,
  threadPreview: threadPreview,
  taskReference: taskReference,
  savedIndicator: savedIndicator,
  threadRepliesBadge: threadRepliesBadge,
  onThread: onThread,
);

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

  for (final size in [
    const Size(856, 944),
    const Size(944, 856),
    const Size(390, 844),
  ]) {
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

  // One control per row: two controls with a tap action conflict with each
  // other and would split out even while a lone control is merged.
  final longBody = [for (var i = 0; i < 30; i++) 'Paragraph $i.'].join('\n\n');
  final forwarded = {
    'kind': 'forwarded-bundle',
    'version': 1,
    'forwardedItems': [
      {
        'index': 0,
        'provenanceState': 'available',
        'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'bob'},
        'contentSnapshot': [for (var i = 0; i < 20; i++) 'Line $i'].join('\n'),
        'sourceCreatedAt': '2026-10-07T09:00:00Z',
        'sourceMessageSeq': 1,
      },
    ],
  };
  // label: the control's own node; tap: whether activating it calls back
  // (null: the control has no tap action, as on the base branch).
  final controls =
      <
        ({
          String label,
          bool? tap,
          RaftMessageTile Function(VoidCallback tap, Widget text) row,
        })
      >[
        (
          label: 'Show More',
          tap: false,
          row: (_, _) => RaftMessageTile(
            author: 'Alice',
            timestamp: '10:00',
            content: longBody,
            coarsePointer: true,
            compactSemantics: true,
            collapseLongMessages: true,
            onAuthor: () {},
            body: RaftMessageBody(
              content: longBody,
              mountedMessage: true,
              compactSemantics: true,
            ),
          ),
        ),
        (
          label: '3 replies',
          tap: true,
          row: (tap, text) => touchRow(
            text,
            threadRepliesBadge: RaftThreadRepliesBadge(
              replyCountLabel: '3 replies',
              replyCount: 3,
              onPressed: tap,
            ),
          ),
        ),
        (
          label: 'Remove from Saved',
          tap: true,
          row: (tap, text) => touchRow(
            text,
            savedIndicator: RaftMessageSavedIndicator(onPressed: tap),
          ),
        ),
        (
          label: 'Open task #7',
          tap: true,
          row: (tap, text) => touchRow(
            text,
            taskReference: RaftMountedMessageTaskChip(
              number: 7,
              status: RaftMessageTaskStatus.todo,
              title: 'Ship it',
              openLabel: 'Open task #7',
              onOpen: tap,
            ),
          ),
        ),
        (
          label: 'Open thread with 2 replies',
          tap: true,
          row: (tap, text) => touchRow(
            text,
            threadPreview: RaftInlineThreadSurface(
              replyCount: 2,
              replies: const [
                RaftInlineReply(
                  id: 'r1',
                  author: 'Bob',
                  preview: 'Sure',
                  senderType: 'user',
                ),
              ],
              summary: const Text('2 replies'),
              semanticLabel: 'Open thread with 2 replies',
              onOpen: tap,
            ),
          ),
        ),
        (
          label: 'Design Spec',
          tap: true,
          row: (tap, text) => touchRow(
            text,
            gallery: RaftCard.item(
              onTap: tap,
              child: const Text('Design Spec'),
            ),
          ),
        ),
        (
          label: 'View All 1 Message',
          tap: false,
          row: (_, text) =>
              touchRow(text, card: RaftForwardedBundle(metadata: forwarded)),
        ),
        (
          // The card's link button has no tap action on the base branch either.
          label: 'Open Dashboard · example.com',
          tap: null,
          row: (tap, text) => touchRow(
            text,
            card: RaftMessageCard(
              root: const RaftCardButton(
                label: 'Open Dashboard',
                url: 'https://example.com',
                domain: 'example.com',
              ),
              relativeTime: (_) => '',
              duration: (_, _) => '',
              onOpen: (_) => tap(),
            ),
          ),
        ),
        (
          label: 'Saved as Artifact',
          tap: true,
          row: (tap, text) => touchRow(
            text,
            gallery: RaftTextLink(label: 'Saved as Artifact', onPressed: tap),
          ),
        ),
        (
          label: 'Download to View',
          tap: true,
          row: (tap, text) => touchRow(
            text,
            gallery: RaftInlineAudio(
              filename: 'memo.m4a',
              state: RaftInlineMediaState.failed,
              onDownload: tap,
            ),
          ),
        ),
        (
          label: 'notes.txt',
          tap: true,
          row: (tap, text) => touchRow(
            text,
            attachments: const [
              {'filename': 'notes.txt'},
            ],
            onAttachment: (_) => tap(),
          ),
        ),
        (
          label: 'Reply in thread',
          tap: true,
          row: (tap, text) => touchRow(text, onThread: tap),
        ),
      ];
  for (final control in controls) {
    testWidgets('touch rows keep ${control.label} as its own node', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final tapped = <String>[];
      final row = control.row(
        () => tapped.add(control.label),
        RaftMessageBody(
          content: '[Docs](https://example.com/docs)',
          mountedMessage: true,
          compactSemantics: true,
          onLink: (_) {},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RaftInteractionScope(
                interaction: RaftInteraction.touchMode,
                child: row,
              ),
            ),
          ),
        ),
      );
      try {
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.byType(RaftMessageRow));
        final tree = node.toStringDeep();
        final nodes = <SemanticsNode>[];
        bool collect(SemanticsNode child) {
          nodes.add(child);
          child.visitChildren(collect);
          return true;
        }

        node.visitChildren(collect);
        // The text still reads as the row; the control is a node below it.
        final rowData = node.getSemanticsData();
        expect(rowData.label, contains('Alice, 10:00'), reason: tree);
        expect(rowData.label, isNot(contains(control.label)), reason: tree);
        expect(rowData.hasAction(SemanticsAction.tap), isFalse, reason: tree);
        expect(
          [
            for (final id in rowData.customSemanticsActionIds!)
              CustomSemanticsAction.getAction(id)!.label,
          ],
          control.label == 'Show More'
              ? ['Mention Alice']
              : ['Mention Alice', 'Docs'],
          reason: tree,
        );
        final own = nodes.where(
          (n) => n.getSemanticsData().label.startsWith(control.label),
        );
        expect(own, hasLength(1), reason: tree);
        final data = own.single.getSemanticsData();
        if (control.tap == null) return;
        expect(data.hasAction(SemanticsAction.tap), isTrue, reason: tree);
        tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
          own.single.id,
          SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        // Show More and the bundle toggle expand in place.
        if (control.tap!) {
          expect(tapped, [control.label]);
        } else {
          expect(
            find.byWidgetPredicate(
              (w) => w is RaftShowMoreToggle && w.label == 'Collapse',
            ),
            findsOneWidget,
          );
        }
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
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

  group('touch row link actions', () {
    late List<String> calls;
    Widget view(String content, {bool collapse = false}) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RaftInteractionScope(
            interaction: RaftInteraction.touchMode,
            child: RaftMessageTile(
              author: 'Alice',
              timestamp: '10:00',
              content: content,
              coarsePointer: true,
              compactSemantics: true,
              collapseLongMessages: collapse,
              onAuthor: () => calls.add('author'),
              semanticsActions: [
                RaftMessageSemanticsAction('Save', (_) => calls.add('save')),
              ],
              body: RaftMessageBody(
                content: content,
                mountedMessage: true,
                compactSemantics: true,
                onLink: calls.add,
              ),
            ),
          ),
        ),
      ),
    );
    Map<String, int> actions(WidgetTester tester) {
      final row = tester.getSemantics(find.byType(RaftMessageRow));
      return {
        for (final id in row.getSemanticsData().customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label!: id,
      };
    }

    void invoke(WidgetTester tester, String label) {
      final row = tester.getSemantics(find.byType(RaftMessageRow));
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        row.id,
        SemanticsAction.customAction,
        actions(tester)[label],
      );
    }

    setUp(() => calls = []);

    testWidgets('a link named like a row action does not replace it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          view(
            'Click [Mention Alice](https://evil.example.com) or '
            '[Save](https://evil2.example.com)',
          ),
        );
        expect(
          actions(tester).keys,
          unorderedEquals([
            'Save',
            'Mention Alice',
            'Mention Alice, https://evil.example.com',
            'Save, https://evil2.example.com',
          ]),
        );
        for (final label in actions(tester).keys) {
          invoke(tester, label);
        }
        expect(
          calls,
          unorderedEquals([
            'save',
            'author',
            'https://evil.example.com',
            'https://evil2.example.com',
          ]),
        );
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('same-named links in separate prose chunks both stay', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          view(
            'See [Docs](https://a.example.com)\n\n'
            '```dart\nvoid main() {}\n```\n\n'
            'And [Docs](https://b.example.com)',
          ),
        );
        expect(
          actions(tester).keys,
          containsAll([
            'Docs, https://a.example.com',
            'Docs, https://b.example.com',
          ]),
        );
        invoke(tester, 'Docs, https://a.example.com');
        invoke(tester, 'Docs, https://b.example.com');
        expect(calls, ['https://a.example.com', 'https://b.example.com']);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a collapsed row hides the links of hidden paragraphs', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          view(
            [
              '[TopLink](https://example.com/top)',
              for (var i = 1; i < 29; i++) 'Paragraph $i.',
              '[HiddenLink](https://example.com/hidden)',
            ].join('\n\n'),
            collapse: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(actions(tester).keys, isNot(contains('HiddenLink')));
        final toggle = <SemanticsNode>[];
        tester.getSemantics(find.byType(RaftMessageRow)).visitChildren((n) {
          if (n.label == 'Show More') toggle.add(n);
          return true;
        });
        tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
          toggle.single.id,
          SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(actions(tester).keys, containsAll(['TopLink', 'HiddenLink']));
        invoke(tester, 'HiddenLink');
        expect(calls, ['https://example.com/hidden']);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
