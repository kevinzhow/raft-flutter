import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (dark, expected) in [
    (false, [89, 87, 84, 255]),
    (true, [5, 5, 4, 255]),
  ]) {
    testWidgets('opaque document scrim matches the browser in dark=$dark', (
      tester,
    ) async {
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: raftTheme(dark: dark),
            home: Builder(
              builder: (context) => ColoredBox(
                color: RaftTokens.of(context).ui.layerSidebar,
                child: Center(
                  child: RaftButton(
                    label: 'Open',
                    onPressed: () => showRaftDialog<void>(
                      context: context,
                      browserBackdropBlend: true,
                      builder: (_) => const RaftDialog(title: 'Document'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final rgba = await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final pixels = (await image.toByteData())!;
          return [
            for (var channel = 0; channel < 4; channel++)
              pixels.getUint8(channel),
          ];
        } finally {
          image.dispose();
        }
      });
      expect(rgba, expected);
    });
  }
}
