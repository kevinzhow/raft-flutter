import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/html_region_marker.dart';
import 'package:raft_ui/test_themes.dart';

import 'fixtures/html_region_native_fixture.dart';

Future<RaftHtmlNativeRegionHint> waitForHint(
  WidgetTester tester,
  NativeGeometry controller,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    final hint = controller.frames.last.hint;
    if (hint != null) return hint;
  }
  throw StateError('Canonical hint raster did not complete');
}

void main() {
  testWidgets(
    'native marker values come from the same five-theme Flutter recipe and flash animation',
    (tester) async {
      for (final id in raftThemeMatrix([
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ], look: raftLookOf)) {
        for (final dark in [false, true]) {
          if (id == brutalThemePackId && dark) continue;
          final session = RaftAttachmentCommentState()..commentMode = true;
          final controller = NativeGeometry();
          await tester.pumpWidget(
            nativeFrame(
              session,
              controller,
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
            ),
          );
          await tester.pumpAndSettle();
          final frame = controller.frames.last;
          final region = RaftHtmlRegion(
            rect: const Rect.fromLTWH(20, 40, 120, 80),
            viewportWidth: frame.viewport.width,
            document: const Size(2000, 3000),
          );
          expect(await session.jumpAsync(region.anchor), isTrue);
          await tester.pump();
          for (final delay in [
            Duration.zero,
            const Duration(milliseconds: 700),
          ]) {
            await tester.pump(delay);
            final marker = controller.frames.last.markers.single;
            final painter =
                tester
                        .widget<CustomPaint>(
                          find.byKey(const ValueKey('html-region-flash')),
                        )
                        .painter!
                    as RaftHtmlRegionMarkerPainter;
            expect(marker.fill, painter.recipe.fill);
            expect(marker.border, painter.recipe.border);
            expect(marker.strokeWidth, painter.recipe.width);
            expect(marker.radius, painter.recipe.radius);
            expect(
              marker.rect,
              Rect.fromLTWH(
                20 / frame.viewport.width,
                40 / frame.viewport.height,
                120 / frame.viewport.width,
                80 / frame.viewport.height,
              ),
            );
            expect(marker.progress, painter.recipe.progress);
          }
          controller.send(
            controller.frames.last,
            RaftHtmlNativeRegionPhase.down,
            1,
            const Offset(.1, .1),
          );
          controller.send(
            controller.frames.last,
            RaftHtmlNativeRegionPhase.move,
            2,
            const Offset(.3, .3),
          );
          await tester.pump();
          final drag = controller.frames.last.markers.last;
          expect(drag.dashed, isTrue);
          expect(drag.borderSegments, isNotEmpty);
          expect(
            drag.borderSegments.every(
              (rect) =>
                  rect.left >= 0 &&
                  rect.top >= 0 &&
                  rect.right <= 1 &&
                  rect.bottom <= 1,
            ),
            isTrue,
          );
          expect(find.byType(RaftHtmlRegionHint), findsOneWidget);
          expect(
            find.byKey(const ValueKey('html-region-drag')),
            findsOneWidget,
          );
          session.commentMode = false;
          await tester.pump();
          session.commentMode = true;
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          expect(controller.frames.last.markers, isEmpty);
          expect(find.byKey(const ValueKey('html-region-flash')), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await controller.input.close();
          session.dispose();
        }
      }
    },
  );

  testWidgets(
    'canonical hint PNG preserves themed scaled widget geometry within decode limits',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final dark in [false, true]) {
        for (final scale in [1.0, 3.1]) {
          final session = RaftAttachmentCommentState()..commentMode = true;
          final controller = NativeGeometry();
          await tester.pumpWidget(
            nativeFrame(
              session,
              controller,
              theme: raftTheme(dark: dark),
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final hint = await waitForHint(tester, controller);
          expect(
            hint.png.take(8),
            orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]),
          );
          final dimensions = ByteData.sublistView(hint.png);
          final width = dimensions.getUint32(16),
              height = dimensions.getUint32(20);
          expect(
            width * height,
            lessThanOrEqualTo(RaftHtmlNativeRegionHint.maximumPixels),
          );
          expect(
            hint.png.length,
            lessThanOrEqualTo(RaftHtmlNativeRegionHint.maximumBytes),
          );
          final widget = tester.getRect(find.byType(RaftHtmlRegionHint));
          expect(hint.logicalSize.width, greaterThanOrEqualTo(widget.width));
          expect(hint.logicalSize.height, greaterThanOrEqualTo(widget.height));
          expect(hint.logicalOffset.dy, lessThanOrEqualTo(widget.top));
          expect(controller.frames.last.captureEnabled, isTrue);
          await tester.pumpWidget(const SizedBox());
          await controller.input.close();
          session.dispose();
        }
      }
    },
  );
}
