import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_table_border.dart';

const _table = '''
| A long heading that remains wider than the first body cell | Status | Notes |
|:---|:---:|---:|
| Short | Ready | An_unbroken_value_that_makes_the_table_horizontally_scrollable_0123456789 |
| A longer body value than its heading | Waiting | A second line of ordinary wrapping prose |
| Third | Running | More content |
| Fourth | Done | Last row |
''';

const _longCode =
    'An_unbroken_code_line_that_overflows_the_embedded_horizontal_viewport_'
    '012345678901234567890123456789012345678901234567890123456789'
    '012345678901234567890123456789012345678901234567890123456789'
    '012345678901234567890123456789012345678901234567890123456789'
    '012345678901234567890123456789012345678901234567890123456789';

Future<ScrollController> _mount(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  Size size = const Size(390, 844),
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  RaftInteraction? interaction,
  Widget child = const RaftMessageBody(content: _table),
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final parent = ScrollController();
  addTearDown(parent.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            textScaler: textScaler,
          ),
          child: RepaintBoundary(
            key: const ValueKey('scroll-test-frame'),
            child: RaftInteractionScope(
              interaction: interaction ?? RaftInteraction.forPlatform(platform),
              child: Material(
                child: SingleChildScrollView(
                  key: const ValueKey('vertical-parent'),
                  controller: parent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 100),
                      child,
                      const SizedBox(height: 1400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return parent;
}

Finder get _horizontal => find.byWidgetPredicate(
  (widget) =>
      widget is SingleChildScrollView &&
      widget.scrollDirection == Axis.horizontal,
);

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: _horizontal,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
        ),
      ),
    )
    .position;

Future<void> _scrollContent(
  WidgetTester tester, {
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.dragFrom(
    tester.getCenter(_horizontal),
    Offset(direction == TextDirection.ltr ? -100 : 100, 0),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 180));
  if (_position(tester).pixels == 0) {
    debugPrint(
      'Horizontal diagnostic: viewport=${tester.getRect(_horizontal)}, '
      'extent=${_position(tester).maxScrollExtent}, '
      'scrollables=${find.descendant(of: _horizontal, matching: find.byType(Scrollable)).evaluate().map((element) => (element.widget as Scrollable).axisDirection).toList()}',
    );
  }
  expect(_position(tester).pixels, greaterThan(0));
}

/// Rasterizes the real mounted scrollbar's foreground painter, rather than
/// inferring the thumb from its outer scroll view or its configured padding.
Future<Rect> _paintedThumb(WidgetTester tester, String label) async {
  final position = _position(tester);
  final scrollbar = find.byWidgetPredicate(
    (widget) =>
        widget is RawScrollbar &&
        (widget.controller?.positions.contains(position) ?? false),
  );
  expect(scrollbar, findsOneWidget);
  final paintFinder = find.descendant(
    of: scrollbar,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.foregroundPainter is ScrollbarPainter,
    ),
  );
  // There must be one table scrollbar, without an automatic second one.
  expect(paintFinder, findsOneWidget);
  final paint = tester.widget<CustomPaint>(paintFinder);
  final painter = paint.foregroundPainter! as ScrollbarPainter;
  final size = tester.getSize(paintFinder);
  final recorder = ui.PictureRecorder();
  paint.foregroundPainter!.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(
    () => picture.toImage(size.width.ceil(), size.height.ceil()),
  ))!;
  try {
    final rgba = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    var left = image.width, top = image.height, right = -1, bottom = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (rgba.getUint8((y * image.width + x) * 4 + 3) == 0) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    expect(right, greaterThanOrEqualTo(left), reason: 'Visible thumb required');
    final local = Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      (right + 1).toDouble(),
      (bottom + 1).toDouble(),
    );
    final global = local.shift(tester.getTopLeft(paintFinder));
    final evidence = Platform.environment['RAFT_SCROLLBAR_EVIDENCE'];
    if (evidence != null) {
      final directory = Directory(evidence)..createSync(recursive: true);
      File('${directory.path}/$label.png').writeAsBytesSync(
        (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        ))!.buffer.asUint8List(),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('scroll-test-frame')),
      );
      final frame = (await tester.runAsync(() => boundary.toImage()))!;
      try {
        File('${directory.path}/$label-frame.png').writeAsBytesSync(
          (await tester.runAsync(
            () => frame.toByteData(format: ui.ImageByteFormat.png),
          ))!.buffer.asUint8List(),
        );
      } finally {
        frame.dispose();
      }
      File('${directory.path}/$label.json').writeAsStringSync(
        jsonEncode({
          'painterSize': [size.width, size.height],
          'thickness': painter.thickness,
          'color': painter.color.toARGB32(),
          'radius': painter.radius?.x,
          'thumb': [global.left, global.top, global.right, global.bottom],
          'table': find.byType(Table).evaluate().isEmpty
              ? null
              : [
                  tester.getRect(find.byType(Table)).left,
                  tester.getRect(find.byType(Table)).top,
                  tester.getRect(find.byType(Table)).right,
                  tester.getRect(find.byType(Table)).bottom,
                ],
          'scrollOffset': _position(tester).pixels,
        }),
      );
    }
    return global;
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void _recordPan(
  WidgetTester tester,
  String label,
  ScrollController parent,
  double horizontalBefore,
) {
  final evidence = Platform.environment['RAFT_SCROLLBAR_EVIDENCE'];
  if (evidence == null) return;
  final directory = Directory(evidence)..createSync(recursive: true);
  File('${directory.path}/$label-gesture.json').writeAsStringSync(
    jsonEncode({
      'parentVerticalOffset': parent.offset,
      'horizontalBefore': horizontalBefore,
      'horizontalAfter': _position(tester).pixels,
      'horizontalExtent': _position(tester).maxScrollExtent,
    }),
  );
}

