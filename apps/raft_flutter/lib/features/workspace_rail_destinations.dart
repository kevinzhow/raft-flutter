import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'activity_first_unread.dart';
import 'artifacts/artifact_session.dart';
import 'computers_rack/computer_attention_seen.dart';

List<RaftRailDestination> workspaceRailDestinations(
  WorkspaceController workspace, {
  required String Function(String) tr,
  required Widget Function(RaftGlyph) icon,
  required bool chatAttention,
  required bool activityAttention,
}) => [
  RaftRailDestination(
    id: 'search',
    label: tr('Search'),
    glyph: RaftGlyph.search,
    iconWidget: icon(RaftGlyph.search),
  ),
  RaftRailDestination(
    id: 'chat',
    label: tr('Chat'),
    glyph: RaftGlyph.messageSquare,
    iconWidget: icon(RaftGlyph.messageSquare),
    attention: chatAttention,
  ),
  RaftRailDestination(
    id: 'activity',
    label: tr('Activity'),
    glyph: RaftGlyph.activity,
    iconWidget: icon(RaftGlyph.activity),
    attention: activityAttention,
    onDoubleClick: () => ActivityFirstUnread.of(workspace).request(workspace),
  ),
  RaftRailDestination(
    id: 'tasks',
    label: tr('Tasks'),
    glyph: RaftGlyph.checkSquare,
    iconWidget: icon(RaftGlyph.checkSquare),
  ),
  if (ArtifactSession.of(workspace).enabled)
    RaftRailDestination(
      id: 'artifacts',
      label: tr('Artifacts'),
      glyph: RaftGlyph.fileText,
      iconWidget: icon(RaftGlyph.fileText),
    ),
  if (workspace.can('viewMembers'))
    RaftRailDestination(
      id: 'members',
      label: tr('Members'),
      glyph: RaftGlyph.users,
      iconWidget: icon(RaftGlyph.users),
    ),
  if (workspace.can('viewMachines'))
    RaftRailDestination(
      id: 'computers',
      label: tr('Computers'),
      glyph: RaftGlyph.monitor,
      iconWidget: icon(RaftGlyph.monitor),
      attention: computerAttentionDotFor(workspace),
    ),
];
