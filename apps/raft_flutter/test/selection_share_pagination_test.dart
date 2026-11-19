import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_image_export.dart';
import 'package:raft_flutter/features/message_selection.dart';
import 'package:raft_flutter/features/screenshot_budget.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  test('three pages preserve order and split only oversized rows', () {
    final pages = planScreenshotBands(
      width: 700,
      rowHeights: [1800, 5000, 1200],
      preferredRatio: 2,
    );
    expect(pages.map((p) => p.top), [0, 1800, 5896, 6800]);
    expect(pages.map((p) => p.height), [1800, 4096, 904, 1200]);

    final three = planScreenshotBands(
      width: 700,
      rowHeights: [3000, 3000, 3000],
      preferredRatio: 2,
    );
    expect(three.map((p) => (p.top, p.height)), [
      (0, 3000),
      (3000, 3000),
      (6000, 3000),
    ]);
    expect(three.every((p) => p.pixelRatio == 2), isTrue);
  });

  test('selection Markdown sorts chat order and uses Web thread syntax', () {
    SelectedMessageRow row(
      String name,
      int seq,
      String text, {
      bool reply = false,
    }) => SelectedMessageRow(
      RaftMessage({
        'id': '$seq',
        'senderName': name,
        'seq': seq,
        'content': text,
      }),
      parentId: reply ? '1' : null,
    );
    expect(
      selectedMessagesMarkdown([
        row('Bob', 2, '  `raw` reply  ', reply: true),
        row('Ada', 1, ' **root** '),
      ]),
      '**Ada**: **root**\n\n  ↳ **Bob**: `raw` reply',
    );
  });

  testWidgets('a long real timeline export opens three ordered PNG pages', (
    tester,
  ) async {
    final (w, _) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    final rows = [
      for (var n = 0; n < 3; n++)
        {
          'id': 'long-$n',
          'channelId': 'c1',
          'seq': n + 1,
          'senderName': 'Author',
          'content': List.filled(85, 'Page ${n + 1} line').join('\n\n'),
        },
    ];
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest(
      rows,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {'long-0', 'long-1', 'long-2'};
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => previewMessageImage(
                context,
                w,
                messages: w.messageDomain.messages
                    .map(SelectedMessageRow.new)
                    .toList(),
                width: 480,
              ),
              child: const Text('Capture'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Capture'));
    for (
      var i = 0;
      i < 150 && find.byType(MessageImageReview).evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    final review = tester.widget<MessageImageReview>(
      find.byType(MessageImageReview),
    );
    expect(review.pages, hasLength(3));
    for (final png in review.pages) {
      validateScreenshotPng(png);
    }
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Close Preview'));
    await tester.pumpAndSettle();
  });
}
