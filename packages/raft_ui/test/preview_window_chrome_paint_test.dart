import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// The title strip belongs to the window's existing workspace route. Reserving
// its bounds in a preview is insufficient if Navigator stops painting it.
void _onSearch() {}

void main() {
  for (final dark in [false, true]) {
    for (final kind in ['media', 'page', 'dialog']) {
      testWidgets(
        '$kind dark=$dark preview keeps the mounted title strip painted',
        (t) async {
          final navigator = GlobalKey<NavigatorState>();
          final canvas = GlobalKey();
          addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
          await t.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              theme: raftTheme(dark: dark),
              builder: (context, child) => RaftWindowChromeScope(
                overlayInsets: const EdgeInsets.only(top: 48),
                child: RepaintBoundary(key: canvas, child: child!),
              ),
              home: const Scaffold(
                body: Column(
                  children: [
                    RaftWorkspaceTopBar(
                      workspace: Text('Project'),
                      onSearch: _onSearch,
                    ),
                    Expanded(child: Center(child: Text('workspace'))),
                  ],
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          var frame = 0;
          Future<int> sample() async => (await t.runAsync(() async {
            final boundary =
                canvas.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final rgba = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final at = (4 * image.width + 780) * 4;
              final color =
                  (rgba.getUint8(at + 3) << 24) |
                  (rgba.getUint8(at) << 16) |
                  (rgba.getUint8(at + 1) << 8) |
                  rgba.getUint8(at + 2);
              final out = Platform.environment['RAFT_PREVIEW_CHROME_CAPTURE'];
              if (out != null) {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                await Directory(out).create(recursive: true);
                await File('$out/$kind-dark=$dark-${frame++}.png')
                    .writeAsBytes(bytes.buffer.asUint8List());
              }
              return color;
            } finally {
              image.dispose();
            }
          }))!;

          final before = await sample();
          Widget preview(BuildContext context) => const ColoredBox(
            color: Colors.white,
            child: Align(alignment: Alignment.topLeft, child: Text('preview')),
          );
          final context = navigator.currentContext!;
          final ModalRoute<void> route = switch (kind) {
            'media' => RaftMediaBrowserRoute<void>(builder: preview),
            'page' => RaftPreviewPageRoute<void>(builder: preview),
            _ => RaftFullBleedDialogRoute<void>(
              context: context,
              builder: preview,
            ),
          };
          unawaited(navigator.currentState!.push(route));
          final frames = <int>[];
          await t.pump();
          for (final delay in [16, 60, 120, 400]) {
            await t.pump(Duration(milliseconds: delay));
            frames.add(await sample());
          }
          if (route is RaftMediaBrowserRoute<void>) {
            route.setTranslucent(true);
            await t.pump();
            route.setTranslucent(false);
            await t.pump();
            frames.add(await sample());
          }
          final previewTop = t.getTopLeft(find.text('preview')).dy;
          navigator.currentState!.pop();
          await t.pump();
          for (final delay in [16, 60, 120, 400]) {
            await t.pump(Duration(milliseconds: delay));
            frames.add(await sample());
          }
          await t.pumpAndSettle();
          frames.add(await sample());
          expect(previewTop, greaterThanOrEqualTo(48));
          expect(
            frames,
            everyElement(before),
            reason: 'the original title strip keeps its color during open, rest, drag reset and close',
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
