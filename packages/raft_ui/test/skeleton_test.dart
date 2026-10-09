import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

class _VisibleShadowsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _VisibleShadowsBinding();
  for (final family in RaftFamily.values) {
    testWidgets('circle skeleton paints the source avatar rim: $family', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: const ColoredBox(
                    color: Colors.white,
                    child: RaftSkeleton(
                      variant: RaftSkeletonVariant.circle,
                      width: 32,
                      height: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      expect(boundary.size, const Size(32, 32));
      await tester.runAsync(() async {
        final full = await boundary.toImage(pixelRatio: 3);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Offset.zero & Size(full.width.toDouble(), full.height.toDouble()),
          Paint()..color = Colors.white,
        );
        canvas.drawImageRect(
          full,
          Offset.zero & Size(full.width.toDouble(), full.height.toDouble()),
          Offset.zero & Size(full.width.toDouble(), full.height.toDouble()),
          Paint()..filterQuality = FilterQuality.none,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(full.width, full.height);
        picture.dispose();
        full.dispose();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int red(int x, int y) => bytes.getUint8((y * image.width + x) * 4);
        expect(
          red(48, 2),
          lessThan(32),
          reason: 'The black two-pixel rim must paint.',
        );
        expect(
          red(48, 48),
          inInclusiveRange(240, 244),
          reason: 'The inner black/5 fill must paint.',
        );
        image.dispose();
      });
    });
  }
  testWidgets(
    'skeleton avatar remains painted in a bounded scrolling row frame',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: RepaintBoundary(
            key: key,
            child: Align(
              alignment: Alignment.topLeft,
              child: ClipRect(
                child: Container(
                  width: 342,
                  height: 150,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.topLeft,
                  child: MediaQuery(
                    data: const MediaQueryData(disableAnimations: true),
                    child: const OverflowBox(
                      alignment: Alignment.topLeft,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RaftSkeletonRow(
                            avatar: true,
                            avatarSize: 20,
                            gap: 12,
                            lineWidths: [128, 80],
                          ),
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
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final full = await boundary.toImage(pixelRatio: 3);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Offset.zero & Size(full.width.toDouble(), full.height.toDouble()),
          Paint()..color = Colors.white,
        );
        canvas.drawImageRect(
          full,
          Offset.zero & Size(full.width.toDouble(), full.height.toDouble()),
          Offset.zero & Size(full.width.toDouble(), full.height.toDouble()),
          Paint()..filterQuality = FilterQuality.none,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(full.width, full.height);
        picture.dispose();
        full.dispose();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int red(int x, int y) => bytes.getUint8((y * image.width + x) * 4);
        expect(
          red(78, 65),
          lessThan(32),
          reason: 'Avatar rim must survive its ancestor overflow/clip.',
        );
        image.dispose();
      });
    },
  );

  testWidgets('black/10 skeleton uses the source 8-bit alpha on white', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: const ColoredBox(
                color: Colors.white,
                child: RaftSkeleton(width: 100, height: 20),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(bytes.getUint8((10 * image.width + 50) * 4), 229);
      image.dispose();
    });
  });
}
