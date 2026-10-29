import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Raft $dark sidebar seam paints over its own background', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: const RaftAdaptiveWorkspace(
                sidebar: SizedBox.expand(),
                rail: SizedBox.expand(),
                content: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final panel = t.getRect(find.byKey(const Key('workspace-sidebar-panel')));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final i = (50 * image.width + panel.right.toInt() - 1) * 4;
        final pixel = [for (var c = 0; c < 3; c++) bytes.getUint8(i + c)];
        // Pinned db5e399f/raft-ui0.7.0 actual sidebar-root border-right:
        // line-seam over layer-sidebar, including the border's own pixel.
        image.dispose();
        expect(pixel, dark ? [74, 74, 72] : [149, 145, 139]);
      });
      await t.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }
}
