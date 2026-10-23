// Reduced motion (Web `prefers-reduced-motion: reduce`): ImageZoom jumps
// instead of animating, the typing dots hold still, and raft_ui's one-off
// transitions take no time. Web applies it narrowly (a few CSS animations,
// ImageZoom and three `motion-reduce:transition-none` spots); the app already
// honoured it in the reaction bump, the bulk-model step, the media browser and
// the sidebar disclosure, and these are the sites it did not.
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_image_zoom.dart';
import 'package:raft_ui/raft_ui.dart';

Widget app(bool reduced, Widget child) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  group('ImageZoom (Web ImageZoom.ts)', () {
    Future<TransformationController> mount(WidgetTester t, bool reduced) async {
      final controller = TransformationController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        app(
          reduced,
          SizedBox(
            width: 400,
            height: 600,
            child: ImageZoomSurface(
              controller: controller,
              natural: const Size(800, 600),
              verticalInset: 0,
              onTapOutside: () {},
              child: const ColoredBox(color: Colors.red),
            ),
          ),
        ),
      );
      return controller;
    }

    Future<void> doubleTap(WidgetTester t) async {
      await t.tapAt(const Offset(100, 300));
      await t.pump(const Duration(milliseconds: 100));
      await t.tapAt(const Offset(100, 300));
      await t.pump();
    }

    testWidgets('a double tap animates normally', (t) async {
      final controller = await mount(t, false);
      await doubleTap(t);
      await t.pump(const Duration(milliseconds: 60));
      expect(controller.value.getMaxScaleOnAxis(), inExclusiveRange(1.0, 2.0));
      await t.pump(const Duration(milliseconds: 300));
      expect(controller.value.getMaxScaleOnAxis(), closeTo(2, 1e-6));
    });

    testWidgets('with reduced motion it lands on the zoom at once, both ways', (
      t,
    ) async {
      final controller = await mount(t, true);
      await doubleTap(t);
      expect(controller.value.getMaxScaleOnAxis(), closeTo(2, 1e-6));
      // The way back is just as immediate.
      await t.tapAt(const Offset(200, 300));
      await t.pump(const Duration(milliseconds: 100));
      await t.tapAt(const Offset(200, 300));
      await t.pump();
      expect(controller.value, Matrix4.identity());
    });

    testWidgets('turning it on mid-zoom does not leave the zoom half done', (
      t,
    ) async {
      final controller = await mount(t, false);
      await doubleTap(t);
      await t.pump(const Duration(milliseconds: 60));
      final surface = t.state<ImageZoomSurfaceState>(
        find.byType(ImageZoomSurface),
      );
      await t.pumpWidget(
        app(
          true,
          SizedBox(
            width: 400,
            height: 600,
            child: ImageZoomSurface(
              controller: controller,
              natural: const Size(800, 600),
              verticalInset: 0,
              onTapOutside: () {},
              child: const ColoredBox(color: Colors.red),
            ),
          ),
        ),
      );
      surface.resetZoom();
      expect(controller.value, Matrix4.identity());
    });
  });

  group('typing dots', () {
    final bouncing = find.descendant(
      of: find.byType(IsTypingIndicator),
      matching: find.byType(SlideTransition),
    );
    final circles = find.descendant(
      of: find.byType(IsTypingIndicator),
      matching: find.byType(DecoratedBox),
    );

    testWidgets('bounce normally and hold still with reduced motion', (
      t,
    ) async {
      await t.pumpWidget(app(false, const IsTypingIndicator()));
      expect(bouncing, findsNWidgets(3));
      await t.pump(const Duration(milliseconds: 500));
      // Still ticking: a frame is scheduled.
      expect(t.binding.hasScheduledFrame, isTrue);

      await t.pumpWidget(app(true, const IsTypingIndicator()));
      await t.pump();
      expect(bouncing, findsNothing);
      // Nothing keeps ticking: the dots are three still circles.
      await t.pump(const Duration(milliseconds: 500));
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(circles, findsNWidgets(3));

      // Turning reduced motion off again starts them once more.
      await t.pumpWidget(app(false, const IsTypingIndicator()));
      await t.pump();
      expect(bouncing, findsNWidgets(3));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('a widget that starts reduced never starts moving', (t) async {
      await t.pumpWidget(app(true, const IsTypingIndicator()));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });

  testWidgets('raft_ui one-off transitions take no time when reduced', (
    t,
  ) async {
    late Duration normal, reduced;
    await t.pumpWidget(
      app(
        false,
        Builder(
          builder: (context) {
            normal = raftMotionDuration(
              context,
              const Duration(milliseconds: 300),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await t.pumpWidget(
      app(
        true,
        Builder(
          builder: (context) {
            reduced = raftMotionDuration(
              context,
              const Duration(milliseconds: 300),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(normal, const Duration(milliseconds: 300));
    expect(reduced, Duration.zero);
  });
}
