// Web features/agent/createdAgentToast.ts: the receipt for an agent created
// from the sidebar, the Members page or a Computer. The person stays where
// they were; View takes them to the agent: its DM in the middle (the existing
// one, else one opened now, as Message on a profile does) and its profile
// beside it, where the profile is a side panel.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart' show RaftProfileKind;
import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

String _name(Map<String, dynamic> agent) {
  final display = agent['displayName'];
  if (display is String && display.isNotEmpty) return display;
  return '${agent['name'] ?? ''}';
}

/// Shows "Created {name}" with View. Call it once the create dialog has closed
/// (no toast with an action over a modal), with a context of the page that
/// opened it. Nothing is shown when that page has gone.
void showCreatedAgentToast(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> agent,
) {
  if (!context.mounted) return;
  final serverId = w.server?.id;
  final authority = workspaceAuthority(w);
  showRaftToast(
    context,
    raftFormat(context, 'Created {name}', {'name': _name(agent)}),
    tone: RaftToastRecipeTone.success,
    actionLabel: 'View',
    onAction: () => unawaited(
      viewCreatedAgent(
        context,
        w,
        agent,
        serverId: serverId,
        authority: authority,
      ),
    ),
  );
}

/// View on the toast. A navigation of the person's own while the DM is being
/// opened means they went on: nothing moves.
Future<void> viewCreatedAgent(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> agent, {
  required String? serverId,
  required Object authority,
}) async {
  // Another server or account now: its stores are not this agent's.
  bool onServer() =>
      context.mounted &&
      w.server?.id == serverId &&
      authority == workspaceAuthority(w);
  if (!onServer()) return;
  final id = agent['id'];
  if (id is! String) return;
  final revision = w.navigationRevision;
  // Read before the first await: the context is only used while mounted.
  final compact = RaftAdaptiveWorkspace.compactOf(context);
  final name = _name(agent);
  w.closeThread();
  String? dmId = w.dms
      .where(
        (dm) => dm.string('peerType') == 'agent' && dm.string('peerId') == id,
      )
      .firstOrNull
      ?.id;
  if (dmId == null) {
    try {
      final value = await w.client.post('/channels/dm', data: {'agentId': id});
      if (value is Map && value['id'] is String) dmId = value['id'] as String;
    } catch (_) {
      dmId = null;
    }
    if (!context.mounted) return;
    if (dmId == null) {
      if (onServer()) {
        showRaftToast(
          context,
          raftFormat(
            context,
            "Couldn't open your conversation with {name}. Try again.",
            {'name': name},
          ),
        );
      }
      return;
    }
  }
  if (!onServer() || revision != w.navigationRevision) return;
  await w.jumpToMessage(dmId, null);
  if (!context.mounted || !onServer()) return;
  // Where the profile would be its own page over the DM (a phone), only the
  // DM opens, so the composer the DM focuses stays in view.
  if (!compact) {
    w.openProfile(RaftProfileKind.agent, id);
  }
}
