import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });
  final scenarios = [
    (
      name: 'narrow desktop',
      size: const Size(390, 844),
      platform: TargetPlatform.linux,
    ),
    (
      name: 'foldable portrait',
      size: const Size(856, 944),
      platform: TargetPlatform.android,
    ),
    (
      name: 'foldable landscape',
      size: const Size(944, 856),
      platform: TargetPlatform.android,
    ),
  ];
  for (final scenario in scenarios) {
    testWidgets('${scenario.name}: large batch task form submits both titles', (
      t,
    ) async {
      t.view.physicalSize = scenario.size;
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 3.1;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final (workspace, api) = await pageFixture(t);
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      api.routes['POST /tasks/channel/c1'] = (_) => {'tasks': <dynamic>[]};
      var created = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: scenario.platform),
          builder: (context, child) => RaftTextScaling(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-create-task'),
                onPressed: () => unawaited(
                  CreateTaskDialog.show(
                    context,
                    controller: workspace,
                    channelId: 'c1',
                    onCreated: () async {
                      created++;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('open-create-task')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final first = find.byKey(const ValueKey('create-task-title-0'));
      await t.ensureVisible(first);
      await t.enterText(first, 'First task');
      await t.pump();
      final add = find.byKey(const ValueKey('create-task-add-row'));
      await t.ensureVisible(add);
      await t.pumpAndSettle();
      await t.tap(add);
      await t.pumpAndSettle();
      final second = find.byKey(const ValueKey('create-task-title-1'));
      await t.ensureVisible(second);
      await t.enterText(second, 'Second task');
      await t.pump();
      final submit = find.byKey(const ValueKey('create-task-submit'));
      await t.ensureVisible(submit);
      await t.pumpAndSettle();
      final rect = t.getRect(submit);
      await t.tapAt(Offset(rect.right - 2, rect.center.dy));
      await t.pumpAndSettle();
      final requests = api.calls
          .where((r) => r.method == 'POST' && r.path == '/tasks/channel/c1')
          .toList();
      expect(requests, hasLength(1));
      expect(requests.single.data, {
        'tasks': [
          {'title': 'First task'},
          {'title': 'Second task'},
        ],
      });
      expect(created, 1);
      expect(find.byType(CreateTaskDialog), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
