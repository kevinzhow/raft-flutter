import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'task_typography_test.dart' show loadTaskFonts;

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} usage sheet has undecorated text and live actions',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await loadTaskFonts(tester);
        final semantics = tester.ensureSemantics();
        final changes = ValueNotifier<int>(0);
        final boundaryKey = GlobalKey();
        var refreshes = 0;
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                theme: raftTheme(dark: dark)
                    .copyWith(platform: TargetPlatform.android),
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      return TextButton(
                        onPressed: () => showRaftRuntimeUsageSheet(
                          context,
                          listenable: changes,
                          data: (_) => RaftRuntimeUsageData(
                            provider: 'Codex',
                            version: '0.162.1',
                            state: 'fresh',
                            updated: '12 minutes ago',
                            footer: changes.value == 0
                                ? 'Cached snapshot only'
                                : 'Requested snapshot',
                            accounts: const [
                              RaftRuntimeUsageAccount(
                                health: 'ok',
                                plan: 'pro',
                                identity: 'fixture@example.invalid',
                                windows: [
                                  RaftRuntimeUsageWindow(
                                    label: '1week',
                                    status: 'ok',
                                    percent: 2,
                                    reset: 'in 7 days',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onRefresh: () {
                            refreshes++;
                            changes.value++;
                          },
                        ),
                        child: const Text('Open usage'),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open usage'));
          await tester.pumpAndSettle();
          final sheet = find.byType(RaftRuntimeUsageSheet);
          expect(sheet, findsOneWidget);
          expect(find.text('Codex usage'), findsOneWidget);
          final output = Platform.environment['RAFT_OVERLAY_EVIDENCE_DIR'];
          if (output != null) {
            await tester.runAsync(() async {
              final image =
                  await (boundaryKey.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              final file = File('$output/$dark.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            });
          }
          final text = find.descendant(
            of: sheet,
            matching: find.byType(RichText),
          );
          expect(text.evaluate().length, greaterThan(8));
          for (final element in text.evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(
              paragraph.text.style?.decoration ?? TextDecoration.none,
              TextDecoration.none,
              reason:
                  'Effective painted style for ${paragraph.text.toPlainText()}',
            );
          }
          await tester.tap(find.byKey(const ValueKey('runtime-usage-refresh')));
          await tester.pumpAndSettle();
          expect(refreshes, 1);
          expect(find.text('Requested snapshot'), findsOneWidget);
          await tester.tap(
            find.descendant(of: sheet, matching: find.byType(RaftCloseButton)),
          );
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          await tester.tap(find.text('Open usage'));
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(8, 8));
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
          changes.dispose();
        }
      },
    );
  }
}
