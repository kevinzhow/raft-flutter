import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/theme.dart';
import 'package:raft_ui/src/thread_composition.dart';

Widget _host(double scale, Widget child, {double width = 300}) => MaterialApp(
  theme: raftTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      devicePixelRatio: 1,
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

Widget _row({String author = 'Public Agent', bool continuation = false}) =>
    RaftMessageRow(
      author: author,
      timestamp: '14:30',
      continuation: continuation,
      avatar: const ColoredBox(color: Colors.blue),
      content: const Text('Body'),
    );

void main() {
  const longAuthor = 'A very long public author name that cannot fit';

  testWidgets('message header stays on one line at the default text size', (
    tester,
  ) async {
    await tester.pumpWidget(_host(1, _row()));
    final author = tester.getRect(find.text('Public Agent'));
    final time = tester.getRect(find.text('14:30'));
    expect(time.left, greaterThan(author.right));
    expect(time.top, lessThan(author.bottom));
  });

  testWidgets('message header wraps name and time at 2.0x instead of clipping', (
    tester,
  ) async {
    await tester.pumpWidget(_host(2, _row(author: longAuthor)));
    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byType(RaftMessageRow));
    final author = tester.getRect(find.text(longAuthor));
    final time = tester.getRect(find.text('14:30'));
    // The whole name is shown (wrapped), the time sits below it, and both stay
    // inside the row.
    expect(find.text(longAuthor), findsOneWidget);
    expect(time.top, greaterThanOrEqualTo(author.bottom - 1));
    expect(author.right, lessThanOrEqualTo(row.right));
    expect(time.right, lessThanOrEqualTo(row.right));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(longAuthor),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThan(40));
  });

  testWidgets('time moves under a short name that no longer fits at 3.1x', (
    tester,
  ) async {
    await tester.pumpWidget(_host(3.1, _row(), width: 260));
    expect(tester.takeException(), isNull);
    final author = tester.getRect(find.text('Public Agent'));
    final time = tester.getRect(find.text('14:30'));
    expect(time.top, greaterThanOrEqualTo(author.bottom - 1));
    expect(time.left, author.left);
  });

  testWidgets('the continuation hover time stays inside its gutter box', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0, 3.1]) {
      await tester.pumpWidget(_host(scale, _row(continuation: true)));
      final gutter = tester.getRect(
        find
            .ancestor(of: find.text('14:30'), matching: find.byType(SizedBox))
            .first,
      );
      final time = tester.getRect(find.text('14:30'));
      expect(time.bottom, lessThanOrEqualTo(gutter.bottom + 0.01));
      if (scale == 1) expect(gutter.height, 14);
    }
  });

  testWidgets('thread header wraps its title and grows at 2.0x', (
    tester,
  ) async {
    Widget header() => RaftThreadHeader(
      presentation: RaftThreadPresentation.side,
      viewportWidth: 300,
      viewportHeight: 560,
      threadLabel: 'Thread',
      parentLabel: '#design-review-channel',
      jumpLabel: 'Jump',
      backLabel: 'Back',
      closeLabel: 'Close',
      onBack: () {},
    );
    await tester.pumpWidget(_host(1, header()));
    final base = tester.getSize(find.byType(RaftThreadHeader));
    await tester.pumpWidget(_host(2, header()));
    expect(tester.takeException(), isNull);
    final scaled = tester.getSize(find.byType(RaftThreadHeader));
    expect(scaled.height, greaterThan(base.height));
    final title = tester.renderObject<RenderParagraph>(
      find.textContaining('Thread', findRichText: true),
    );
    expect(title.didExceedMaxLines, isFalse);
  });
}
