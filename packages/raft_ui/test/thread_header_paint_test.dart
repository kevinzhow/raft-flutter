import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Legacy measured geometry is retained; paint now follows the Raft token roles.
// Earlier original ThreadPanel samples:
// reports/thread-header-border-source-20261009/receipt.json and
// reports/ink10-browser-paint-diagnostic-20261009/receipt.json.
void main() {
  for (final width in [390.0, 957.0]) {
    for (final dark in raftThemeMatrix([false, true])) {
      testWidgets('mounted header rule paint $width/$dark', (t) async {
        final key = GlobalKey();
        await t.binding.setSurfaceSize(Size(width, 100));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
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
        final height = 56;
        expect(t.getSize(header).height, height);
        final tokens = RaftTokens.of(t.element(header));
        // Current Web PanelHeader's paper fill is the shared named role.
        final surface = tokens.colors['layer-panel-header']!;
        List<int> rgbOf(Color c) => [
          (c.r * 255).round(),
          (c.g * 255).round(),
          (c.b * 255).round(),
        ];
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
            final expected = rgbOf(
              Color.alphaBlend(tokens.colors['line-muted']!, surface),
            );
            expect(rgb(height - 1), expected);

            expect(rgb(height - (2)), rgbOf(surface));
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
