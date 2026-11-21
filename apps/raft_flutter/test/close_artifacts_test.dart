import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/artifact_fake_client.dart';
import 'support/close_registry_artifacts.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart' show tapAndSettle;
import 'support/close_surface.dart';
import 'support/fake_artifact_webview.dart';

void main() {
  setUp(() {
    FakeArtifactWebView.reset();
    WebViewPlatform.instance = FakeArtifactWebView();
  });
  final harness = <String, OpenSurface>{
    'workspace-artifact-viewer': (t, size) async {
      final client = ArtifactFakeClient();
      client.answers['GET /artifacts/$artifactId'] = (_) =>
          artifactViewerJson(frame: false);
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
      addTearDown(w.dispose);
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          openWorkspaceArtifact(
            context,
            w,
            const ArtifactLinkTarget(artifactId),
          ),
        ),
      );
      final viewer = find.byKey(const ValueKey('artifact-workspace-viewer'));
      return SurfaceProbe(
        isOpen: () => viewer.evaluate().isNotEmpty,
        x: find.descendant(of: find.byType(RaftLightboxHeader), matching: anyX),
        back: find.byKey(const ValueKey('artifact-viewer-close')),
        scrim: size.width < 768 ? null : const Offset(6, 6),
      );
    },
    'artifact-delete-confirm': (t, size) async {
      await _openViewerAction(t, size, 'Delete');
      final dialog = find.byKey(const ValueKey('artifact-delete-dialog'));
      return SurfaceProbe(
        isOpen: () => _viewerChildIsOpen(dialog),
        x: find.descendant(of: dialog, matching: anyX),
        scrim: const Offset(6, 6),
        dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
      );
    },
    'artifact-display-report': (t, size) async {
      await _openViewerAction(t, size, "Doesn't display well here");
      final panel = find.byKey(const ValueKey('artifact-comments-panel'));
      final phone = size.width < RaftLayoutMetrics.desktopBreakpoint;
      return SurfaceProbe(
        isOpen: () => _viewerChildIsOpen(panel),
        x: find.byKey(const ValueKey('artifact-comments-close')),
        scrim: phone ? const Offset(6, 6) : null,
        dragHandle: phone
            ? find.byKey(const ValueKey('raft-sheet-handle'))
            : null,
      );
    },
  };
  registerCloseTests(artifactSurfaces, harness);
  registerNoScrimTests(artifactSurfaces, harness);
}

final _viewer = find.byKey(const ValueKey('artifact-workspace-viewer'));

bool _viewerChildIsOpen(Finder child) {
  final open = child.evaluate().isNotEmpty;
  if (!open) expect(_viewer.hitTestable(), findsOneWidget);
  return open;
}

Future<void> _openViewerAction(WidgetTester t, Size size, String label) async {
  // Each dismissal keeps the Viewer alive. Start again from its entry point.
  await t.pumpWidget(const SizedBox.shrink());
  const artifact = '/artifacts/$artifactId';
  final client = ArtifactFakeClient();
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    w.dispose();
    await client.dispose();
    expect(client.requestAuthorization['GET $artifact'], isTrue);
    expect(
      client.requests.where(
        (request) =>
            request.startsWith('DELETE $artifact') ||
            request.startsWith('POST $artifact/'),
      ),
      isEmpty,
    );
  });
  client.answers.addAll({
    'GET $artifact': (_) => artifactViewerJson(
      card: artifactCardJson(kind: 'text'),
      files: [
        {'path': 'probe.txt', 'kind': 'text', 'entry': true},
      ],
      frame: false,
    ),
    'GET $artifact/files/probe.txt?version=1': (_) => 'Artifact text',
    'GET $artifact/comments': (_) => {'comments': []},
    'GET $artifact/will-notify': (_) => {'recipients': []},
    'GET $artifact/review/drafts': (_) => {'drafts': []},
  });
  await openFromButton(
    t,
    size,
    (context) => unawaited(
      openWorkspaceArtifact(context, w, const ArtifactLinkTarget(artifactId)),
    ),
  );
  await tapAndSettle(
    t,
    find.byKey(const ValueKey('artifact-viewer-menu-trigger')).hitTestable(),
  );
  await tapAndSettle(t, find.text(label).hitTestable());
}
