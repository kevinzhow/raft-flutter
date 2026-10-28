// The image viewer's zoom surface (port of Web ImageZoom.ts): limits, fit
// bounds, double-tap, modifier wheel and trackpad gestures.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_image_zoom.dart';

const _stage = Size(400, 600);

class _Rig {
  _Rig(this.controller, this.outside);
  final TransformationController controller;
  final List<Offset> outside;
  double get scale => controller.value.getMaxScaleOnAxis();
  double get tx => controller.value.storage[12];
  double get ty => controller.value.storage[13];
}

Future<_Rig> _mount(
  WidgetTester tester, {
  Size? natural = const Size(800, 600),
  double inset = 0,
}) async {
  final controller = TransformationController();
  addTearDown(controller.dispose);
  final outside = <Offset>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _stage.width,
          height: _stage.height,
          child: ImageZoomSurface(
            controller: controller,
            natural: natural,
            verticalInset: inset,
            onTapOutside: () => outside.add(Offset.zero),
            child: const ColoredBox(color: Colors.red),
          ),
        ),
      ),
    ),
  );
  return _Rig(controller, outside);
}

Future<void> _pinch(WidgetTester tester, {double spread = 60}) async {
  final centre =
      _stage.center(Offset.zero) +
      tester.getTopLeft(find.byType(ImageZoomSurface));
  final a = await tester.startGesture(centre - const Offset(20, 0), pointer: 1);
  final b = await tester.startGesture(centre + const Offset(20, 0), pointer: 2);
  await a.moveBy(Offset(-spread, 0));
  await b.moveBy(Offset(spread, 0));
  await tester.pump();
  await a.up();
  await b.up();
  await tester.pump();
}

/// Two quick taps; the zoom animation starts on the next frame.
Future<void> _doubleTap(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(at);
  await tester.pump();
}