Future<List<int>> _frameBytes(WidgetTester tester, String label) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('scroll-test-frame')),
  );
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  try {
    final rgba = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!.buffer.asUint8List();
    final evidence = Platform.environment['RAFT_SCROLLBAR_EVIDENCE'];
    if (evidence != null) {
      final directory = Directory(evidence)..createSync(recursive: true);
      File('${directory.path}/$label.png').writeAsBytesSync(
        (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        ))!.buffer.asUint8List(),
      );
    }
    return rgba;
  } finally {
    image.dispose();
  }
}

void _case(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      // Dispose the entire fixture even when an old-source assertion fails.
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

void main() {
  for (final dark in [false, true]) {
    for (final direction in TextDirection.values) {
      _case('iOS table thumb stays below its last row $dark/$direction', (
        tester,
      ) async {
        await _mount(tester, dark: dark, direction: direction);
        await _scrollContent(tester, direction: direction);
        final thumb = await _paintedThumb(
          tester,
          'ios-edge-$dark-${direction.name}',
        );
        final table = tester.getRect(find.byType(Table));
        final viewport = tester.getRect(_horizontal);
        expect(thumb.top, greaterThanOrEqualTo(table.bottom));
        expect(thumb.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(viewport.bottom - thumb.bottom, lessThanOrEqualTo(1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final device in [
    (TargetPlatform.iOS, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
  ]) {
    _case('finger scroll over table thumb reaches parent $device', (
      tester,
    ) async {
      final parent = await _mount(tester, platform: device.$1, size: device.$2);
      await _scrollContent(tester);
      final thumb = await _paintedThumb(
        tester,
        'touch-pan-${device.$1.name}-${device.$2.width.toInt()}',
      );
      final horizontal = _position(tester).pixels;
      final gesture = await tester.startGesture(thumb.center);
      // Real vertical finger movement has small horizontal jitter. A thumb's
      // zero-slop recognizer must not capture it before the vertical parent.
      await gesture.moveBy(const Offset(2, -1));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, -90));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 80));
      _recordPan(
        tester,
        'touch-pan-${device.$1.name}-${device.$2.width.toInt()}',
        parent,
        horizontal,
      );
      expect(parent.offset, greaterThan(40));
      expect(_position(tester).pixels, closeTo(horizontal, .1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.linux, TargetPlatform.iOS]) {
    _case('narrow pointer table keeps mouse thumb dragging $platform', (
      tester,
    ) async {
      final parent = await _mount(
        tester,
        platform: platform,
        interaction: RaftInteraction.pointerMode,
      );
      await _scrollContent(tester);
      final thumb = await _paintedThumb(
        tester,
        '${platform.name}-mouse-before',
      );
      final before = _position(tester).pixels;
      final gesture = await tester.startGesture(
        thumb.center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(_position(tester).pixels, greaterThan(before + 60));
      expect(parent.offset, 0);
      expect(tester.takeException(), isNull);
    });

    _case(
      'narrow pointer trackpad axes reach their respective scrollers $platform',
      (tester) async {
        final parent = await _mount(
          tester,
          platform: platform,
          interaction: RaftInteraction.pointerMode,
        );
        final center = tester.getCenter(_horizontal);
        final trackpad = await tester.createGesture(
          kind: PointerDeviceKind.trackpad,
        );
        await trackpad.panZoomStart(center);
        await trackpad.panZoomUpdate(center, pan: const Offset(-80, 0));
        await trackpad.panZoomUpdate(center, pan: const Offset(-160, 0));
        await trackpad.panZoomEnd();
        await tester.pump();
        expect(_position(tester).pixels, greaterThan(0));
        expect(parent.offset, 0);
        final horizontal = _position(tester).pixels;
        await trackpad.panZoomStart(center);
        await trackpad.panZoomUpdate(center, pan: const Offset(0, -80));
        await trackpad.panZoomUpdate(center, pan: const Offset(0, -160));
        await trackpad.panZoomEnd();
        await tester.pump();
        expect(parent.offset, greaterThan(0));
        expect(_position(tester).pixels, horizontal);
      },
    );
  }

  for (final fixture in [
    ('table', _table),
    (
      'pre',
      '```\nAn_unbroken_pre_line_that_overflows_the_embedded_horizontal_viewport_012345678901234567890123456789012345678901234567890123456789\n```',
    ),
  ]) {
    _case(
      'body-null message tile keeps ${fixture.$1} thumb at its edge and yields finger pans',
      (tester) async {
        final parent = await _mount(
          tester,
          child: RaftMessageTile(
            author: 'Author',
            content: fixture.$2,
            timestamp: '12:00',
            collapseLongMessages: false,
          ),
        );
        await _scrollContent(tester);
        final thumb = await _paintedThumb(tester, 'fallback-${fixture.$1}');
        final viewport = tester.getRect(_horizontal);
        expect(viewport.bottom - thumb.bottom, lessThanOrEqualTo(1));
        if (fixture.$1 == 'table') {
          expect(
            thumb.top,
            greaterThanOrEqualTo(tester.getRect(find.byType(Table)).bottom),
          );
        }
        final horizontal = _position(tester).pixels;
        final gesture = await tester.startGesture(thumb.center);
        await gesture.moveBy(const Offset(2, -1));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveBy(const Offset(0, -90));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 80));
        _recordPan(tester, 'fallback-${fixture.$1}', parent, horizontal);
        expect(parent.offset, greaterThan(40));
        expect(_position(tester).pixels, closeTo(horizontal, .1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.linux]) {
    for (final direction in TextDirection.values) {
      _case(
        'stock table cells and intrinsic geometry survive $platform/$direction',
        (tester) async {
          await _mount(
            tester,
            platform: platform,
            direction: direction,
            child: RaftMessageBody(
              content: _table
                  .trim()
                  .split('\n')
                  .map((line) => '> $line')
                  .join('\n'),
            ),
          );
          final table = tester.widget<Table>(find.byType(Table));
          expect(table.defaultColumnWidth, isA<IntrinsicColumnWidth>());
          expect(table.border, isA<MessageCollapsedTableBorder>());
          expect(table.children, hasLength(5));
          expect(
            table.children.every((row) => row.children.length == 3),
            isTrue,
          );
          for (var column = 0; column < 3; column++) {
            final header = tester.getRect(
              find.byWidget(table.children.first.children[column]),
            );
            for (final row in table.children.skip(1)) {
              final body = tester.getRect(find.byWidget(row.children[column]));
              expect(body.left, closeTo(header.left, .1));
              expect(body.right, closeTo(header.right, .1));
            }
          }
          final markdown = tester.widget<MarkdownBody>(
            find.byWidgetPredicate((widget) => widget is MarkdownBody),
          );
          final scroll = tester.widget<SingleChildScrollView>(_horizontal);
          expect(scroll.padding, markdown.styleSheet!.tablePadding);
          final render = tester.renderObject<RenderBox>(find.byType(Table));
          expect(
            render.size.width,
            closeTo(render.getMaxIntrinsicWidth(double.infinity), .1),
          );
          expect(_position(tester).maxScrollExtent, greaterThan(0));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final device in [
    (TargetPlatform.iOS, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
    (TargetPlatform.linux, const Size(390, 844)),
  ]) {
    _case('code content keeps horizontal and parent vertical pans $device', (
      tester,
    ) async {
      final parent = await _mount(
        tester,
        platform: device.$1,
        size: device.$2,
        child: const RaftCodeBlock(code: _longCode),
      );
      await _scrollContent(tester);
      final horizontal = _position(tester).pixels;
      final rect = tester.getRect(_horizontal);
      await tester.dragFrom(
        rect.bottomCenter - const Offset(0, 2),
        const Offset(0, -90),
      );
      await tester.pump(const Duration(milliseconds: 80));
      _recordPan(
        tester,
        'code-pan-${device.$1.name}-${device.$2.width.toInt()}',
        parent,
        horizontal,
      );
      expect(parent.offset, greaterThan(40));
      expect(_position(tester).pixels, closeTo(horizontal, .1));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RawScrollbar &&
              (widget.controller?.positions.any(
                    (position) =>
                        axisDirectionToAxis(position.axisDirection) ==
                        Axis.horizontal,
                  ) ??
                  false),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final mixed in [false, true]) {
    _case(
      'Android ${mixed ? 'mixed' : 'code-only'} message content keeps finger pans',
      (tester) async {
        final parent = await _mount(
          tester,
          platform: TargetPlatform.android,
          size: const Size(856, 944),
          child: RaftMessageBody(
            content:
                '${mixed ? 'Intro paragraph\n\n' : ''}```\n$_longCode\n```',
          ),
        );
        expect(
          tester
              .widget<RaftCodeBlock>(find.byType(RaftCodeBlock))
              .joinsSelection,
          mixed,
        );
        await _scrollContent(tester);
        final horizontal = _position(tester).pixels;
        await tester.dragFrom(
          tester.getRect(_horizontal).bottomCenter - const Offset(0, 2),
          const Offset(0, -90),
        );
        await tester.pump();
        expect(parent.offset, greaterThan(40));
        expect(_position(tester).pixels, closeTo(horizontal, .1));
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    _case(
      'standalone touch code retains long-press Select all and Copy $platform',
      (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await _mount(
          tester,
          platform: platform,
          child: const RaftCodeBlock(code: 'alpha beta gamma'),
        );
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump();
        }
        await tester.longPress(
          find.text('alpha beta gamma', findRichText: true),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Copy'), findsOneWidget);
        final selectAll = platform == TargetPlatform.iOS
            ? 'Select All'
            : 'Select all';
        expect(find.text(selectAll), findsOneWidget);
        await tester.tap(find.text(selectAll));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (find.text('Copy').evaluate().isEmpty) {
          await tester.longPress(
            find.text('alpha beta gamma', findRichText: true),
          );
          await tester.pump();
        }
        await tester.tap(find.text('Copy'));
        await tester.pump();
        expect(copied, 'alpha beta gamma');
        expect(find.text('Copy'), findsNothing);
      },
    );
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 3.1]) {
      _case('standalone touch code keeps original text paint $dark/$scale', (
        tester,
      ) async {
        const code = RaftCodeBlock(
          code: 'final value = 42;\nprint(value);',
          language: 'dart',
          exportMode: true,
        );
        await _mount(
          tester,
          platform: TargetPlatform.android,
          dark: dark,
          textScaler: TextScaler.linear(scale),
          interaction: RaftInteraction.pointerMode,
          child: code,
        );
        expect(find.byType(SelectableText), findsOneWidget);
        final original = await _frameBytes(
          tester,
          'code-original-$dark-$scale',
        );
        await _mount(
          tester,
          platform: TargetPlatform.android,
          dark: dark,
          textScaler: TextScaler.linear(scale),
          interaction: RaftInteraction.touchMode,
          child: code,
        );
        expect(find.byType(SelectableText), findsNothing);
        final touch = await _frameBytes(tester, 'code-touch-$dark-$scale');
        expect(listEquals(touch, original), isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  _case(
    'standalone pointer code retains desktop keyboard select-all and copy',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _mount(
        tester,
        platform: TargetPlatform.linux,
        child: const RaftCodeBlock(code: 'alpha beta gamma'),
      );
      expect(find.byType(SelectableText), findsOneWidget);
      await tester.tap(find.text('alpha beta gamma', findRichText: true));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, 'alpha beta gamma');
    },
  );
}
