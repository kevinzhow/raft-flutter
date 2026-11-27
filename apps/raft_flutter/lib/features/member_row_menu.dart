import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart';
import 'agent_profile_rules.dart';
import 'desktop_navigation_policy.dart';
import 'fleet_views.dart';

/// Web Sidebar context menu of a Members row, opened by a right click or a
/// long press:
/// - a person: Message;
/// - an agent: Message, and for a managed agent the viewer may control,
///   a divider, Start or Stop (by whether it is online) and Restart / Reset.
///
/// [onMessage] opens the conversation (the row's double click). [onClosed]
/// runs when the menu goes away, so the row can drop its pressed fill.
Future<void> openMemberRowMenu(
  BuildContext context, {
  required Offset at,
  required WorkspaceController w,
  required DesktopContentTarget target,
  required Map<String, dynamic> value,
  required Future<void> Function(DesktopContentTarget)? onMessage,
  VoidCallback? onClosed,
}) {
  final agent = target.kind == DesktopContentKind.agent;
  final access = agentRuntimePermissions(
    agent: value,
    currentUserId: w.client.user?.id,
    controlAgentRuntime: w.can('controlAgentRuntime'),
    stopAgents: w.can('stopAgents'),
    resetAgentWorkspace: false,
    external: value['external'] == true || value['runtime'] == 'external',
    boundedPublic: !agent || isBoundedPublicAgent(value, w.server?.id),
  );
  final controls = agentRuntimeControls(
    canControl: access.canControlAgentRuntime,
    canStop: access.canStopAgent,
    isOnline: agent && agentRowAmbientDisplay(value).activity != 'offline',
    computerOffline: isAgentComputerOffline(value, [
      if (value['machineId'] case final String id)
        if (w.entityDirectory.computer(id) case final Map machine) machine,
    ]),
    stoppedByPerson: value['status'] == 'stopped',
  );
  return showRaftMessageContextMenu<void>(
    context: context,
    anchor: at,
    builder: (menuContext) {
      void close() => Navigator.of(menuContext).pop();
      void command(MemberAgentCommand next) {
        close();
        unawaited(runMemberAgentCommand(context, w, value, next));
      }

      return RaftSidebarContextMenu(
        width: 192,
        onDismiss: close,
        entries: [
          RaftSidebarMenuItem(
            itemKey: const ValueKey('member-menu-message'),
            label: raftText(menuContext, 'Message'),
            glyph: RaftGlyph.messageSquare,
            onPressed: () {
              close();
              unawaited(
                onMessage?.call(target).catchError((_) {}) ?? Future.value(),
              );
            },
          ),
          if (controls.start || controls.stop || controls.restartReset)
            const RaftSidebarMenuDivider(),
          if (controls.start || controls.stop)
            RaftSidebarMenuItem(
              itemKey: const ValueKey('member-menu-runtime'),
              label: raftText(
                menuContext,
                controls.stop ? 'Stop agent' : 'Start agent',
              ),
              glyph: controls.stop ? RaftGlyph.square : RaftGlyph.play,
              onPressed: () => command(
                controls.stop
                    ? MemberAgentCommand.stop
                    : MemberAgentCommand.start,
              ),
            ),
          if (controls.restartReset)
            RaftSidebarMenuItem(
              itemKey: const ValueKey('member-menu-reset'),
              label: raftText(menuContext, 'Restart / reset'),
              glyph: RaftGlyph.rotateCcw,
              onPressed: () => command(MemberAgentCommand.restartReset),
            ),
        ],
      );
    },
  ).whenComplete(() => onClosed?.call());
}
