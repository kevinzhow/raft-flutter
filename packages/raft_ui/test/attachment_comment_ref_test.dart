// Web AttachmentCommentRefChip and the card's comment count.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool zh = false}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: Locale(zh ? 'zh' : 'en'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(RaftFamily.elegant)
            .copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );

void main() {
  group('RaftAttachmentCommentRef', () {
    testWidgets('reads "re: filename · anchor" and jumps when resolved', (
      tester,
    ) async {
      var jumps = 0;
      await _pump(
        tester,
        RaftAttachmentCommentRef(
          filename: 'report.csv',
          anchorLabel: 'Row 3',
          onJump: () => jumps++,
        ),
      );
      expect(find.text('re: report.csv · Row 3'), findsOneWidget);
      await tester.tap(find.text('re: report.csv · Row 3'));
      expect(jumps, 1);
    });

    testWidgets(
      'without an anchor it names the file only; unresolved it is inert',
      (tester) async {
        await _pump(
          tester,
          const RaftAttachmentCommentRef(filename: 'notes.md'),
        );
        expect(find.text('re: notes.md'), findsOneWidget);
        expect(
          find.byType(GestureDetector).evaluate().where((e) {
            final w = e.widget as GestureDetector;
            return w.onTap != null;
          }),
          isEmpty,
        );
      },
    );

    testWidgets('the anchor quote follows in its own block', (tester) async {
      await _pump(
        tester,
        const RaftAttachmentCommentRef(
          filename: 'a.txt',
          anchorLabel: 'L2',
          anchorQuote: 'the quoted line',
        ),
      );
      expect(find.text('the quoted line'), findsOneWidget);
    });

    testWidgets('Chinese follows the Web catalog', (tester) async {
      await _pump(
        tester,
        RaftAttachmentCommentRef(
          filename: 'a.txt',
          anchorLabel: 'L2',
          onJump: () {},
        ),
        zh: true,
      );
      expect(find.text('回复：a.txt · L2'), findsOneWidget);
    });
  });

  group('RaftAttachmentCard comment count', () {
    Future<void> card(WidgetTester tester, String mime, int count) => _pump(
      tester,
      SizedBox(
        width: 220,
        child: RaftAttachmentCard(
          filename: 'x',
          mimeType: mime,
          metaLabel: 'meta',
          sizeBytes: 2048,
          commentCount: count,
          onOpen: () {},
        ),
      ),
    );

    testWidgets('shows the number after the size, with the comment glyph', (
      tester,
    ) async {
      await card(tester, 'text/csv', 3);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
    });

    testWidgets('no count for none, images or PDFs', (tester) async {
      await card(tester, 'text/csv', 0);
      expect(find.text('0'), findsNothing);
      await card(tester, 'application/pdf', 3);
      expect(find.text('3'), findsNothing);
      await card(tester, 'image/png', 3);
      expect(find.text('3'), findsNothing);
    });
  });
}
