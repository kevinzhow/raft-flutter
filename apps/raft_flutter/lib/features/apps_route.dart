import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import 'app_permission_updates.dart';
import 'artifacts/artifact_dashboard.dart';
import 'artifacts/artifact_session.dart';
import 'integrations_views.dart';

const workspaceCatalogRoutes = {'apps', 'artifacts'};

Widget listenWorkspaceRail(
  WorkspaceController workspace,
  Widget Function() build,
) => AppPermissionUpdatesHost(
  workspace: workspace,
  child: ListenableBuilder(
    listenable: Listenable.merge([
      ArtifactSession.of(workspace),
      AppPermissionUpdates.of(workspace),
    ]),
    builder: (_, _) => build(),
  ),
);

Widget workspaceCatalogPage(
  String route,
  WorkspaceController workspace,
  String authority,
  VoidCallback? onBack,
) => route == 'apps'
    ? AppsRoute(key: ValueKey(authority), workspace: workspace, onBack: onBack)
    : ArtifactDashboard(
        key: ValueKey(authority),
        workspace: workspace,
        onBack: onBack,
      );

RaftLocation appsRouteLocation(Uri uri, {required bool guest}) {
  final location = RaftLocation.fromUri(RaftLocation.canonicalLegacy(uri));
  if (guest && location.route == RaftRoute.apps) {
    return RaftLocation.at(
      serverSlug: location.serverSlug,
      route: RaftRoute.home,
    );
  }
  if (location.route != RaftRoute.settings) return location;
  final slug = location.settingsPath.firstOrNull;
  if (!{'integrations', 'applications', 'mcp', 'mcp-servers'}.contains(slug)) {
    return location;
  }
  return RaftLocation.fromUri(
    location.uri.replace(
      pathSegments: [
        '',
        's',
        location.serverSlug,
        guest ? 'settings' : 'apps',
        if (guest) 'applications',
      ],
    ),
  );
}

class AppsRoute extends StatelessWidget {
  const AppsRoute({super.key, required this.workspace, this.onBack});

  final WorkspaceController workspace;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canvas = RaftTokens.of(context).canvas;
    return ColoredBox(
      key: const Key('apps-page'),
      color: canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            title: raftText(context, 'Apps'),
            background: canvas,
            onBack: onBack,
            backKey: const Key('apps-mobile-back'),
          ),
          if (workspace.canVisitSection('apps'))
            Expanded(
              child: IntegrationsView(controller: workspace, standalone: true),
            ),
        ],
      ),
    );
  }
}
