import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import 'thread_viewport_handle.dart';
import 'mobile_route_gate.dart';
import 'thread_actions.dart';
import 'thread_agent_followers_view.dart';
import 'icu_message.dart';

class WorkspaceThreadHeader extends StatefulWidget {
  const WorkspaceThreadHeader({
    super.key,
    required this.controller,
    required this.viewport,
    required this.mobile,
    required this.selectionActive,
    required this.onClose,
  });

  final WorkspaceController controller;
  final ChatViewportHandle viewport;
  final bool mobile, selectionActive;
  final VoidCallback onClose;

  @override
  State<WorkspaceThreadHeader> createState() => _WorkspaceThreadHeaderState();
}

class _WorkspaceThreadHeaderState extends State<WorkspaceThreadHeader> {
  int followersRequest = 0;

  @override
  Widget build(BuildContext context) {
    final w = widget.controller;
    final messages = w.messageDomain;
    final threadId = w.threadChannelId;
    final unresolved =
        threadId == null &&
        (messages.threadResolutionLoading ||
            messages.threadResolutionError != null);
    final parentId = messages.threadParentMessageId;
    final channelId = messages.threadParentChannelId;
    final channel = messages.threadSourceChannel;
    final summary = messages.summariesByChannel[channelId]?[parentId];
    final count = math.max(
      w.replies.length,
      summary is Map ? (summary['replyCount'] as num?)?.toInt() ?? 0 : 0,
    );
    void openParent() {
      if (channelId == null || parentId == null) return;
      final replace = RaftAdaptiveWorkspace.compactOf(context);
      w.closeThread(navigate: false);
      w.jumpToMessage(channelId, parentId, replaceEntry: replace);
    }

    final dismissLabel = widget.selectionActive
        ? 'Exit Selection'
        : 'Close thread';
    return ListenableBuilder(
      listenable: w.services.threadFollowers,
      builder: (context, _) => RetainWhileCovered(
        builder: (context) => LayoutBuilder(
          builder: (context, bounds) {
            final showFollowers =
                threadId != null &&
                !unresolved &&
                w.services.threadFollowers.visible(threadId);
            final fold =
                bounds.maxWidth < 360 ||
                RaftThreadPlacement.maybeOf(context) == null;
            final followers = threadId != null && !unresolved
                ? ThreadAgentFollowersView(
                    key: ValueKey('thread-followers-$threadId'),
                    controller: w,
                    threadChannelId: threadId,
                    folded: fold,
                    openRequest: followersRequest,
                    onOpenAgent: (id) =>
                        w.openProfile(RaftProfileKind.agent, id),
                  )
                : null;
            final overflow =
                !unresolved && parentId != null && channelId != null
                ? ThreadActions(
                    key: ValueKey('thread-menu-$parentId'),
                    controller: w,
                    parentMessageId: parentId,
                    menuMode: true,
                    onSearch: w.threadSearch.open,
                    onViewChannel: openParent,
                    onOutlineJump: widget.viewport.jumpToOutline,
                    onFollowers: fold && showFollowers
                        ? () => setState(() => followersRequest++)
                        : null,
                  )
                : null;
            return RaftThreadHeader(
              key: Key(
                widget.mobile
                    ? 'workspace-mobile-detail-header'
                    : 'workspace-thread-header',
              ),
              presentation: RaftThreadPresentation.side,
              threadLabel: raftText(context, 'Thread'),
              jumpLabel: raftText(context, 'Scroll to first message'),
              backLabel: raftText(context, dismissLabel),
              closeLabel: raftText(context, dismissLabel),
              backKey: Key(
                widget.mobile ? 'mobile-detail-back' : 'thread-back',
              ),
              closeKey: const Key('thread-close'),
              parentLabel: unresolved || channel == null
                  ? null
                  : threadChannelLabel(channel),
              replyCountLabel: count == 0 && messages.state.threadLoading
                  ? null
                  : replyCountText(context, count),
              interactiveTitle: !unresolved,
              onBack: widget.onClose,
              onClose: widget.onClose,
              onViewParent: parentId == null || channelId == null
                  ? null
                  : openParent,
              onJumpToStart: unresolved
                  ? null
                  : widget.viewport.jumpToBeginning,
              allowFocusMode: true,
              actions: [
                if (RaftTokens.of(context).desktop &&
                    followers != null &&
                    overflow != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      followers,
                      if (showFollowers && !fold)
                        const SizedBox(width: RaftSpace.x1),
                      overflow,
                    ],
                  )
                else ...[
                  ?followers,
                  ?overflow,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String threadChannelLabel(RaftChannel channel) => channel.type == 'dm'
    ? '@${channel.string('peerDisplayName', channel.string('peerName', channel.name))}'
    : '#${channel.name}';
