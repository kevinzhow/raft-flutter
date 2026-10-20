import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Actual original mounted ThreadPanel safe-point samples, all six contexts:
// reports/thread-header-border-source-20261009/receipt.json and
// reports/ink10-browser-paint-diagnostic-20261009/receipt.json.
void main() {
  for (final width in [390.0, 957.0]) {
    for (final (family, dark) in raftThemeMatrix([
      (RaftFamily.brutal, false),
      (RaftFamily.elegant, false),
      (RaftFamily.elegant, true),
    ])) {
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
        // `--shell-header-height`: brutal 62 / elegant 56 at every width (the
        // phone header is Web's PanelHeader, not a shared 56px page header).
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
                // Dark rule --ink-10 over layer-canvas-muted: Chromium paints
                // 36 36 34 (tool/design-source/chrome-oracle.json canvasMuted).
                // v1.21.12 paints the muted canvas at every width.
                : [36, 36, 34];
            expect(rgb(height - 1), expected);
            if (family == RaftFamily.brutal) expect(rgb(height - 2), expected);
            expect(
              rgb(height - (family == RaftFamily.brutal ? 3 : 2)),
              dark
                  ? [13, 13, 11]
                  : family == RaftFamily.elegant
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
