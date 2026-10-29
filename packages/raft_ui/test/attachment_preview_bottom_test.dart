import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// The collapsed comments bar of a document preview on a phone, through the
// real routes (the native page and the full-bleed dialog) with a gesture-bar
// inset: the content scrolls clear of the bar, and the bar paints opaquely to
// the screen bottom (nothing of the dimmed page shows under it).
const _size = Size(390, 844);
const _inset = 34.0;
const _lastKey = ValueKey('document-last-line');

Future<GlobalKey> _pumpHome(
  WidgetTester tester,
  double scale, {
  Size size = _size,
  double inset = _inset,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => RepaintBoundary(
        key: boundary,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: EdgeInsets.only(top: 24, bottom: inset),
            viewPadding: EdgeInsets.only(top: 24, bottom: inset),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
      // Something conspicuous behind the route, to show through if the route
      // leaves any part of the screen uncovered.
      home: const ColoredBox(
        color: Color(0xFFFF00FF),
        child: SizedBox.expand(),
      ),
    ),
  );
  return boundary;
}

/// A scrolling "document" (what every kind's body is) and the comments bar.
Widget _shell({required bool page, required Widget child}) =>
    RaftAttachmentPreviewShell(
      page: page,
      filename: 'review.md',
      onClose: () {},
      canvas: true,
      commentsBuilder: (_, sheet) => RaftAttachmentCommentsPanel(
        filename: 'review.md',
        comments: const [],
        composer: const SizedBox(),
        sheet: sheet,
        collapsedBody: !sheet!.expanded,
      ),
      child: child,
    );

Widget _document(ScrollController controller) => SingleChildScrollView(
  controller: controller,
  child: Column(
    children: [
      for (var i = 0; i < 60; i++) SizedBox(height: 40, child: Text('line $i')),
      const SizedBox(key: _lastKey, height: 40, child: Text('last line')),
    ],
  ),
);

Future<void> _push(
  WidgetTester tester,
  bool page,
  Widget Function() shell,
) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(
    page
        ? RaftPreviewPageRoute<void>(builder: (_) => Scaffold(body: shell()))
        : RaftFullBleedDialogRoute<void>(
            context: tester.element(find.byType(ColoredBox).first),
            builder: (_) => shell(),
          ),
  );
  await tester.pumpAndSettle();
}

Future<Color> _pixel(WidgetTester tester, GlobalKey boundary, Offset at) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final i = (at.dy.toInt() * image.width + at.dx.toInt()) * 4;
  final color = Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
  image.dispose();
  return color;
}

void main() {
  for (final page in [true, false]) {
    for (final scale in [1.0, 2.0]) {
      final name = '${page ? 'page' : 'dialog'} ${scale}x: collapsed bar';
      testWidgets('$name: the end of the content stays above it', (
        tester,
      ) async {
        await _pumpHome(tester, scale);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await _push(
          tester,
          page,
          () => _shell(page: page, child: _document(controller)),
        );
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        final sheet = tester.getRect(
          find.byKey(const ValueKey('attachment-comments-sheet')),
        );
        final last = tester.getRect(find.byKey(_lastKey));
        expect(last.bottom, lessThanOrEqualTo(sheet.top));
        // The last line is fully on screen, right above the bar.
        expect(last.top, greaterThan(0));
        expect(sheet.top - last.bottom, lessThan(1));
      });

      testWidgets('$name: is opaque down to the screen bottom', (tester) async {
        final boundary = await _pumpHome(tester, scale);
        await _push(
          tester,
          page,
          () => _shell(page: page, child: const Text('body')),
        );
        final sheet = tester.getRect(
          find.byKey(const ValueKey('attachment-comments-sheet')),
        );
        expect(sheet.bottom, _size.height);
        expect(sheet.left, 0);
        expect(sheet.right, _size.width);
        // The header row sits fully above the system bar.
        expect(
          tester
              .getRect(
                find.byKey(const ValueKey('attachment-comments-sheet-toggle')),
              )
              .bottom,
          lessThanOrEqualTo(_size.height - _inset),
        );
        // And what is painted there is the sheet's own surface: not the
        // dimmed page behind a dialog, not the magenta home.
        final t = RaftTokens.of(
          tester.element(find.byType(RaftAttachmentPreviewShell)),
        );
        final surface = t.panel;
        for (final y in [_size.height - 2, _size.height - _inset / 2]) {
          final color = await _pixel(tester, boundary, Offset(60, y));
          expect(color.a, 1.0, reason: 'opaque at y=$y');
          expect(
            (color.r - surface.r).abs() +
                (color.g - surface.g).abs() +
                (color.b - surface.b).abs(),
            lessThan(.01),
            reason: 'the sheet surface at y=$y, got $color',
          );
        }
      });
    }
  }

  testWidgets('open sheet stays an overlay: the body does not move', (
    tester,
  ) async {
    await _pumpHome(tester, 1);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _push(
      tester,
      true,
      () => _shell(page: true, child: _document(controller)),
    );
    final before = tester.getRect(find.text('line 5'));
    await tester.tap(
      find.byKey(const ValueKey('attachment-comments-sheet-toggle')),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('line 5')), before);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('attachment-comments-sheet')))
          .height,
      _size.height * .45,
    );
  });

  testWidgets('no comments: the content clears the system bar', (tester) async {
    await _pumpHome(tester, 1);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _push(
      tester,
      false,
      () => RaftAttachmentPreviewShell(
        page: false,
        filename: 'notes.txt',
        onClose: () {},
        child: _document(controller),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(_lastKey)).bottom,
      lessThanOrEqualTo(_size.height - _inset),
    );
  });

  // Audio is centred while the card fits and scrolls when it does not.
  testWidgets('audio: centred when it fits', (tester) async {
    await _pumpHome(tester, 1);
    await _push(
      tester,
      true,
      () => _shell(
        page: true,
        child: const RaftAudioPreview(filename: 'voice.mp3'),
      ),
    );
    final viewport = tester.getRect(
      find.descendant(
        of: find.byType(RaftAudioPreview),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final card = tester.getRect(find.byKey(const Key('audio-preview')));
    expect((card.center.dy - viewport.center.dy).abs(), lessThan(1));
  });

  for (final page in [true, false]) {
    testWidgets('${page ? 'page' : 'dialog'} audio: a short window at 2x text '
        'scrolls instead of overflowing', (tester) async {
      await _pumpHome(tester, 2, size: const Size(600, 300), inset: 24);
      await _push(
        tester,
        page,
        () => _shell(
          page: page,
          child: const RaftAudioPreview(filename: 'voice.mp3'),
        ),
      );
      expect(tester.takeException(), isNull);
      final scrollable = find.descendant(
        of: find.byType(RaftAudioPreview),
        matching: find.byType(SingleChildScrollView),
      );
      final viewport = tester.getRect(scrollable);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: scrollable, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final card = tester.getRect(find.byKey(const Key('audio-preview')));
      final sheet = tester.getRect(
        find.byKey(const ValueKey('attachment-comments-sheet')),
      );
      expect(card.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(viewport.bottom, lessThanOrEqualTo(sheet.top));
      expect(tester.takeException(), isNull);
    });
  }
}
