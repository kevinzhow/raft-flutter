import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart';
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
  final control = agent && memberAgentRuntimeControllable(w, value);
  final online = agent && agentRowAmbientDisplay(value).activity != 'offline';
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
          if (control) ...[
            const RaftSidebarMenuDivider(),
            RaftSidebarMenuItem(
              itemKey: const ValueKey('member-menu-runtime'),
              label: raftText(menuContext, online ? 'Stop' : 'Start'),
              glyph: online ? RaftGlyph.square : RaftGlyph.play,
              onPressed: () => command(
                online ? MemberAgentCommand.stop : MemberAgentCommand.start,
              ),
            ),
            RaftSidebarMenuItem(
              itemKey: const ValueKey('member-menu-reset'),
              label: raftText(menuContext, 'Restart / Reset'),
              glyph: RaftGlyph.rotateCcw,
              onPressed: () => command(MemberAgentCommand.restartReset),
            ),
          ],
        ],
      );
    },
  ).whenComplete(() => onClosed?.call());
}
