import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';

import 'close_dialogs_test.dart' show openFromButton;
import 'support/artifact_fake_client.dart';
import 'support/close_registry_artifacts.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

void main() {
  registerCloseTests(artifactDiscussionSurfaces, {
    'artifact-comments': _openPanel,
    'artifact-comment-actions': (tester, size) async {
      await _openMenu(tester, size);
      return SurfaceProbe(
        isOpen: () => find.text('Delete').evaluate().isNotEmpty,
        scrim: const Offset(10, 140),
      );
    },
    'artifact-review-discard': (tester, size) async {
      await _openPanel(tester, size, withDraft: true);
      await tester.tap(find.text('Discard all').hitTestable());
      await tester.pumpAndSettle();
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('artifact-review-discard-dialog'))
            .evaluate()
            .isNotEmpty,
        back: find.text('Cancel'),
        scrim: const Offset(10, 140),
      );
    },
    'artifact-comment-delete': (tester, size) async {
      await _openMenu(tester, size);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('artifact-comment-delete-dialog'))
            .evaluate()
            .isNotEmpty,
        back: find.text('Cancel'),
        scrim: const Offset(10, 140),
      );
    },
  });
}

Future<SurfaceProbe> _openPanel(
  WidgetTester tester,
  Size size, {
  bool withDraft = false,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  final client = ArtifactFakeClient();
  final workspace = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  addTearDown(workspace.dispose);
  client.answers['GET /artifacts/$artifactId'] = (_) => {
    ...artifactViewerJson(frame: false),
    'capabilities': {'comment': true, 'delete': true},
  };
  client.answers['GET /artifacts/$artifactId/review/drafts'] = (_) => {
    'drafts': [
      if (withDraft)
        {
          'id': 'own-draft',
          'body': [
            {'type': 'text', 'text': 'A private draft'},
          ],
          'version': 1,
          'target': {'scope': 'artifact'},
        },
    ],
  };
  client.answers['GET /artifacts/$artifactId/comments'] = (_) => {
    'comments': [
      {
        'id': 'own-comment',
        'author': artifactActor(),
        'body': [
          {'type': 'text', 'text': 'A comment'},
        ],
        'version': 1,
        'target': {'scope': 'artifact'},
      },
    ],
    'olderCursor': null,
  };
  await openFromButton(
    tester,
    size,
    (context) => unawaited(
      openWorkspaceArtifact(
        context,
        workspace,
        const ArtifactLinkTarget(artifactId),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('artifact-comments-trigger')));
  await tester.pumpAndSettle();
  return SurfaceProbe(
    isOpen: () => find
        .byKey(const ValueKey('artifact-comments-panel'))
        .evaluate()
        .isNotEmpty,
    x: find.byKey(const ValueKey('artifact-comments-close')),
  );
}

Future<void> _openMenu(WidgetTester tester, Size size) async {
  await _openPanel(tester, size);
  await tester.tap(
    find.byKey(const ValueKey('artifact-comment-more-own-comment')),
  );
  await tester.pumpAndSettle();
}
