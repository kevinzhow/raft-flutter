import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';
import 'package:raft_flutter/features/artifacts/artifact_forward_dialog.dart';
import 'package:raft_flutter/features/artifacts/artifact_manage_dialogs.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_public_page.dart';
import 'package:raft_flutter/features/artifacts/artifact_sharing_api.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/artifact_fake_client.dart';
import 'support/close_registry_artifacts.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

void main() {
  final harnesses = <String, OpenSurface>{
    for (final surface in artifactHomeSurfaces)
      surface.id: (tester, size) async {
        await tester.pumpWidget(const SizedBox.shrink());
        final client = ArtifactFakeClient();
        final card = artifactCardJson(title: 'Collection artifact');
        client.answers['GET /artifacts/dashboard/all?sort=opened'] = (_) => {
          'rows': [
            if (surface.id == 'artifact-collection-viewer') {'card': card},
          ],
        };
        client.answers['GET /artifacts/$artifactId'] = (_) =>
            artifactViewerJson(card: card, frame: false);
        client.answers['GET /artifacts/dashboard/conversations'] = (_) => {
          'conversations': [],
        };
        client.answers['GET /public/artifacts/$artifactId'] = (_) => {
          'title': 'Public roadmap',
          'kind': 'html',
          'version': {'number': 1},
        };
        final workspace = WorkspaceController(client)
          ..server = RaftRecord({'id': 's1', 'role': 'owner'});
        addTearDown(client.ingress.close);
        addTearDown(workspace.dispose);
        final data = ArtifactViewerData.fromJson(artifactViewerJson())!;
        await openFromButton(tester, size, (context) {
          switch (surface.id) {
            case 'artifact-collection-viewer':
            case 'artifact-dashboard-filter':
            case 'artifact-dashboard-page':
            case 'artifact-public-page':
            case 'public-artifact-menu':
              unawaited(
                Navigator.of(context).push<void>(
                  PageRouteBuilder(
                    pageBuilder: (context, _, _) {
                      final back = Navigator.of(context).pop;
                      return surface.id != 'artifact-dashboard-page' &&
                              surface.id != 'artifact-dashboard-filter' &&
                              surface.id != 'artifact-collection-viewer'
                          ? ArtifactPublicPage(
                              client: client,
                              id: artifactId,
                              onBack: back,
                              onSignIn: back,
                            )
                          : Scaffold(
                              body: ArtifactDashboard(
                                workspace: workspace,
                                onBack:
                                    size.width < raftBreakpointWidth(context)
                                    ? back
                                    : null,
                              ),
                            );
                    },
                  ),
                ),
              );
            case 'artifact-manage-dialog':
              unawaited(
                showArtifactManageDialog(
                  context,
                  api: ArtifactSharingApi(client),
                  data: data,
                  action: ArtifactManageAction.rename,
                  current: () => true,
                ),
              );
            case 'artifact-forward-dialog':
              unawaited(
                showArtifactForwardDialog(
                  context,
                  workspace: workspace,
                  card: data.card,
                  current: () => true,
                ),
              );
          }
        });
        if (surface.id == 'artifact-collection-viewer') {
          await tester.tap(
            find.byKey(ValueKey('artifact-dashboard-open-$artifactId')),
          );
          await frames(tester);
          final close = find.byKey(const ValueKey('artifact-viewer-close'));
          return SurfaceProbe(
            isOpen: () => close.evaluate().isNotEmpty,
            back: close,
            x: close,
          );
        }
        if (surface.id == 'artifact-dashboard-filter') {
          await tester.tap(
            find.byKey(const Key('artifacts-filter-conversation')),
          );
          await frames(tester);
        }
        if (surface.id == 'public-artifact-menu') {
          await tester.tap(find.byKey(const Key('public-artifact-more')));
          await frames(tester);
        }
        if (surface.id == 'artifact-dashboard-page' ||
            surface.id == 'artifact-public-page') {
          return SurfaceProbe(
            isOpen: () => find
                .byType(
                  surface.id == 'artifact-public-page'
                      ? ArtifactPublicPage
                      : ArtifactDashboard,
                )
                .evaluate()
                .isNotEmpty,
            back: find.byTooltip('Back'),
          );
        }
        return SurfaceProbe(
          isOpen: () => find.byKey(ValueKey(surface.id)).evaluate().isNotEmpty,
          x: anyX,
          back: find.widgetWithText(RaftButton, 'Cancel'),
          scrim: const Offset(10, 140),
        );
      },
  };
  registerCloseTests(artifactHomeSurfaces, harnesses);
  registerNoScrimTests(artifactHomeSurfaces, harnesses);
}
