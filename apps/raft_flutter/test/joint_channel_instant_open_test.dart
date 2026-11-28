import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart';

void main() {
  testWidgets('the joint channel "+" opens from the loaded directory without '
      'waiting on the network', (t) async {
    final (w, api) = await mountWorkspace(t, const Size(1280, 800));
    api.routes['GET /agents'] = (_) => [
      {'id': 'a1', 'name': 'helper', 'displayName': 'Helper'},
    ];
    api.routes['GET /servers/s1/members'] = (_) => [
      {'userId': 'u2', 'name': 'bob', 'displayName': 'Bob'},
    ];
    await t.runAsync(() async {
      for (final kind in [
        WorkspaceEntityKind.agents,
        WorkspaceEntityKind.members,
      ]) {
        await w.entityDirectory.refresh(kind, force: true);
      }
    });
    expect(w.entityDirectory.state(WorkspaceEntityKind.members).loaded, true);

    // From here on both lists would hang forever if requested.
    var requests = 0;
    Future<dynamic> never(_) {
      requests++;
      return Completer<dynamic>().future;
    }

    api.routes['GET /agents'] = never;
    api.routes['GET /servers/s1/members'] = never;
    unawaited(
      CreateJointChannelDialog.show(
        t.element(find.byType(WorkspaceView)),
        controller: w,
      ),
    );
    await frames(t, 6);
    expect(find.byType(CreateJointChannelDialog), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('the phone joint form pins Create in the sheet header', (
    t,
  ) async {
    final (w, _) = await mountWorkspace(t, const Size(390, 844));
    unawaited(
      CreateJointChannelDialog.show(
        t.element(find.byType(WorkspaceView)),
        controller: w,
      ),
    );
    await frames(t, 8);
    final sheet = find.byType(RaftFormSheet);
    final head = find.byKey(const ValueKey('raft-form-sheet-head'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(
        of: head,
        matching: find.byKey(const ValueKey('joint-create-submit')),
      ),
      findsOneWidget,
    );
    await t.binding.handlePopRoute();
    await frames(t, 8);
    expect(sheet, findsNothing);
    expect(find.byType(WorkspaceView), findsOneWidget);
  });
}
