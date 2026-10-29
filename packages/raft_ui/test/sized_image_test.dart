import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<Uint8List> _png(WidgetTester tester, int w, int h) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF3366CC),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

/// Pumps until the engine finished decoding (real async work).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

ui.Image _decoded(WidgetTester tester) =>
    tester.widget<RawImage>(find.byType(RawImage)).image!;

Widget _avatar(
  Uint8List source, {
  double extent = 36,
  bool content = true,
}) => MaterialApp(
  home: Center(
    child: SizedBox.square(
      dimension: extent,
      child: content
          ? RaftAvatarContent(
              name: 'Ada',
              uploadedUrl:
                  'https://public.example.test/api/avatars/users/abcdef.webp',
              imageProviderBuilder: (_) => MemoryImage(source),
            )
          : RaftSizedImage.memory(source, fit: BoxFit.cover),
    ),
  ),
);

void main() {
  tearDown(() => PaintingBinding.instance.imageCache.clear());

  group('target size policy', () {
    test('rounds up and never upscales', () {
      expect(raftPhysicalExtent(36, 3), 108);
      expect(raftPhysicalExtent(36.01, 3), 109);
      expect(raftPhysicalExtent(10.2, 2), 21);
      expect(
        raftSizedImageTarget(
          intrinsicWidth: 64,
          intrinsicHeight: 64,
          width: 108,
          height: 108,
          cover: true,
        ),
        (width: 64, height: 64),
      );
    });
    test('cover keeps the short side on the box, fit keeps the long side', () {
      expect(
        raftSizedImageTarget(
          intrinsicWidth: 2000,
          intrinsicHeight: 1000,
          width: 100,
          height: 100,
          cover: true,
        ),
        (width: 200, height: 100),
      );
      expect(
        raftSizedImageTarget(
          intrinsicWidth: 2000,
          intrinsicHeight: 1000,
          width: 100,
          height: 100,
          cover: false,
        ),
        (width: 100, height: 50),
      );
      expect(
        raftSizedImageTarget(
          intrinsicWidth: 2000,
          intrinsicHeight: 1000,
          height: 100,
          cover: false,
        ),
        (width: 200, height: 100),
      );
    });
    test('bucket rounds the decode extent up to 64 physical pixels', () {
      final base = MemoryImage(Uint8List.fromList([1, 2, 3]));
      int? widthOf(double logical, {bool bucket = true}) => (raftSizedImage(
        base,
        logicalWidth: logical,
        devicePixelRatio: 2,
        fit: BoxFit.scaleDown,
        bucket: bucket,
      ) as RaftSizedImageProvider).width;
      expect(widthOf(400), 832);
      expect(widthOf(410), 832);
      expect(widthOf(416), 832);
      expect(widthOf(416.5), 896);
      expect(widthOf(400, bucket: false), 800);
    });
    test('cache key carries the decode box', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final base = MemoryImage(bytes);
      const cfg = ImageConfiguration();
      Future<Object> key(int w) =>
          RaftSizedImageProvider(base, width: w, height: w).obtainKey(cfg);
      expect(await key(72), await key(72));
      expect(await key(72), isNot(await key(108)));
      expect(
        RaftSizedImageProvider(base, width: 72, height: 72),
        RaftSizedImageProvider(base, width: 72, height: 72),
      );
      expect(
        raftSizedImage(base, devicePixelRatio: 2),
        same(base),
        reason: 'no box => unchanged',
      );
    });
  });

  group('avatar decode', () {
    testWidgets('a 36 dp avatar on a 3x screen decodes at <= 108 px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1200, 1800);
      addTearDown(tester.view.reset);
      final source = await _png(tester, 1024, 1024);
      await tester.pumpWidget(_avatar(source));
      await _settle(tester);
      final image = _decoded(tester);
      expect(image.width, lessThanOrEqualTo(108));
      expect(image.height, lessThanOrEqualTo(108));
      expect(image.width, 108, reason: 'sharp at the device pixel ratio');
    });

    testWidgets('a non-square source keeps its short side at the box', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final source = await _png(tester, 1024, 512);
      await tester.pumpWidget(_avatar(source));
      await _settle(tester);
      final image = _decoded(tester);
      expect(image.height, 108);
      expect(image.width, 216);
    });

    testWidgets('a small source is not upscaled', (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final source = await _png(tester, 40, 40);
      await tester.pumpWidget(_avatar(source));
      await _settle(tester);
      expect(_decoded(tester).width, 40);
    });

    testWidgets('a changed pixel ratio re-resolves at the new size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = await _png(tester, 1024, 1024);
      await tester.pumpWidget(_avatar(source));
      await _settle(tester);
      expect(_decoded(tester).width, 36);
      tester.view.devicePixelRatio = 3;
      await tester.pump();
      await _settle(tester);
      expect(_decoded(tester).width, 108);
    });

    testWidgets('one source at two extents is two cache entries', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final source = await _png(tester, 1024, 1024);
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              SizedBox.square(
                dimension: 20,
                child: RaftSizedImage.memory(
                  source,
                  key: const Key('small'),
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox.square(
                dimension: 80,
                child: RaftSizedImage.memory(
                  source,
                  key: const Key('large'),
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      );
      await _settle(tester);
      ui.Image of(String k) => tester
          .widget<RawImage>(
            find.descendant(
              of: find.byKey(Key(k)),
              matching: find.byType(RawImage),
            ),
          )
          .image!;
      expect(of('small').width, 40);
      expect(of('large').width, 160, reason: 'not the small decode, scaled up');
    });

    testWidgets('zoomable viewers decode at viewport x zoom', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(1000, 1000);
      addTearDown(tester.view.reset);
      final source = await _png(tester, 4000, 2000);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RaftSizedImage.memory(
              source,
              fit: BoxFit.contain,
              zoom: raftZoomableImageScale,
            ),
          ),
        ),
      );
      await _settle(tester);
      // 500 dp wide viewport x 2 (dpr) x 2.5 (zoom) = 2500 px wide.
      expect(_decoded(tester).width, 2500);
    });

    testWidgets('evictOnDispose drops the sized entry', (tester) async {
      final source = await _png(tester, 256, 256);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 32,
            child: RaftSizedImage.memory(source, evictOnDispose: true),
          ),
        ),
      );
      await _settle(tester);
      expect(PaintingBinding.instance.imageCache.currentSize, greaterThan(0));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(PaintingBinding.instance.imageCache.currentSize, 0);
    });
  });
}
