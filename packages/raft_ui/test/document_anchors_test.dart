// Web attachmentCommentAnchors: the lines of a text preview and the rows of a
// CSV / XLSX preview are numbered; in comment mode a tap or a drag over them
// becomes the pending anchor, and a comment's anchor scrolls to its rows and
// flashes them.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<RaftAttachmentCommentState> _pump(
  WidgetTester tester,
  Map<String, dynamic> data, {
  bool commentMode = true,
  double width = 900,
  double height = 700,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = RaftAttachmentCommentState()..commentMode = commentMode;
  addTearDown(state.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: RaftAttachmentCommentScope(
          state: state,
          child: RaftDocumentPreview(data: data),
        ),
      ),
    ),
  );
  await tester.pump();
  return state;
}

Map<String, dynamic> _text(int lines) => {
  'kind': 'text',
  'text': [for (var i = 1; i <= lines; i++) 'line $i text'].join('\n'),
};

Map<String, dynamic> _csv(int rows) => {
  'kind': 'csv',
  'headers': ['id', 'name'],
  'rows': [
    for (var i = 1; i <= rows; i++) ['$i', 'name $i'],
  ],
  'rowCount': rows,
  'columnCount': 2,
};

Future<void> _tap(WidgetTester tester, Finder at) async {
  final gesture = await tester.startGesture(
    tester.getCenter(at),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> _drag(WidgetTester tester, Finder from, Finder to) async {
  final gesture = await tester.startGesture(
    tester.getCenter(from),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.moveBy(const Offset(0, 12));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Map<String, dynamic> _data(RaftAttachmentCommentState state) =>
    Map<String, dynamic>.from(state.pendingAnchor!['data'] as Map);

void main() {
  group('text lines', () {
    testWidgets('a tap anchors the line with its text as the quote', (
      tester,
    ) async {
      final state = await _pump(tester, _text(8));
      await _tap(tester, find.text('line 3 text'));
      expect(state.pendingAnchor!['type'], 'lines');
      expect(_data(state), {'start': 3, 'end': 3, 'quote': 'line 3 text'});
    });

    testWidgets('a drag over lines anchors the range, either direction', (
      tester,
    ) async {
      final state = await _pump(tester, _text(8));
      await _drag(tester, find.text('line 6 text'), find.text('line 4 text'));
      expect(_data(state)['start'], 4);
      expect(_data(state)['end'], 6);
      expect(_data(state)['quote'], 'line 4 text\nline 5 text\nline 6 text');
    });

    testWidgets('a pushed anchor opens the panel through the session', (
      tester,
    ) async {
      final state = await _pump(tester, _text(4));
      var opened = 0;
      state.openPanel = () => opened++;
      await _tap(tester, find.text('line 2 text'));
      expect(opened, 1);
    });

    testWidgets('outside comment mode nothing is captured', (tester) async {
      final state = await _pump(tester, _text(8), commentMode: false);
      await _tap(tester, find.byType(SelectableText));
      expect(state.pendingAnchor, isNull);
    });

    testWidgets(
      'the pending rows are tinted, and the tint ends with the anchor',
      (tester) async {
        final state = await _pump(tester, _text(6));
        await _tap(tester, find.text('line 2 text'));
        Finder tinted(String text) => find.ancestor(
          of: find.text(text),
          matching: find.byType(ColoredBox),
        );
        final before = tester
            .widgetList<ColoredBox>(tinted('line 2 text'))
            .length;
        state.clearAnchor();
        await tester.pump();
        final after = tester
            .widgetList<ColoredBox>(tinted('line 2 text'))
            .length;
        expect(before, after + 1);
      },
    );

    testWidgets('a long text still shows each line as a row', (tester) async {
      final state = await _pump(tester, _text(2500));
      expect(find.byKey(const ValueKey('lazy-text-lines')), findsOneWidget);
      await _tap(tester, find.text('line 3 text'));
      expect(_data(state)['start'], 3);
    });
  });

  group('CSV rows', () {
    testWidgets('a tap anchors the row', (tester) async {
      final state = await _pump(tester, _csv(5));
      await _tap(tester, find.text('name 4'));
      expect(state.pendingAnchor!['type'], 'csv-rows');
      expect(_data(state)['start'], 4);
      expect(_data(state)['end'], 4);
      expect(_data(state)['quote'], '4\tname 4');
    });

    testWidgets('a drag over cells of two rows anchors both', (tester) async {
      final state = await _pump(tester, _csv(5));
      await _drag(tester, find.text('name 2'), find.text('name 4'));
      expect(_data(state)['start'], 2);
      expect(_data(state)['end'], 4);
    });

    testWidgets('a long CSV anchors its rows too', (tester) async {
      final state = await _pump(tester, _csv(300));
      expect(find.byKey(const ValueKey('lazy-csv-rows')), findsOneWidget);
      await _tap(tester, find.text('name 5'));
      expect(_data(state)['start'], 5);
    });
  });

  group('jumping to an anchor', () {
    testWidgets('scrolls a text line into view and flashes it', (tester) async {
      final state = await _pump(tester, _text(2500));
      expect(find.text('line 1200 text'), findsNothing);
      final found = state.jump({
        'type': 'lines',
        'data': {'start': 1200, 'end': 1202},
      });
      expect(found, isTrue);
      Finder tint() => find.ancestor(
        of: find.text('line 1201 text'),
        matching: find.byType(ColoredBox),
      );
      // The row is built, centred, then flashes (1.6 s) and the tint fades.
      var peak = 0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('line 1201 text').evaluate().isNotEmpty) {
          final count = tester.widgetList<ColoredBox>(tint()).length;
          if (count > peak) peak = count;
        }
      }
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('line 1200 text'), findsOneWidget);
      expect(
        tester.getCenter(find.text('line 1200 text')).dy,
        inInclusiveRange(150, 600),
      );
      expect(tester.widgetList<ColoredBox>(tint()).length, lessThan(peak));
    });

    testWidgets('scrolls a CSV row into view', (tester) async {
      final state = await _pump(tester, _csv(600));
      expect(
        state.jump({
          'type': 'csv-rows',
          'data': {'start': 450},
        }),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('name 450'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a short text and a table scroll into view too', (
      tester,
    ) async {
      final state = await _pump(tester, _text(60), height: 300);
      expect(
        state.jump({
          'type': 'lines',
          'data': {'start': 55},
        }),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.getCenter(find.text('line 55 text')).dy,
        inInclusiveRange(0, 300),
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('an anchor past the end of a cut preview is a miss', (
      tester,
    ) async {
      final state = await _pump(tester, _text(10));
      expect(
        state.jump({
          'type': 'lines',
          'data': {'start': 11},
        }),
        isFalse,
      );
      expect(
        state.jump({
          'type': 'csv-rows',
          'data': {'start': 1},
        }),
        isFalse,
      );
      expect(
        state.jump({
          'type': 'html-region',
          'data': {'x': 1},
        }),
        isFalse,
      );
      expect(
        state.jump({
          'type': 'lines',
          'data': {'start': 'x'},
        }),
        isFalse,
      );
    });
  });

  group('quotes', () {
    test('are trimmed, capped at 400 characters, and null when blank', () {
      expect(raftCommentQuote('   '), isNull);
      expect(raftCommentQuote('  hi  '), 'hi');
      final long = raftCommentQuote('x' * 500)!;
      expect(long.length, 401);
      expect(long.endsWith('…'), isTrue);
    });
  });
}
