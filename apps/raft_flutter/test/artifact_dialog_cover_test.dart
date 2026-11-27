// Web v1.24 ArtifactCoverViewer (artifactViewerStore.ts ArtifactPlace :22-23,
// coverOf :233-238): an Artifact clicked in a task's dialog on a wide window
// covers that dialog's card, not the window; × closes it back to the task.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shell_artifact_place_test.dart' show artifactLink, card, viewer;
import 'support/artifact_fake_client.dart';
import 'tap_target_matrix_test.dart' show Ctx, mount, msg;
import 'task_surface_test.dart' show flush;

final frame = find.byKey(const ValueKey('task-thread-modal'));

/// The matrix's chat at 1280 with its task's dialog open; the task's
/// conversation links an Artifact.
Future<Ctx> mountTaskDialog(WidgetTester t, [TapHost? host]) async {
  SharedPreferences.setMockInitialValues({});
  final c = await mount(
    t,
    host ?? TapTargetRegistry.hosts.firstWhere((h) => h.id == 'chat-1280'),
  );
  c.api.routes['GET /messages/channel/task-thread'] = (_) => {
    'messages': [msg('tr1', 'task-thread', 1, 'The plan: $artifactLink')],
  };
  c.api.routes['POST /objects/summaries'] = (_) => {
    'kind': 'artifact',
    'summaries': [
      {
        'ref': {'id': artifactId},
        'ok': true,
        'summary': artifactCardJson(kind: 'text', title: 'Launch plan'),
      },
    ],
  };
  c.api.routes['GET /artifacts/$artifactId'] = (_) => artifactViewerJson(
    card: artifactCardJson(kind: 'text', title: 'Launch plan'),
    files: [
      {'path': 'plan.txt', 'kind': 'text', 'entry': true},
    ],
    frame: false,
  );
  c.api.routes['GET /artifacts/$artifactId/files/plan.txt?version=1'] = (_) =>
      'The plan';
  // The task's conversation has a session of its own: it asks the server.
  c.api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'workspace_artifacts_v0', 'enabled': true},
    ],
  };
  ArtifactSession.of(c.w).debugSetEnabled(true);
  await t.tap(find.byKey(const ValueKey('message-task-task-parent')));
  await flush(t);
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('task dialog 1280: an Artifact card covers the dialog card, not '
      'the window; × gives the task back', (t) async {
    final c = await mountTaskDialog(t);
    expect(frame, findsOneWidget);
    final inDialog = find.descendant(of: frame, matching: card);
    expect(inDialog, findsOneWidget);
    await t.tap(inDialog);
    await flush(t);
    await t.pumpAndSettle();

    expect(viewer, findsOneWidget);
    expect(
      find.descendant(of: frame, matching: viewer),
      findsOneWidget,
      reason: 'over the dialog card, inside it',
    );
    final window = t.view.physicalSize / t.view.devicePixelRatio;
    expect(t.getRect(viewer).width, lessThan(window.width));
    expect(
      ModalRoute.of(t.element(viewer)),
      same(ModalRoute.of(t.element(frame))),
      reason: 'no window route over the workspace',
    );
    expect(inDialog.hitTestable(), findsNothing, reason: 'it covers the card');
    expect(c.w.location.query('task'), isNotNull);

    await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
    await flush(t);
    await t.pumpAndSettle();
    expect(viewer, findsNothing);
    expect(frame, findsOneWidget, reason: 'the task stays open');
    expect(inDialog.hitTestable(), findsOneWidget);
  });
}
