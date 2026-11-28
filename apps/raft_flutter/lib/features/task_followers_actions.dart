import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'chat_navigation.dart';
import 'thread_agent_followers_view.dart';
import '../data/raft_location.dart';

class TaskFollowersActions extends StatefulWidget {
  const TaskFollowersActions({
    super.key,
    required this.discussion,
    required this.navigation,
    required this.hasExpand,
    required this.buildHeader,
  });

  final WorkspaceController discussion;
  final ChatNavigation navigation;
  final bool hasExpand;
  final Widget Function(Widget? trigger, RaftMenuEntry? overflow) buildHeader;

  @override
  State<TaskFollowersActions> createState() => _TaskFollowersActionsState();
}

class _TaskFollowersActionsState extends State<TaskFollowersActions> {
  int openRequest = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.discussion,
    builder: (context, _) {
      final channelId = widget.discussion.threadChannelId;
      if (channelId == null) return widget.buildHeader(null, null);
      final workspace = widget.navigation.workspace;
      final followers = workspace.services.threadFollowers;
      return ListenableBuilder(
        listenable: followers,
        builder: (context, _) => LayoutBuilder(
          builder: (context, bounds) {
            final folded = bounds.maxWidth < (widget.hasExpand ? 261 : 225);
            return widget.buildHeader(
              ThreadAgentFollowersView(
                key: ValueKey('task-followers-$channelId'),
                controller: workspace,
                threadChannelId: channelId,
                folded: folded,
                openRequest: openRequest,
                task: true,
                onOpenAgent: (id) => widget.navigation.openProfile(
                  RaftProfileKind.agent,
                  id,
                  channelId: widget.discussion.channel?.id,
                ),
              ),
              folded && followers.visible(channelId)
                  ? RaftMenuEntry(
                      label: raftText(context, 'Following agents'),
                      onPressed: () => setState(() => openRequest++),
                    )
                  : null,
            );
          },
        ),
      );
    },
  );
}
