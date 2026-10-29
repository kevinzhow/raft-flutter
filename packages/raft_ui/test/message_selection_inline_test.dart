import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _mixed = '''
# Heading text

Plain **bold** *italic* `inline code` [a link](https://example.org/x) @Cindy #general 😀 end

- list item one
- list item two

> quoted words

| h1 | h2 |
|----|----|
| c1 | c2 |

```dart
final x = 1;
```

tail words''';

const _refs = [
  RaftTextReference(text: '@Cindy', href: 'raft-ref://mention/user/cindy'),
  RaftTextReference(text: '#general', href: 'raft-ref://channel/general'),
];

RaftReferenceAppearance? _appearance(String href) => href.contains('mention')
    ? const RaftReferenceAppearance(RaftReferenceKind.mention)
    : const RaftReferenceAppearance(RaftReferenceKind.channel);

final _shot = GlobalKey();

Widget _host(Widget child, {double width = 600}) => MaterialApp(
  theme: raftTheme(dark: false),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _shot,
        child: ColoredBox(
          color: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: child,
          ),
        ),
      ),
    ),
  ),
);

Widget _body(String content, {List<String>? links}) => RaftMessageBody(
  content: content,
  references: _refs,
  referenceAppearance: _appearance,
  onLink: links?.add,
);

List<RenderParagraph> _paragraphs(WidgetTester tester) {
  final out = <RenderParagraph>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o);
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(RaftMessageBody)));
  return out;
}

/// Selected text of the paragraph that shows [snippet]; null if none does.
String? _selectedIn(WidgetTester tester, String snippet) {
  for (final p in _paragraphs(tester)) {
    final text = p.text.toPlainText();
    if (!text.contains(snippet)) continue;
    return [for (final s in p.selections) text.substring(s.start, s.end)]
        .join('|');
  }
  return null;
}

/// Global rect of [snippet] (first paragraph that shows it).
Rect _rectOf(WidgetTester tester, String snippet) {
  for (final p in _paragraphs(tester)) {
    final text = p.text.toPlainText();
    final at = text.indexOf(snippet);
    if (at < 0) continue;
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: at, extentOffset: at + snippet.length),
    );
    final origin = p.localToGlobal(Offset.zero);
    return boxes
        .map((b) => b.toRect().shift(origin))
        .reduce((a, b) => a.expandToInclude(b));
  }
  throw StateError('no paragraph shows "$snippet"');
}

/// Share of the pixels inside [rect] whose colour differs between two frames:
/// a highlight drawn behind opaque paint changes none of them.
double _changed(ui.Image a, ByteData ad, ByteData bd, Rect rect) {
  var changed = 0, total = 0;
  for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
    for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
      final i = (y * a.width + x) * 4;
      total++;
      for (var c = 0; c < 3; c++) {
        if ((ad.getUint8(i + c) - bd.getUint8(i + c)).abs() > 8) {
          changed++;
          break;
        }
      }
    }
  }
  return changed / total;
}

Future<(ui.Image, ByteData)> _frame(WidgetTester tester) async {
  final image = await _image(tester);
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  addTearDown(image.dispose);
  return (image, data);
}

/// What Ctrl+C would put on the clipboard.
Future<String?> _copied(WidgetTester tester) async {
  String? text;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        text = (call.arguments as Map)['text'] as String?;
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
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
  return text;
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  // Nested selection containers publish their geometry one frame per level.
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await tester.pump();
  await g.moveTo(to, timeStamp: const Duration(milliseconds: 100));
  await tester.pump();
  await g.moveTo(to + const Offset(1, 1));
  await tester.pump();
  await g.up();
  await tester.pump();
}

Future<ui.Image> _image(WidgetTester tester) async {
  final boundary =
      _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
}

Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final name in const [
      'SpaceGrotesk',
      'SpaceMono',
      'HankenGrotesk',
      'Geist',
      'GeistMono',
      'Inter',
    ]) {
      ByteData data;
      try {
        data = await rootBundle.load('packages/raft_ui/assets/fonts/$name.ttf');
      } on FlutterError {
        data = await rootBundle.load('assets/fonts/$name.ttf');
      }
      await (FontLoader(
        'packages/raft_ui/$name',
      )..addFont(Future.value(data))).load();
    }
  });
}

/// [testWidgets] on [platform] (the test default is Android).
void _testOn(
  TargetPlatform platform,
  String name,
  Future<void> Function(WidgetTester) body,
) => testWidgets(name, (tester) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    // Each scenario must work when selected alone or shuffled before the
    // mixed-message scenario. Ahem's metrics otherwise change link wrapping
    // and the coordinates of the blank-space selection gesture.
    await _loadFonts(tester);
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
});

