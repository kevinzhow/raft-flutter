import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/bulk_agent_model_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import '../bulk_agent_model_test.dart' as bulk;
import 'close_support.dart';
import 'close_surface.dart';

class BulkModelCloseHarness {
  const BulkModelCloseHarness(this.probe, this.client);
  final SurfaceProbe probe;
  final bulk.ModelClient client;

  Iterable<(String, String, dynamic)> get writes => client.calls.where(
    (call) => call.$1 == 'PATCH' || call.$2.endsWith('/reset'),
  );
}

/// Opens the production route, including its responsive sheet and PopScope.
Future<BulkModelCloseHarness> openBulkModelClose(
  WidgetTester t,
  Size size, {
  bool review = false,
}) async {
  await t.pumpWidget(const SizedBox.shrink());
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = bulk.ModelClient();
  final workspace = WorkspaceController(client)
    ..server = RaftRecord({'id': 's', 'role': 'owner'});
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await frames(t, 2);
    workspace.dispose();
    await client.stream.close();
    await client.dispose();
  });
  await workspace.services.entityDirectory.refresh(
    WorkspaceEntityKind.agents,
    force: true,
  );
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-bulk-model-close'),
            onPressed: () => unawaited(
              showBulkAgentModelDialog(
                context,
                controller: workspace,
                machine: bulk.machine,
                agentIds: const ['a1'],
                authorized: () => true,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const ValueKey('open-bulk-model-close')));
  await frames(t, 25);
  final dialog = find.byKey(const ValueKey('bulk-change-model-dialog'));
  expect(dialog, findsOneWidget);
  if (review) {
    await t.tap(find.byKey(const ValueKey('bulk-model-next')));
    await frames(t, 20);
    expect(find.byKey(const ValueKey('bulk-model-apply')), findsOneWidget);
  }
  return BulkModelCloseHarness(
    SurfaceProbe(
      isOpen: () => dialog.evaluate().isNotEmpty,
      x: find.descendant(
        of: dialog,
        matching: find.byType(RaftAgentCloseButton),
      ),
      scrim: const Offset(6, 6),
      dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
    ),
    client,
  );
}
