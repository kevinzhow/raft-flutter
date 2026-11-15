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
  };
  registerCloseTests(artifactSurfaces, harness);
  registerNoScrimTests(artifactSurfaces, harness);
}
