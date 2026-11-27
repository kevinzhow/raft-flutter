import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flutter_test_config.dart' show leakDebt;
import '../support/artifact_fake_client.dart';

const _artifact = '/artifacts/$artifactId';

/// The viewer is a channel side column (`ChannelBrowserPlace`) as often as it
/// is the whole window, so "comments beside the artifact or as a sheet" has to
/// be decided on the viewer's own box. Every case here mounts it in a narrow
/// pane inside a 1280x900 desktop window.
void main() {
  // Flutter 3.47.8's modal sheet leaves its drag-end CurvedAnimation undisposed.
  leakDebt(const ['CurvedAnimation']);
  late ArtifactFakeClient client;
  late WorkspaceController workspace;
  late ArtifactSession session;

  final trigger = find.byKey(const Key('artifact-comments-trigger'));
  final panel = find.byKey(const Key('artifact-comments-panel'));
  final sheetHandle = find.byKey(const Key('raft-sheet-handle'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    client = ArtifactFakeClient();
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    session = ArtifactSession.of(workspace);
    client.answers.addAll({
      'GET $_artifact': (_) => {
        ...artifactViewerJson(
          card: artifactCardJson(kind: 'text', version: 1, latest: 1),
          frame: false,
          versions: const [1],
          files: [
            {'path': 'probe.txt', 'kind': 'text', 'entry': true},
          ],
        ),
        'viewer': artifactActor(),
        'capabilities': {'comment': true},
      },
      'GET $_artifact/files/probe.txt?version=1': (_) => 'Artifact text',
      'GET $_artifact/comments': (_) => {'comments': []},
      'GET $_artifact/will-notify': (_) => {'recipients': []},
      'GET $_artifact/review/drafts': (_) => {'drafts': []},
    });
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
  });

  Future<void> mount(WidgetTester t, {required double pane}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1280, 900);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: pane,
                child: ArtifactWorkspaceViewer(
                  session: session,
                  target: ArtifactLinkTarget(artifactId),
                  page: false,
                  inline: true,
                  onClose: () {},
                  operatingSystem: 'linux',
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('a side column too narrow for both shows the discussion over '
      'the artifact inside it, not as a sheet over the window', (t) async {
    // Web ArtifactSurface `fit="measure"` (ArtifactViewer.tsx:226): beside
    // where both fit, else over the content, full height; a sheet only on a
    // phone.
    await mount(t, pane: 560);
    await t.tap(trigger.hitTestable());
    await t.pumpAndSettle();
    expect(panel.hitTestable(), findsOneWidget);
    expect(sheetHandle, findsNothing);
    expect(t.getRect(panel).left, 0);
    expect(t.getRect(panel).right, 560);
  });

  testWidgets('a pane wide enough keeps the discussion beside the artifact', (
    t,
  ) async {
    await mount(t, pane: 900);
    await t.tap(trigger.hitTestable());
    await t.pumpAndSettle();
    expect(panel.hitTestable(), findsOneWidget);
    expect(sheetHandle, findsNothing);
    // The 340 column, inside its own seam border, at the pane's trailing edge.
    expect(t.getSize(panel).width, 339);
    expect(t.getRect(panel).right, 900);
  });
}
