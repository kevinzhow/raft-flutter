import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// First-line alphabetic baseline: the underline's anchor (Web
/// `underline-offset-2`), whatever the font or line box.
double _baseline(RenderParagraph p) =>
    // ignore: invalid_use_of_protected_member
    p.computeDistanceToActualBaseline(TextBaseline.alphabetic);

const _href = 'https://example.invalid/manual';
const _label = 'Quest Machine 官方手册';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'mixed link has one detached underline ${dark ? 'dark' : 'light'}/$scale',
        (tester) async {
          final key = GlobalKey();
          final tapped = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: RepaintBoundary(
                      key: key,
                      child: SizedBox(
                        width: 700,
                        child: RaftMessageBody(
                          content: '[$_label]($_href); ordinary',
                          onLink: tapped.add,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final rich = find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().startsWith(_label),
          );
          final paragraph = tester.renderObject<RenderParagraph>(rich);
          final span = tester.widget<RichText>(rich).text;
          span.visitChildren((s) {
            if (s is TextSpan && s.recognizer is MessageLinkRecognizer) {
              expect(s.style!.decoration, TextDecoration.none);
            }
            return true;
          });
          final bounds = paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: _label.length),
            boxHeightStyle: ui.BoxHeightStyle.strut,
          );
          expect(bounds.map((b) => b.top).toSet(), hasLength(1));
          final left = bounds
              .map((b) => b.left)
              .reduce((a, b) => a < b ? a : b);
          final right = bounds
              .map((b) => b.right)
              .reduce((a, b) => a > b ? a : b);
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final origin = paragraph.localToGlobal(
            Offset.zero,
            ancestor: boundary,
          );
          // Check painted pixels, not just a style flag: a continuous stroke lies
          // below the common baseline across both scripts, exactly 2 scaled px.
          final image = (await tester.runAsync(() => boundary.toImage()))!;
          final bytes = (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!;
          final color = dark
              ? const Color(0xff8ec5ff)
              : const Color(0xff1447e6);
          final strokeTop = (origin.dy + _baseline(paragraph) + 2 * scale)
              .roundToDouble();
          for (
            var y = strokeTop.ceil();
            y < (strokeTop + 2 * scale).floor();
            y++
          ) {
            for (
              var x = (origin.dx + left).ceil() + 1;
              x < (origin.dx + right).floor() - 1;
              x++
            ) {
              final pixel = (y * image.width + x) * 4;

              expect(bytes.getUint8(pixel), (color.r * 255).round());
              expect(bytes.getUint8(pixel + 1), (color.g * 255).round());
              expect(bytes.getUint8(pixel + 2), (color.b * 255).round());
            }
          }
          image.dispose();
          await tester.tapAt(
            paragraph.localToGlobal(
              Offset(
                (left + right) / 2,
                (bounds.first.top + bounds.first.bottom) / 2,
              ),
            ),
          );
          expect(tapped, [_href]);
          expect(paragraph.text.toPlainText(), '$_label; ordinary');
          expect(find.byType(SelectionArea), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('wrapped links retain selection and independent tap targets', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: RaftMessageBody(
              content:
                  '[$_label — 更多说明]($_href) [Smart Variables](https://example.invalid/variables)',
              onLink: tapped.add,
            ),
          ),
        ),
      ),
    );
    final rich = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().startsWith(_label),
    );
    final paragraph = tester.renderObject<RenderParagraph>(rich);
    final text = paragraph.text.toPlainText();
    final first = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.indexOf(' Smart')),
    );
    expect(first.map((b) => b.top).toSet().length, greaterThan(1));
    final second = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: text.indexOf('Smart'),
        extentOffset: text.length,
      ),
    );
    await tester.tapAt(paragraph.localToGlobal(first.first.toRect().center));
    await tester.tapAt(paragraph.localToGlobal(second.last.toRect().center));
    expect(tapped, [_href, 'https://example.invalid/variables']);
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('font changes do not move the link underline', (tester) async {
    final key = GlobalKey();
    await tester.runAsync(() async {
      for (final (name, asset) in [
        ('UnderlineLatin', 'HankenGrotesk.ttf'),
        ('UnderlineFallback', 'LiberationSans-Regular.ttf'),
      ]) {
        ByteData data;
        try {
          data = await rootBundle.load('packages/raft_ui/assets/fonts/$asset');
        } on FlutterError {
          data = await rootBundle.load('assets/fonts/$asset');
        }
        await (FontLoader(name)..addFont(Future.value(data))).load();
      }
    });
    const blue = Color(0xff1447e6);
    const base = TextStyle(
      fontFamily: 'UnderlineLatin',
      fontSize: 20,
      height: 1.5,
    );
    final firstRecognizer = MessageLinkRecognizer();
    final secondRecognizer = MessageLinkRecognizer();
    addTearDown(firstRecognizer.dispose);
    addTearDown(secondRecognizer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: RaftUnderlines(
              child: Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    TextSpan(
                      text: 'Quest Machine ',
                      recognizer: firstRecognizer,
                      style: TextStyle(color: blue, fontSize: 20),
                    ),
                    TextSpan(
                      text: '官方手册 fallback',
                      recognizer: secondRecognizer,
                      style: TextStyle(
                        color: blue,
                        fontFamily: 'UnderlineFallback',
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                strutStyle: StrutStyle(
                  fontFamily: 'UnderlineLatin',
                  fontSize: 20,
                  height: 1.5,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final rich = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().startsWith('Quest Machine'),
    );
    final paragraph = tester.renderObject<RenderParagraph>(rich);
    final bounds = paragraph.getBoxesForSelection(
      const TextSelection(
        baseOffset: 0,
        extentOffset: 'Quest Machine 官方手册 fallback'.length,
      ),
      boxHeightStyle: ui.BoxHeightStyle.strut,
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final origin = paragraph.localToGlobal(Offset.zero, ancestor: boundary);
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    for (final box in bounds) {
      final y = (origin.dy + _baseline(paragraph) + 3).round();
      for (
        var x = (origin.dx + box.left).ceil() + 1;
        x < (origin.dx + box.right).floor() - 1;
        x++
      ) {
        final pixel = (y * image.width + x) * 4;
        expect(
          [for (var c = 0; c < 4; c++) bytes.getUint8(pixel + c)],
          [20, 71, 230, 255],
        );
      }
    }
    image.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ordinary prose skips decoration and repaint reuses link geometry',
    (tester) async {
      Widget host(String content, double width) => MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: RaftMessageBody(content: content),
          ),
        ),
      );
      await tester.pumpWidget(host('Ordinary 中文 prose', 320));
      expect(find.byType(RaftUnderlines), findsNothing);
      await tester.pumpWidget(host('[$_label]($_href)', 320));
      final dynamic render = tester.renderObject(find.byType(RaftUnderlines));
      expect(render.debugGeometryBuildCount, 1);
      for (var i = 0; i < 8; i++) {
        render.markNeedsPaint();
        await tester.pump();
      }
      expect(render.debugGeometryBuildCount, 1);
      await tester.pumpWidget(host('[$_label]($_href)', 160));
      expect(render.debugGeometryBuildCount, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'table underline stays clipped and follows horizontal scrolling',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 140,
                      child: RaftMessageBody(
                        content: '| Link | Wide column |\n|---|---|\n| [Quest Machine 官方手册](https://example.invalid/manual) | ALongUnbrokenColumnThatRequiresHorizontalScrolling |',
                      ),
                    ),
                    const SizedBox(width: 160, height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final rich = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith(_label),
      );
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final y =
          (paragraph.localToGlobal(Offset.zero, ancestor: boundary).dy +
                  _baseline(paragraph) +
                  3)
              .round();
      Future<int> bluePixels(int left, int right) async {
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        var count = 0;
        for (var x = left; x < right; x++) {
          final p = (y * image.width + x) * 4;
          if (bytes.getUint8(p) == 20 &&
              bytes.getUint8(p + 1) == 71 &&
              bytes.getUint8(p + 2) == 230)
            count++;
        }
        image.dispose();
        return count;
      }

      expect(await bluePixels(0, 140), greaterThan(20));
      expect(await bluePixels(142, 298), 0);
      final dynamic render = tester.renderObject(find.byType(RaftUnderlines));
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(await bluePixels(0, 140), 0);
      expect(render.debugGeometryBuildCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
