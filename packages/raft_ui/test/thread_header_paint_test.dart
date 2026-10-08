import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Actual original mounted ThreadPanel safe-point samples, all six contexts:
// reports/thread-header-border-source-20261009/receipt.json and
// reports/ink10-browser-paint-diagnostic-20261009/receipt.json.
void main() {
  for (final width in [390.0, 957.0]) {
    for (final (family, dark) in [
      (RaftFamily.brutal, false),
      (RaftFamily.elegant, false),
      (RaftFamily.elegant, true),
    ]) {
      testWidgets('mounted header rule paint $width/$family/$dark', (t) async {
        final key = GlobalKey();
        await t.binding.setSurfaceSize(Size(width, 100));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: RepaintBoundary(
              key: key,
              child: RaftConversationSurface(
                role: RaftConversationSurfaceRole.threadTimeline,
                child: Column(
                  children: [
                    RaftThreadHeader(
                      presentation: RaftThreadPresentation.side,
                      viewportWidth: width,
                      viewportHeight: 720,
                      threadLabel: 'Thread',
                      jumpLabel: 'First message',
                      backLabel: 'Back',
                      closeLabel: 'Close',
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pump();
        final header = find.byType(RaftThreadHeader);
        final height = family == RaftFamily.brutal ? 62 : 56;
        expect(t.getSize(header).height, height);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            List<int> rgb(int y) => [
              for (var c = 0; c < 3; c++)
                data.getUint8((y * image.width + 200) * 4 + c),
            ];
            final expected = family == RaftFamily.brutal
                ? [0, 0, 0]
                : !dark
                ? [229, 229, 226]
                // Dark rule: --ink-10 oklch(0.985 0.004 106.42 / 0.1) =
                // rgb(250 250 247 / .1) over layer-canvas-muted (13 13 11).
                : width < 768
                ? [37, 37, 35]
                : [49, 49, 47];
            expect(rgb(height - 1), expected);
            if (family == RaftFamily.brutal) expect(rgb(height - 2), expected);
            expect(
              rgb(height - (family == RaftFamily.brutal ? 3 : 2)),
              dark
                  ? width < 768
                        ? [13, 13, 11]
                        : [27, 27, 25]
                  : family == RaftFamily.elegant && width < 768
                  ? [248, 248, 247]
                  : [255, 255, 255],
            );
          } finally {
            image.dispose();
          }
        });
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      });
    }
  }
}
