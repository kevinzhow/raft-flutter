// Shared by the RaftBench integration tests: sign in to the local test stack
// through the real login screen, open Settings > RaftBench, capture the app.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_ui/raft_ui.dart';

const raftbenchReport = String.fromEnvironment(
  'RAFT_TEST_REPORT',
  defaultValue: '/tmp/raftbench-e2e',
);

Map<String, dynamic> raftbenchConfig() => jsonDecode(
  File(const String.fromEnvironment('RAFT_TEST_CONFIG')).readAsStringSync(),
) as Map<String, dynamic>;

Future<void> until(
  WidgetTester t,
  bool Function() ready, {
  int seconds = 30,
  String? what,
}) async {
  for (var i = 0; i < seconds * 5; i++) {
    await t.pump(const Duration(milliseconds: 200));
    if (ready()) return;
  }
  throw TestFailure('Timed out waiting for ${what ?? 'the UI state'}.');
}

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) =>
        (w is Semantics && w.properties.label == label) ||
        (w is RaftProductFormField && w.label == label),
  ),
  matching: find.byType(TextField),
);

final _log = StringBuffer();
void note(String line) {
  _log.writeln('${DateTime.now().toUtc().toIso8601String()} $line');
}

Future<void> writeRunLog(String name) async {
  await Directory(raftbenchReport).create(recursive: true);
  await File('$raftbenchReport/$name').writeAsString(_log.toString());
}

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  final boundary =
      t.renderObject(find.byKey(raftScreenshotKey)) as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(raftbenchReport).create(recursive: true);
    await File('$raftbenchReport/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    note('screenshot $name');
  } finally {
    image.dispose();
  }
}

/// The real login screen against the stack, then the chosen server's workspace.
Future<WorkspaceController> signIn(
  WidgetTester t,
  Map<String, dynamic> cfg,
) async {
  await t.pumpWidget(
    RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: MemorySessionStore(),
    ),
  );
  await until(
    t,
    () => find.byKey(const Key('login-email')).evaluate().isNotEmpty,
    what: 'login',
  );
  await t.tap(find.byKey(const Key('login-server')));
  await t.pumpAndSettle();
  await t.enterText(_field('Server URL'), cfg['origin'] as String);
  await t.tap(find.widgetWithText(RaftButton, 'Save'));
  await until(
    t,
    () => find.byType(RaftFormDialog).evaluate().isEmpty,
    what: 'the server dialog',
  );
  await t.enterText(
    find.byKey(const Key('login-email')),
    cfg['email'] as String,
  );
  await t.enterText(
    find.byKey(const Key('login-password')),
    cfg['password'] as String,
  );
  await t.tap(find.byKey(const Key('login-submit')));
  await until(
    t,
    () {
      if (find.byType(WorkspaceView).evaluate().isNotEmpty) return true;
      final selector = find.byType(GlobalServerSelector);
      if (selector.evaluate().isEmpty) return false;
      final page = t.widget<GlobalServerSelector>(selector);
      return !page.loading && page.servers.isNotEmpty;
    },
    seconds: 60,
    what: 'the workspace',
  );
  if (find.byType(WorkspaceView).evaluate().isEmpty) {
    await t.tap(find.byKey(ValueKey('global-server-${cfg['serverId']}')));
    await until(
      t,
      () => find.byType(WorkspaceView).evaluate().isNotEmpty,
      what: 'the chosen server',
    );
  }
  final w = t
      .widget<WorkspaceView>(find.byType(WorkspaceView).first)
      .controller;
  await until(
    t,
    () => !w.loading && w.channels.isNotEmpty,
    seconds: 60,
    what: 'channels',
  );
  note('signed in as ${w.server?.string('role')} on the chosen server');
  return w;
}

bool phone(WidgetTester t) =>
    t.view.physicalSize.width / t.view.devicePixelRatio < 768;

/// Settings > [tab]: the rail's Settings entry (the tab bar on a phone).
Future<void> openSettingsTab(WidgetTester t, String tab) async {
  final row = find.byKey(ValueKey('workspace-settings-nav-$tab'));
  if (row.evaluate().isEmpty) {
    final back = find.byKey(const Key('mobile-settings-back'));
    if (phone(t) && back.evaluate().isNotEmpty) {
      await t.tap(back);
      await t.pumpAndSettle();
    }
  }
  if (row.evaluate().isEmpty) {
    final entry = phone(t)
        ? find.byKey(const Key('mobile-tab-settings'))
        : find.byKey(const ValueKey('rail-settings'));
    await t.tap(entry);
    await t.pumpAndSettle();
  }
  await until(
    t,
    () => row.evaluate().isNotEmpty,
    what: 'the $tab settings row',
  );
  await t.ensureVisible(row);
  await t.tap(row);
  await t.pumpAndSettle();
}

Future<void> openRaftbench(WidgetTester t) async {
  await openSettingsTab(t, 'raftbench');
  await until(
    t,
    () => find
        .byKey(const ValueKey('raftbench-hosted-analysis'))
        .evaluate()
        .isNotEmpty,
    what: 'the RaftBench page',
  );
  await until(
    t,
    () =>
        find.text('Loading analysis settings…').evaluate().isEmpty &&
        find.text('正在加载分析设置…').evaluate().isEmpty,
    what: 'the dashboard',
  );
  await t.pump(const Duration(seconds: 2));
}