void main() {
  _testOn(
    TargetPlatform.linux,
    'a drag across a mixed message highlights and copies every '
    'element',
    (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(_body(_mixed)));
      final (img, before) = await _frame(tester);
      final box = tester.getRect(find.byType(RaftMessageBody));
      await _drag(
        tester,
        box.topLeft + const Offset(1, 1),
        box.bottomRight - const Offset(1, 1),
      );
      final (_, after) = await _frame(tester);

      for (final element in const [
        'Heading text',
        'Plain',
        'bold',
        'italic',
        'inline code',
        'a link',
        'quoted words',
        'h1',
        'c2',
        'list item one',
        'final x = 1;',
        'tail words',
      ]) {
        final rect = _rectOf(tester, element);
        expect(
          _changed(img, before, after, rect),
          greaterThan(.25),
          reason: '"$element" shows no selection highlight',
        );
      }
      // Mention and channel chip: their label is a separate run.
      for (final label in const ['@Cindy', '#general']) {
        expect(_selectedIn(tester, label), label, reason: label);
        expect(
          _changed(img, before, after, _rectOf(tester, label)),
          greaterThan(.25),
          reason: '"$label" shows no selection highlight',
        );
      }
      // One line per block, a mention copies as @name. (Table cells may
      // join without a separator: Flutter's scrollable selection container
      // owns them.)
      expect(
        await _copied(tester),
        matches(
          RegExp(
            r'^Heading text\n'
            r'Plain bold italic inline code a link @Cindy #general 😀 end\n'
            r'list item one\n'
            r'list item two\n'
            r'quoted words\n'
            r'h1\W*h2\W*c1\W*c2\n'
            r'final x = 1;\n'
            r'tail words$',
          ),
        ),
      );
      // Web copies a list without its markers.
      expect(await _copied(tester), isNot(contains('•')));
    },
  );

  _testOn(
    TargetPlatform.macOS,
    'a drag from the blank space beside a link-only message '
    'selects the link; a click still opens it',
    (tester) async {
      tester.view.physicalSize = const Size(800, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const url = 'https://docs.raft.build/developers/raft-apps/';
      final links = <String>[];
      await tester.pumpWidget(_host(_body(url, links: links)));
      final text = _rectOf(tester, url);
      final y = text.center.dy;
      expect(text.right, lessThan(500), reason: 'there is blank space beside');

      // Blank space to the right of the link, dragged left across it.
      await _drag(tester, Offset(580, y), Offset(text.left + 1, y));
      expect(_selectedIn(tester, url), url);
      expect(await _copied(tester), url);
      expect(links, isEmpty);

      // A drag starting on the link selects, it does not click.
      await tester.tapAt(const Offset(700, 250));
      await tester.pump();
      await _drag(
        tester,
        Offset(text.left + 40, y),
        Offset(text.left + 120, y),
      );
      expect(_selectedIn(tester, url), isNotEmpty);
      expect(links, isEmpty);

      // A plain click opens it.
      await tester.tapAt(const Offset(700, 250));
      await tester.pump();
      await tester.tapAt(Offset(text.left + 40, y));
      await tester.pump(const Duration(milliseconds: 400));
      expect(links, [url]);
    },
  );

  _testOn(
    TargetPlatform.android,
    'a touch selection shows Copy and Select all; Copy puts the '
    'message text on the clipboard',
    (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clip = (call.arguments as Map)['text'] as String?;
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
      await tester.pumpWidget(
        _host(_body('hi @Cindy and [a link](https://example.org/x) `code`')),
      );
      expect(find.byType(RaftTextSelectionToolbar), findsNothing);
      // Nested selection containers publish their geometry one frame per level.
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.longPressAt(_rectOf(tester, 'hi').center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RaftTextSelectionToolbar), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);

      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      if (find.text('Copy').evaluate().isEmpty) {
        // The toolbar re-shows after Select all on some platforms.
        await tester.longPressAt(_rectOf(tester, 'hi').center);
        await tester.pump();
      }
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(clip, 'hi @Cindy and a link code');
    },
  );

  _testOn(
    TargetPlatform.linux,
    'on desktop a right click opens the host menu, not the '
    'platform toolbar',
    (tester) async {
      tester.view.physicalSize = const Size(800, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var host = 0;
      await tester.pumpWidget(
        _host(
          // The message row's own hook: a Listener, because the selection
          // area wins the secondary tap in the gesture arena.
          Listener(
            onPointerDown: (e) {
              if ((e.buttons & kSecondaryMouseButton) != 0) host++;
            },
            child: _body('plain words here'),
          ),
        ),
      );
      final at = _rectOf(tester, 'words').center;
      final mouse = await tester.startGesture(
        at,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouse.up();
      await tester.pump();
      expect(host, 1);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      expect(find.byType(RaftTextSelectionToolbar), findsNothing);
      expect(find.text('Copy'), findsNothing);
    },
  );
}
