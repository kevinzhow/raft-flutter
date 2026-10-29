// The three ways to show a running copy on the incoming-share page, rendered
// from the real raft_ui widgets in the three themes. With SHARE_PROGRESS_OUT
// set the cells are written as PNGs (the mock-up sheet is assembled from them);
// without it the test only checks that every cell builds and states its wait.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/share_progress_previews.dart';
import 'package:raft_ui/test_themes.dart';

import 'flutter_test_config.dart' show leakDebt;

const _rows = <(String, RaftShareWaitOption, RaftShareWaitScenario)>[
  ('A-continued', RaftShareWaitOption.button, RaftShareWaitScenario.continued),
  ('A-failed', RaftShareWaitOption.button, RaftShareWaitScenario.failed),
  ('B-copying', RaftShareWaitOption.card, RaftShareWaitScenario.copying),
  ('B-continued', RaftShareWaitOption.card, RaftShareWaitScenario.continued),
  ('B-failed', RaftShareWaitOption.card, RaftShareWaitScenario.failed),
  ('C-copying', RaftShareWaitOption.composer, RaftShareWaitScenario.copying),
  ('C-failed', RaftShareWaitOption.composer, RaftShareWaitScenario.failed),
];

void main() {
  // Leak debt (share flow): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<RaftTransferProgress?>']);
  final out = Platform.environment['SHARE_PROGRESS_OUT'];
  setUpAll(() async {
    // Rendering the mock-up sheet needs the real faces (the test engine draws
    // undeclared fonts as blocks).
    if (out == null) return;
    final root = Directory('assets/fonts').existsSync()
        ? 'assets/fonts'
        : 'packages/raft_ui/assets/fonts';
    for (final family in const [
      'SpaceGrotesk',
      'SpaceMono',
      'HankenGrotesk',
      'Geist',
      'GeistMono',
      'Inter',
    ]) {
      final loader = FontLoader('packages/raft_ui/$family')
        ..addFont(
          File('$root/$family.ttf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    final theme = dark ? 'dark' : 'elegant';
    for (final (name, option, scenario) in _rows) {
      testWidgets('share wait option $name ($theme)', (t) async {
        t.view.physicalSize = const Size(412, 720) * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        final capture = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RepaintBoundary(
                key: capture,
                child: incomingShareWaitPreview(
                  option: option,
                  scenario: scenario,
                ),
              ),
            ),
          ),
        );
        // The transfer bars sweep forever: advance a fixed time, never settle.
        await t.pump(const Duration(milliseconds: 400));
        if (option == RaftShareWaitOption.composer) {
          expect(find.byType(RaftComposerAttachments), findsOneWidget);
        } else {
          expect(find.byType(RaftForwardSharePreview), findsOneWidget);
          expect(
            find.byType(RaftTransferBar),
            scenario == RaftShareWaitScenario.copying &&
                    option == RaftShareWaitOption.button
                ? findsNothing
                : findsWidgets,
          );
        }
        if (out != null) {
          await t.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$out/$name-$theme.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
      });
    }
  }
}
