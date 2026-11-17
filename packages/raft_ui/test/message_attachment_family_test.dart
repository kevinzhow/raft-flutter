import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Message attachment family against raft-ui 0.95.3 (message-attachment,
// message-image-gallery, file-preview badge). The Raft look follows the
// recipes. Input mode comes from
// RaftInteractionScope, never from width.

const _touch = [Size(856, 944), Size(944, 856)];
const _mouse = [Size(390, 844), Size(1440, 900)];

Future<RaftTokens> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required bool touch,
  double width = 600,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  late RaftTokens tokens;
  await tester.pumpWidget(
    RaftInteractionScope(
      interaction: touch
          ? RaftInteraction.touchMode
          : RaftInteraction.pointerMode,
      child: MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Builder(
                builder: (context) {
                  tokens = RaftTokens.of(context);
                  return child;
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tokens;
}

Widget _card() => RaftAttachmentCard(
  filename: 'report.pdf',
  mimeType: 'application/pdf',
  sizeBytes: 2048,
  metaLabel: 'Portable document',
  summary: 'Quarterly numbers',
  onOpen: () {},
);

Material _surface(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(
        of: find.byType(RaftAttachmentCard),
        matching: find.byType(Material),
      )
      .first,
);

TextStyle _text(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style!;

Future<void> _hover(WidgetTester tester, Finder at) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(at));
  await tester.pump();
}

Widget _gallery(
  List<({double? width, double? height})> dims,
  List<Size> extents,
) => RaftAttachmentGallery(
  dimensions: dims,
  itemBuilder: (index, extent, fit) {
    extents.add(extent);
    return SizedBox.fromSize(key: ValueKey('img$index'), size: extent);
  },
);

const _square = (width: 100.0, height: 100.0);

void main() {
  for (final (size, touch) in [
    for (final s in _touch) (s, true),
    for (final s in _mouse) (s, false),
  ]) {
    final label =
        '${size.width.toInt()}x${size.height.toInt()} '
        '${touch ? 'touch' : 'mouse'}';
    group('card $label', () {
      testWidgets('Raft: radius 10, right inset 5, callout title, mono meta', (
        tester,
      ) async {
        final t = await _pump(tester, _card(), size: size, touch: touch);
        final shape = _surface(tester).shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(10));
        final inset = tester
            .widgetList<Padding>(
              find.descendant(
                of: find.byType(RaftAttachmentCard),
                matching: find.byType(Padding),
              ),
            )
            .map((p) => p.padding)
            .whereType<EdgeInsets>()
            .where((p) => p.left == 11 && p.right == 6);
        expect(inset, isNotEmpty);
        final title = _text(tester, 'report.pdf');
        expect(title.fontSize, 14);
        expect(title.fontWeight, FontWeight.w600);
        expect(title.height! * 14, closeTo(t.desktop ? 22 : 20, .01));
        final meta = _text(tester, 'Portable document');
        expect(meta.fontSize, 12);
        expect(meta.fontFamily, t.monoFont);
        expect(meta.height! * 12, closeTo(t.desktop ? 18 : 16, .01));
        final summary = _text(tester, 'Quarterly numbers');
        expect(summary.fontSize, 12);
        expect(summary.fontFamily, t.monoFont);
        expect(meta.color, t.colors['foreground-hint']);
      });

      testWidgets('Raft gallery: gap 4, container-keyed row height', (
        tester,
      ) async {
        final extents = <Size>[];
        await _pump(
          tester,
          _gallery([_square, _square], extents),
          size: size,
          touch: touch,
          width: 360,
        );
        final a = tester.getRect(find.byKey(const ValueKey('img0')));
        final b = tester.getRect(find.byKey(const ValueKey('img1')));
        expect(b.left - a.right, 4);
        expect(a.height, 144);
        expect(a.width + b.width + 4, 360);
      });
    });
  }

  testWidgets('gallery: 359 container is 128 high, 3 images 112', (
    tester,
  ) async {
    final extents = <Size>[];
    await _pump(
      tester,
      _gallery([_square, _square], extents),
      size: const Size(1440, 900),
      touch: false,
      width: 359,
    );
    expect(tester.getSize(find.byKey(const ValueKey('img0'))).height, 128);
    extents.clear();
    await _pump(
      tester,
      _gallery([_square, _square, _square], extents),
      size: const Size(1440, 900),
      touch: false,
      width: 359,
    );
    expect(tester.getSize(find.byKey(const ValueKey('img0'))).height, 112);
  });

  testWidgets('gallery: root max 360 on a wide window, 3 images stay one row', (
    tester,
  ) async {
    final extents = <Size>[];
    await _pump(
      tester,
      _gallery([_square, _square, _square], extents),
      size: const Size(390, 844),
      touch: false,
      width: 600,
    );
    final rects = [
      for (var i = 0; i < 3; i++) tester.getRect(find.byKey(ValueKey('img$i'))),
    ];
    expect(rects.map((r) => r.top).toSet().length, 1);
    expect(rects.last.right - rects.first.left, closeTo(360, .01));
    expect(rects.first.height, 128);
  });

  for (final dark in [false, true]) {
    testWidgets('card hover keeps the hairline border, overlays fill-subtle '
        '(dark=$dark)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      late RaftTokens t;
      await tester.pumpWidget(
        RaftInteractionScope(
          interaction: RaftInteraction.pointerMode,
          child: MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) {
                    t = RaftTokens.of(context);
                    return _card();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hairline = t.colors['line-hairline'];
      expect(
        (_surface(tester).shape! as RoundedRectangleBorder).side.color,
        hairline,
      );
      Finder overlay(Color c) => find.descendant(
        of: find.byType(RaftAttachmentCard),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == c,
        ),
      );
      expect(overlay(t.colors['fill-subtle']!), findsNothing);
      await _hover(tester, find.byType(RaftAttachmentCard));
      expect(
        (_surface(tester).shape! as RoundedRectangleBorder).side.color,
        hairline,
      );
      expect(overlay(t.colors['fill-subtle']!), findsOneWidget);
      final press = await tester.startGesture(
        tester.getCenter(find.byType(RaftAttachmentCard)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(overlay(t.colors['fill-medium']!), findsOneWidget);
      await press.up();
      await tester.pump();
    });
  }

  testWidgets('badge: Raft is neutral fill-muted with a hairline ring', (
    tester,
  ) async {
    final t = await _pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: RaftFileTypeBadge(filename: 'a.md', size: Size(28, 14)),
      ),
      size: const Size(1440, 900),
      touch: false,
    );
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(RaftFileTypeBadge),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final d = box.decoration as BoxDecoration;
    expect(d.color, t.colors['fill-muted']);
    expect(d.borderRadius, BorderRadius.circular(4));
    expect(
      d.boxShadow!.single,
      BoxShadow(color: t.colors['line-hairline']!, spreadRadius: 1),
    );
    final label = _text(tester, 'MD');
    expect(label.fontSize, 10);
    expect(label.fontWeight, FontWeight.w700);
    expect(label.fontFamily, t.monoFont);
    expect(label.color, t.colors['foreground-muted']);
    expect(tester.getSize(find.byType(RaftFileTypeBadge)), const Size(28, 14));
  });

  testWidgets('hover and press repaint the overlay without remounting the '
      'card content', (tester) async {
    await _pump(tester, _card(), size: const Size(1440, 900), touch: false);
    final before = tester.element(find.text('report.pdf'));
    await _hover(tester, find.byType(RaftAttachmentCard));
    expect(identical(tester.element(find.text('report.pdf')), before), isTrue);
    final press = await tester.startGesture(
      tester.getCenter(find.byType(RaftAttachmentCard)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(identical(tester.element(find.text('report.pdf')), before), isTrue);
    await press.up();
    await tester.pump();
    expect(identical(tester.element(find.text('report.pdf')), before), isTrue);
  });

  testWidgets('meta: label and size truncate as one metaStart block, the '
      'comment count and affordance keep their width', (tester) async {
    await _pump(
      tester,
      RaftAttachmentCard(
        filename: 'notes.txt',
        mimeType: 'text/plain',
        sizeBytes: 4096,
        metaLabel: 'Text',
        commentCount: 2,
        onOpen: () {},
      ),
      size: const Size(1280, 800),
      touch: false,
    );
    // The test font is 12px a glyph: the Web `min-w-0 flex-1 truncate`
    // start block gives way (clipped) before the line overflows.
    expect(tester.takeException(), isNull);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('an image tile load error clips like the Web tile '
      '(overflow-hidden) instead of overflowing', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        height: 144,
        child: RaftLoadError(
          'Preview unavailable. Download the original file.',
          expand: false,
        ),
      ),
      size: const Size(1000, 900),
      touch: false,
      width: 178,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RaftLoadError)), const Size(178, 144));
  });
}
