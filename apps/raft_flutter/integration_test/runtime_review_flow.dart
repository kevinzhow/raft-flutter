import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> verifyRuntimeReview(
  WidgetTester tester,
  WorkspaceController w,
  Map proof, {
  required Future<void> Function(String) section,
  required Future<void> Function(String) capture,
}) async {
  final originalServer = w.server!, originalChannel = w.channel;
  final originalSection = w.section;
  Future<void> wait(bool Function() condition) async {
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (condition()) return;
    }
    throw TestFailure(
      'Native connected Computer runtime review did not reach the required state.',
    );
  }

  try {
    await w.recoverMembership();
    await w.selectServer(
      w.servers.singleWhere((s) => s.id == proof['serverId']),
    );
    final rows =
        (await w.query('/servers/${w.server!.id}/machines'))['machines']
            as List;
    final computer = rows.cast<Map>().singleWhere(
      (m) => m['id'] == proof['machineId'],
    );
    expect(computer['status'], 'online');
    expect(computer['isComputer'], true);
    await section('agents');
    await tester.tap(find.text('Create managed agent'));
    await wait(
      () => find
          .textContaining('Isolated Flutter runtime proof')
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(find.textContaining('Isolated Flutter runtime proof'));
    await wait(() => find.text('codex').evaluate().isNotEmpty);
    await tester.tap(find.text('codex'));
    await wait(
      () =>
          find.byType(RuntimeFormDialog).evaluate().isNotEmpty &&
          find.byKey(const ValueKey('runtime-model')).evaluate().isNotEmpty,
    );
    final fields = find.descendant(
      of: find.byType(RuntimeFormDialog),
      matching: find.byType(TextField),
    );
    final name = fields.first;
    await tester.enterText(name, 'Runtime review without creation');
    final model = tester.widget<TextField>(
      find.byKey(const ValueKey('runtime-model')),
    );
    expect(model.controller!.text, isNotEmpty);
    final environment = find.byKey(const ValueKey('runtime-envVars'));
    await tester.ensureVisible(environment);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(environment, 'invalid line without equals');
    await tester.tap(find.widgetWithText(RaftButton, 'Create'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RuntimeFormDialog), findsOneWidget);
    expect(
      (await w.query('/agents') as List),
      isEmpty,
      reason: 'Invalid environment text must never create an agent.',
    );
    await tester.enterText(environment, 'NATIVE_TEXT=中文 日本語 = unchanged');
    await tester.pump(const Duration(milliseconds: 300));
    await capture('linux-live-runtime-form');
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect((await w.query('/agents') as List), isEmpty);
  } finally {
    await w.selectServer(originalServer);
    w.setSection(originalSection);
    if (originalChannel != null) await w.selectChannel(originalChannel);
    await tester.pump(const Duration(milliseconds: 300));
  }
}