Future<void> _wheel(
  WidgetTester tester,
  Offset at,
  Offset delta, {
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) async {
  final pointer = TestPointer(7, kind);
  await tester.sendEventToBinding(pointer.hover(at));
  await tester.sendEventToBinding(pointer.scroll(delta));
  await tester.pump();
}

void main() {
  group('max scale (Web imageDimensionsToMaxScale)', () {
    test('4x base for ordinary images', () {
      expect(
        imageMaxScale(
          natural: const Size(600, 600),
          fitted: const Size(600, 600),
        ),
        4,
      );
      expect(imageMaxScale(natural: null, fitted: const Size(10, 10)), 4);
      expect(imageMaxScale(natural: const Size(10, 10), fitted: Size.zero), 4);
    });
    test('a long screenshot scales by its natural ratio, capped at 16x', () {
      expect(
        imageMaxScale(
          natural: const Size(600, 6000),
          fitted: const Size(60, 600),
        ),
        10,
      );
      expect(
        imageMaxScale(
          natural: const Size(600, 60000),
          fitted: const Size(6, 600),
        ),
        16,
      );
    });
  });

  group('zoom maths', () {
    test('fit box: never enlarged, keeps the vertical inset free', () {
      expect(fittedImageSize(_stage, const Size(100, 50)), const Size(100, 50));
      expect(
        fittedImageSize(_stage, const Size(800, 600)),
        const Size(400, 300),
      );
      final tall = fittedImageSize(
        _stage,
        const Size(400, 1200),
        verticalInset: 100,
      );
      expect(tall.height, 400);
      expect(tall.width, closeTo(400 / 3, 1e-9));
      expect(fittedImageSize(_stage, null), _stage);
    });

    test('an unknown size takes the known shape and fills the room', () {
      // 3:2 in a 400x600 stage: width limits; 1:3 limits by height.
      expect(
        fittedImageSize(_stage, null, fillAspect: 1.5),
        const Size(400, 400 / 1.5),
      );
      final tall = fittedImageSize(
        _stage,
        null,
        verticalInset: 100,
        fillAspect: 1 / 3,
      );
      expect(tall.height, 400);
      expect(tall.width, closeTo(400 / 3, 1e-9));
      // A known size wins over the shape; nonsense shapes are ignored.
      expect(
        fittedImageSize(_stage, const Size(100, 50), fillAspect: 3),
        const Size(100, 50),
      );
      expect(fittedImageSize(_stage, null, fillAspect: 0), _stage);
      expect(fittedImageSize(_stage, null, fillAspect: double.nan), _stage);
    });

    test('the pan keeps the fitted image box in view', () {
      const fitted = Size(400, 300);
      ImageZoomState clamp(ImageZoomState s, [double max = 4]) =>
          clampImageZoom(s, stage: _stage, fitted: fitted, maxScale: max);
      // 4x: 1600 wide, may move between its edges and the stage edges.
      expect(clamp((scale: 4, tx: -5000, ty: 0)).tx, -1200);
      expect(clamp((scale: 4, tx: 5000, ty: 0)).tx, 0);
      // 1200 tall at 4x on a 600 stage: top and bottom edges bound it.
      expect(clamp((scale: 4, tx: 0, ty: 5000)).ty, -600);
      expect(clamp((scale: 4, tx: 0, ty: -5000)).ty, -1200);
      // 1.5x: 450 tall in a 600 stage: it stays centred, no vertical pan.
      expect(clamp((scale: 1.5, tx: 0, ty: 300)).ty, 300 - 1.5 * 300);
      expect(clamp((scale: 9, tx: 0, ty: 0), 4).scale, 4);
      expect(clamp((scale: .5, tx: 0, ty: 0)).scale, 1);
    });

    test('zoom around a point keeps the content under it', () {
      final z = zoomImageAround(
        (scale: 1, tx: 0, ty: 0),
        2,
        const Offset(100, 80),
      );
      expect(z.scale * 100 + z.tx, 100);
      expect(z.scale * 80 + z.ty, 80);
    });

    test('wheel curve: capped at 2^0.45 per event', () {
      expect(imageWheelZoomFactor(-1000), closeTo(1.366, .001));
      expect(imageWheelZoomFactor(1000), closeTo(1 / 1.366, .001));
      expect(imageWheelZoomFactor(0), 1);
    });
  });

  group('pinch and limits', () {
    testWidgets('a pinch from fit scale zooms', (tester) async {
      final rig = await _mount(tester);
      await _pinch(tester);
      expect(rig.scale, greaterThan(1.2));
    });

    testWidgets('an ordinary image stops at 4x', (tester) async {
      final rig = await _mount(tester, natural: const Size(800, 600));
      await _pinch(tester, spread: 190);
      await _pinch(tester, spread: 190);
      expect(rig.scale, closeTo(4, .001));
    });

    testWidgets('a long screenshot goes beyond 4x, up to its natural ratio', (
      tester,
    ) async {
      // 600x6000 on a 400x600 stage: fitted 60x600, natural ratio 10.
      final rig = await _mount(tester, natural: const Size(600, 6000));
      for (var i = 0; i < 4; i++) {
        await _pinch(tester, spread: 190);
      }
      expect(rig.scale, closeTo(10, .001));
    });
  });

  group('double tap', () {
    testWidgets('toggles fit and 2x around the tap point, animated', (
      tester,
    ) async {
      final rig = await _mount(tester);
      const p = Offset(100, 300);
      await _doubleTap(tester, p);
      await tester.pump(const Duration(milliseconds: 60));
      // Mid-animation: between fit and 2x.
      expect(rig.scale, inExclusiveRange(1, 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(rig.scale, closeTo(2, 1e-6));
      // The point under the finger stays under the finger.
      expect(rig.scale * p.dx + rig.tx, closeTo(p.dx, 1e-6));
      expect(rig.scale * p.dy + rig.ty, closeTo(p.dy, 1e-6));
      // Double-tap again: back to fit.
      await _doubleTap(tester, const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.controller.value, Matrix4.identity());
    });

    testWidgets(
      'a double tap on the image never closes; one tap outside does',
      (tester) async {
        final rig = await _mount(tester, natural: const Size(200, 100));
        await _doubleTap(tester, const Offset(200, 300));
        await tester.pump(const Duration(milliseconds: 400));
        expect(rig.outside, isEmpty);
        expect(rig.scale, closeTo(2, 1e-6));
        // Zoomed to 2x the image fills the width; fit again, tap the margin.
        rig.controller.value = Matrix4.identity();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tapAt(const Offset(200, 20));
        await tester.pump(const Duration(milliseconds: 400));
        expect(rig.outside, hasLength(1));
      },
    );

    testWidgets('two taps far apart in time are two single taps', (
      tester,
    ) async {
      final rig = await _mount(tester);
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.scale, 1);
    });

    testWidgets('a long image zooms by 2x at most its max', (tester) async {
      final rig = await _mount(tester, natural: const Size(100, 100));
      await _doubleTap(tester, const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.scale, closeTo(2, 1e-6));
    });
  });

  group('pan bounds', () {
    testWidgets('a zoomed image cannot be dragged off its own edges', (
      tester,
    ) async {
      final rig = await _mount(tester, natural: const Size(800, 600));
      rig.controller.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);
      await tester.pump();
      // Fitted 400x300: 2x is 800x600; the 400x600 stage shows its middle.
      await tester.dragFrom(const Offset(200, 300), const Offset(-900, 0));
      await tester.pump();
      expect(rig.tx, -400);
      await tester.dragFrom(const Offset(200, 300), const Offset(900, 0));
      await tester.pump();
      expect(rig.tx, 0);
      // Vertically the image is exactly as tall as the stage: no pan.
      await tester.dragFrom(const Offset(200, 300), const Offset(0, 300));
      await tester.pump();
      expect(rig.ty, closeTo(-300, 1e-6));
    });

    testWidgets('a stale transform is clamped when the stage changes', (
      tester,
    ) async {
      final rig = await _mount(tester, natural: const Size(800, 600));
      rig.controller.value = Matrix4.identity()
        ..translateByDouble(-3000, 0, 0, 1)
        ..scaleByDouble(2, 2, 1, 1);
      await tester.pump();
      // The next gesture clamps it.
      await tester.dragFrom(const Offset(200, 300), const Offset(-30, 0));
      await tester.pump();
      expect(rig.tx, -400);
    });
  });

  group('desktop wheel and trackpad', () {
    const at = Offset(200, 300);

    testWidgets('a plain wheel never zooms', (tester) async {
      final rig = await _mount(tester);
      await _wheel(tester, at, const Offset(0, -53));
      await _wheel(tester, at, const Offset(0, 53));
      expect(rig.controller.value, Matrix4.identity());
    });

    testWidgets('Ctrl + wheel zooms around the pointer, Cmd too', (
      tester,
    ) async {
      final rig = await _mount(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _wheel(tester, const Offset(100, 300), const Offset(0, -53));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      final once = rig.scale;
      expect(once, closeTo(1.366, .001));
      expect(once * 100 + rig.tx, closeTo(100, 1e-6));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await _wheel(tester, at, const Offset(0, -53));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(rig.scale, greaterThan(once));
      // Wheel down zooms back out, never below fit.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      for (var i = 0; i < 6; i++) {
        await _wheel(tester, at, const Offset(0, 53));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(rig.scale, 1);
    });

    testWidgets('zoomed, a plain wheel pans (Shift: sideways)', (tester) async {
      final rig = await _mount(tester);
      rig.controller.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);
      await tester.pump();
      final before = (rig.tx, rig.ty);
      await _wheel(tester, at, const Offset(0, 40));
      expect(rig.scale, 2);
      // Fitted 400x300 at 2x fills the 600 height: only sideways pans.
      expect(rig.tx, before.$1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _wheel(tester, at, const Offset(0, 40));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      // Fitted 400x300 at 2x is as wide as 2 stages' worth: it pans sideways.
      expect(rig.tx, before.$1 - 40);
      expect(rig.scale, 2);
    });

    testWidgets('zoomed in a tall image, the wheel scrolls it vertically', (
      tester,
    ) async {
      final rig = await _mount(tester, natural: const Size(300, 1200));
      // Fitted 150x600: 2x is 300x1200 on a 600 stage (top edge at 0).
      rig.controller.value = Matrix4.identity()
        ..translateByDouble(0, 0, 0, 1)
        ..scaleByDouble(2, 2, 1, 1);
      await tester.pump();
      await _wheel(tester, at, const Offset(0, 100));
      expect(rig.ty, closeTo(-100, 1e-6));
      await _wheel(tester, at, const Offset(0, 900));
      expect(rig.ty, closeTo(-600, 1e-6));
      await _wheel(tester, at, const Offset(0, -2000));
      expect(rig.ty, closeTo(0, 1e-6));
    });

    testWidgets('a pinch scale event zooms (Windows / web trackpads)', (
      tester,
    ) async {
      final rig = await _mount(tester);
      await tester.sendEventToBinding(
        PointerScaleEvent(position: at, scale: 1.5),
      );
      await tester.pump();
      expect(rig.scale, closeTo(1.5, 1e-6));
    });

    for (final start in [1.0, 2.0]) {
      testWidgets('trackpad inward pinch stays cumulative after fit ($start)', (
        tester,
      ) async {
        final rig = await _mount(tester);
        rig.controller.value = imageZoomMatrix((scale: start, tx: 0, ty: 0));
        final pad = await tester.createGesture(
          kind: PointerDeviceKind.trackpad,
        );
        await pad.panZoomStart(at);
        await pad.panZoomUpdate(at, scale: 0.25);
        expect(rig.scale, 1);
        await pad.panZoomUpdate(at, scale: 0.4);
        expect(rig.scale, 1);
        await pad.panZoomUpdate(at, scale: 0.75);
        expect(rig.scale, closeTo((start * 0.75).clamp(1, 4), 1e-6));
        await pad.panZoomEnd();
        await tester.pump(const Duration(milliseconds: 500));
        expect(rig.scale, closeTo((start * 0.75).clamp(1, 4), 1e-6));
      });
      testWidgets(
        'trackpad outward pinch stays cumulative after max ($start)',
        (tester) async {
          final rig = await _mount(tester);
          rig.controller.value = imageZoomMatrix((scale: start, tx: 0, ty: 0));
          final pad = await tester.createGesture(
            kind: PointerDeviceKind.trackpad,
          );
          await pad.panZoomStart(at);
          await pad.panZoomUpdate(at, scale: 8);
          expect(rig.scale, 4);
          await pad.panZoomUpdate(at, scale: 6);
          expect(rig.scale, 4);
          await pad.panZoomUpdate(at, scale: 1.5);
          expect(rig.scale, closeTo(start * 1.5, 1e-6));
          await pad.panZoomEnd();
          await tester.pump(const Duration(milliseconds: 500));
          expect(rig.scale, closeTo(start * 1.5, 1e-6));
        },
      );
    }

    testWidgets('a new trackpad pinch anchors to the settled scale', (
      tester,
    ) async {
      final rig = await _mount(tester);
      final pad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
      await pad.panZoomStart(at);
      await pad.panZoomUpdate(at, scale: 0.5);
      await pad.panZoomUpdate(at, scale: 0.75);
      await pad.panZoomEnd();
      expect(rig.scale, 1);
      await pad.panZoomStart(at);
      await pad.panZoomUpdate(at, scale: 2);
      await pad.panZoomEnd();
      expect(rig.scale, 2);
      await pad.panZoomStart(at);
      await pad.panZoomUpdate(at, scale: 0.75);
      await pad.panZoomEnd();
      expect(rig.scale, 1.5);
    });

    testWidgets(
      'pinch interrupts double-click animation without a later jump',
      (tester) async {
        final rig = await _mount(tester);
        await _doubleTap(tester, at);
        await tester.pump(const Duration(milliseconds: 60));
        final start = rig.scale;
        expect(start, inExclusiveRange(1, 2));
        final pad = await tester.createGesture(
          kind: PointerDeviceKind.trackpad,
        );
        await pad.panZoomStart(at);
        await pad.panZoomUpdate(at, scale: 0.25);
        await pad.panZoomUpdate(at, scale: 0.5);
        await pad.panZoomEnd();
        await tester.pump(const Duration(milliseconds: 500));
        expect(rig.scale, 1);
      },
    );

    testWidgets('trackpad pinch zooms, two-finger scroll pans only zoomed', (
      tester,
    ) async {
      final rig = await _mount(tester, natural: const Size(300, 1200));
      final pad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
      await pad.panZoomStart(at);
      await pad.panZoomUpdate(at, pan: const Offset(0, -80));
      // At fit scale a scroll does not move the image.
      expect(rig.controller.value, Matrix4.identity());
      await pad.panZoomUpdate(at, pan: const Offset(0, -80), scale: 2);
      await pad.panZoomEnd();
      await tester.pump();
      expect(rig.scale, closeTo(2, 1e-6));
      await pad.panZoomStart(at);
      await pad.panZoomUpdate(at, pan: const Offset(0, -100));
      await pad.panZoomEnd();
      await tester.pump();
      expect(rig.ty, closeTo(-300 - 100, 1e-6));
    });
  });
}
