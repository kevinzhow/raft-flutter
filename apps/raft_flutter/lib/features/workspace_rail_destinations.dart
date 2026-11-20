import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'activity_first_unread.dart';
import 'app_permission_updates.dart';
import 'artifacts/artifact_session.dart';
import 'computers_rack/computer_attention_seen.dart';

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

List<RaftRailDestination> workspaceRailDestinations(
  WorkspaceController workspace, {
  required String Function(String) tr,
  required bool desktopFrame,
  required bool chatAttention,
  required bool activityAttention,
}) => [
  RaftRailDestination(
    id: 'search',
    label: tr('Search'),
    glyph: RaftGlyph.search,
  ),
  RaftRailDestination(
    id: 'chat',
    label: tr('Chat'),
    glyph: desktopFrame ? RaftGlyph.message : RaftGlyph.messageSquare,
    attention: chatAttention,
  ),
  RaftRailDestination(
    id: 'activity',
    label: tr('Activity'),
    glyph: RaftGlyph.activity,
    attention: activityAttention,
    onDoubleClick: () => ActivityFirstUnread.of(workspace).request(workspace),
  ),
  RaftRailDestination(
    id: 'tasks',
    label: tr('Tasks'),
    glyph: desktopFrame ? RaftGlyph.listTodo : RaftGlyph.checkSquare,
  ),
  if (ArtifactSession.of(workspace).enabled)
    RaftRailDestination(
      id: 'artifacts',
      label: tr('Artifacts'),
      glyph: desktopFrame ? RaftGlyph.artifact : RaftGlyph.fileText,
    ),
  if (workspace.can('viewMembers'))
    RaftRailDestination(
      id: 'members',
      label: tr('Members'),
      glyph: RaftGlyph.users,
    ),
  if (workspace.can('viewMachines'))
    RaftRailDestination(
      id: 'computers',
      label: tr('Computers'),
      glyph: RaftGlyph.monitor,
      attention: computerAttentionDotFor(workspace),
    ),
  if (workspace.canVisitSection('apps'))
    RaftRailDestination(
      id: 'apps',
      label: tr('Apps'),
      glyph: RaftGlyph.blocks,
      iconWidget: icon(RaftGlyph.blocks),
      attention: AppPermissionUpdates.of(workspace).summary.needsAdminReview,
    ),
];
