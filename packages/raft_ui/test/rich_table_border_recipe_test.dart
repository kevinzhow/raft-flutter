import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_content_tokens.dart';
import 'package:raft_ui/src/message_table_border.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'collapsed outer stroke extends half a stroke without moving internal grid',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      MessageCollapsedTableBorder(color: Colors.black, width: 1).paint(
        canvas,
        const Rect.fromLTWH(10, 10, 40, 40),
        rows: [20],
        columns: [20],
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(60, 60);
      try {
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(bytes, isNotNull);
        int alpha(int x, int y) => bytes!.getUint8((y * 60 + x) * 4 + 3);
        expect(alpha(9, 20), greaterThan(0)); // Outside half of outer stroke.
        expect(alpha(8, 20), 0);
        expect(alpha(11, 20), 0);
        expect(alpha(30, 20), greaterThan(0)); // Internal column stays at x30.
        expect(alpha(28, 20), 0);
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
  );

  for (final dark in [false, true]) {
    for (final rows in [1, 3]) {
      testWidgets(
        'uniform Elegant collapsed strokes allocate layout for $rows rows/$dark',
        (tester) async {
          final source =
              'Before paragraph\n\nAfter paragraph\n\n| Status | Count |\n|---|---|\n${List.generate(rows, (i) => '|Value $i|${i + 1}|').join('\n')}';
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(RaftFamily.elegant, dark: dark),
              home: Scaffold(body: RaftMessageBody(content: source)),
            ),
          );
          final before = tester.getRect(
            find.text('Before paragraph', findRichText: true),
          );
          final after = tester.getRect(
            find.text('After paragraph', findRichText: true),
          );
          expect(after.top - before.bottom, closeTo(4, .1));
          final markdown = tester.widget<MarkdownBody>(
            find.byType(MarkdownBody),
          );
          final sheet = markdown.styleSheet!;
          expect(sheet.blockSpacing, 4); // Ordinary paragraph/heading contract.
          expect(
            sheet.tableCellsPadding,
            const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4.5),
          );
          expect(sheet.tableHeadCellsPadding, sheet.tableCellsPadding);
          expect(
            sheet.tablePadding,
            const EdgeInsets.symmetric(horizontal: .5, vertical: 4.5),
          );
          final table = tester.widget<Table>(find.byType(Table));
          expect(table.defaultColumnWidth, isA<IntrinsicColumnWidth>());
          expect(table.border, isA<MessageCollapsedTableBorder>());
          expect(table.children.length, rows + 1);
          // All cells stay intrinsic: size follows actual cell content, padding,
          // and allocated shared strokes rather than a fixture's fixed width.
          final firstRow = table.children.first;
          var expectedWidth = 0.0;
          for (var column = 0; column < firstRow.children.length; column++) {
            final cells = [
              for (final row in table.children) row.children[column],
            ];
            var maxWidth = 0.0;
            for (final cell in cells) {
              final box = tester.renderObject<RenderBox>(find.byWidget(cell));
              final intrinsic = box.getMaxIntrinsicWidth(double.infinity);
              if (intrinsic > maxWidth) maxWidth = intrinsic;
            }
            expectedWidth += maxWidth;
          }
          expect(
            tester.getSize(find.byType(Table)).width,
            closeTo(expectedWidth, .1),
          );
          final scroll = tester.widget<SingleChildScrollView>(
            find.byType(SingleChildScrollView),
          );
          expect(scroll.padding, sheet.tablePadding);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Brutal mixed-stroke table remains explicit pending renderer without global gap change',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: const Scaffold(
            body: RaftMessageBody(
              content: '| Status | Count |\n|---|---|\n|Ready|3|',
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(RaftMessageBody));
      final recipe = MessageContentRecipe(RaftTokens.of(context));
      expect(recipe.collapsedTableHalfStroke, 0);
      expect(recipe.tableCellInset, MessageContentPrimitive.tableInset);
      expect(recipe.stylesheet(context).blockSpacing, 4);
      expect(tester.takeException(), isNull);
    },
  );
}
