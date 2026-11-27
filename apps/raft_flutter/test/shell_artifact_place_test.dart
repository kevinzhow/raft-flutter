// Web v1.24 ShellArtifactHost (#proj-workspace:#104): an Artifact clicked
// where no channel panel is (a thread Activity opened in its main area,
// Search, Saved) opens in the app shell's own column beside the main area,
// never over the whole window. The page's address holds it (`?artifact=`,
// useArtifactViewerAddress); × and Escape close it and the thread stays.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/artifact_fake_client.dart';
import 'tap_target_matrix_test.dart' show Ctx, mount, msg, threadReplies;
import 'task_surface_test.dart' show flush;

const artifactLink = 'https://a-pt-$artifactUuid.raftusercontent.com/';

/// The matrix's Activity thread host with an Artifact linked in the reply.
Future<Ctx> mountArtifactThread(
  WidgetTester t, [
  String host = 'activity-thread-1280',
]) async {
  SharedPreferences.setMockInitialValues({});
  threadReplies['messages'] = [
    msg(
      'r1',
      't1',
      1,
      'The plan: $artifactLink',
      extra: {'senderName': 'Cindy', 'senderId': 'cindy'},
    ),
  ];
  final c = await mount(
    t,
    TapTargetRegistry.hosts.firstWhere((h) => h.id == host),
  );
  serveArtifact(c);
  ArtifactSession.of(c.w).debugSetEnabled(true);
  await flush(t);
  await t.pumpAndSettle();
  return c;
}

/// The fixture Artifact's summary and viewer, as the server answers them.
void serveArtifact(Ctx c) {
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
}

final card = find.byKey(const ValueKey('artifact-card-title'));
final viewer = find.byType(ArtifactWorkspaceViewer);

void main() {
  for (final escape in [false, true]) {
    testWidgets('Activity thread 1280: an Artifact card opens beside the '
        'thread at its address; ${escape ? 'Escape' : '×'} closes it', (
      t,
    ) async {
      final c = await mountArtifactThread(t);
      final thread = c.w.location;
      expect(card, findsOneWidget);
      await t.tap(card);
      await flush(t);
      await t.pumpAndSettle();

      expect(viewer, findsOneWidget);
      expect(
        ModalRoute.of(t.element(viewer)),
        same(ModalRoute.of(t.element(c.threadView.first))),
        reason: 'in the workspace, not on a window over it',
      );
      expect(c.threadView.hitTestable(), findsWidgets, reason: 'it stays');
      expect(card.hitTestable(), findsOneWidget);
      expect(
        t.getRect(viewer).left,
        greaterThanOrEqualTo(t.getRect(c.threadView.first).right - 1),
      );
      expect(c.w.location.query('artifact'), artifactShort);
      expect(c.w.location.query('open'), thread.query('open'));

      if (escape) {
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await t.tap(find.byKey(const ValueKey('artifact-viewer-close')));
      }
      await flush(t);
      await t.pumpAndSettle();
      expect(viewer, findsNothing);
      expect(c.w.location.query('artifact'), isNull);
      expect(c.w.location.query('open'), thread.query('open'));
      expect(c.threadView.hitTestable(), findsWidgets);
    });
  }

  testWidgets('Activity thread 1280: leaving Activity closes the shell '
      'Artifact', (t) async {
    final c = await mountArtifactThread(t);
    await t.tap(card);
    await flush(t);
    await t.pumpAndSettle();
    expect(viewer, findsOneWidget);
    await t.tap(find.byKey(const Key('rail-chat')));
    await flush(t);
    await t.pumpAndSettle();
    expect(viewer, findsNothing);
    expect(c.w.location.query('artifact'), isNull);
  });
}
