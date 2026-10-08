import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/main.dart' as app;

import 'sidebar_flow.dart';
import 'workspace_test.dart' as workspace;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('actual native reversible sidebar preferences and drag', (
    tester,
  ) async {
    final fixtureFile = File(const String.fromEnvironment('RAFT_TEST_CONFIG'));
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!await fixtureFile.exists()) {
        if (DateTime.now().isAfter(deadline)) {
          throw TestFailure('Private test fixture was not installed.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });
    final fixture = jsonDecode(fixtureFile.readAsStringSync()) as Map;
    final report = Directory(const String.fromEnvironment('RAFT_TEST_REPORT'));
    await report.create(recursive: true);
    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 300 && !ready(); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(ready(), true);
    }

    await tester.pumpWidget(app.RaftApp(sessionStore: MemorySessionStore()));
    await until(
      () => find.byKey(const Key('login-email')).evaluate().isNotEmpty,
    );
    for (final field in ['origin', 'email', 'password']) {
      await tester.tap(find.byKey(Key('login-$field')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(Key('login-$field')), fixture[field]);
    }
    await tester.tap(find.byKey(const Key('login-submit')));
    await until(() => find.byType(WorkspaceView).evaluate().isNotEmpty);
    final w = tester
        .widget<WorkspaceView>(find.byType(WorkspaceView).first)
        .controller;
    await until(() => !w.loading && w.server != null);
    try {
      await verifySidebarFlow(
        tester,
        w,
        section: (name) => workspace.section(tester, name),
        capture: (name) async {
          await tester.pump(const Duration(milliseconds: 300));
          final image =
              await (app.raftScreenshotKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('${report.path}/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        },
      );
      await File('${report.path}/sidebar-result.json').writeAsString(
        jsonEncode({
          'platform': const String.fromEnvironment(
            'RAFT_TEST_PLATFORM',
            defaultValue: 'linux',
          ),
          'completed': true,
          'flow': 'actual-login-preferences-pointer-drag-restored',
          'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
        }),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
