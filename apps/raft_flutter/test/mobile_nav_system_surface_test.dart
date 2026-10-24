import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/mobile_workspace_navigation.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('native docked surface fills system inset dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      final client = RaftClient(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
      addTearDown(w.dispose);
      final key = GlobalKey();
      final theme = raftTheme(dark: dark)
          .copyWith(platform: TargetPlatform.android);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: theme.extension<RaftTokens>()!.canvas,
                  child: WorkspaceMobileTabBar(
                    controller: w,
                    selectedId: 'chat',
                    onSelected: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(key)), const Size(390, 86));
      final expected = theme.extension<RaftTokens>()!.colors['layer-card']!;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final actual = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final i = ((image.height - 5) * image.width + 5) * 4;
        final pixel = Color.fromARGB(
          bytes.getUint8(i + 3),
          bytes.getUint8(i),
          bytes.getUint8(i + 1),
          bytes.getUint8(i + 2),
        );
        image.dispose();
        return pixel;
      });
      expect(
        actual,
        expected,
        reason: 'the stable system inset belongs to the bottom bar surface',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
