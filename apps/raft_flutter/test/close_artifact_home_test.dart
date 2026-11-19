import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard_data.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard_filter.dart';
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
            case 'artifact-dashboard-page':
            case 'artifact-public-page':
            case 'public-artifact-menu':
              unawaited(
                Navigator.of(context).push<void>(
                  PageRouteBuilder(
                    pageBuilder: (context, _, _) {
                      final back = Navigator.of(context).pop;
                      return surface.id != 'artifact-dashboard-page'
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
            case 'artifact-dashboard-filter':
              unawaited(
                showArtifactDashboardFilter(
                  context,
                  ArtifactDashboardApi(client),
                  authors: true,
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
          scrim: const Offset(10, 140),
        );
      },
  };
  registerCloseTests(artifactHomeSurfaces, harnesses);
  registerNoScrimTests(artifactHomeSurfaces, harnesses);
}
