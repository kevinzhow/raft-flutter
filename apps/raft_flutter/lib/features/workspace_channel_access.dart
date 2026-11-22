import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/channel_access_loss.dart';
import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';

enum WorkspaceChannelAccess {
  lost,
  unavailable;

  static WorkspaceChannelAccess? forChannel(
    WorkspaceController workspace,
    String? channelId,
  ) {
    final marks = ChannelAccessLoss.of(workspace.client);
    if (marks.isLost(channelId)) return lost;
    if (marks.isUnavailable(channelId)) return unavailable;
    return null;
  }
}

class WorkspaceChannelAccessPage extends StatelessWidget {
  const WorkspaceChannelAccessPage({
    super.key,
    required this.workspace,
    required this.access,
    required this.wide,
  });

  final WorkspaceController workspace;
  final WorkspaceChannelAccess access;
  final bool wide;

  void leave(bool guest) {
    final owner = workspace.presentationSource ?? workspace;
    final marks = ChannelAccessLoss.of(owner.client);
    owner.closeThread(navigate: false);
    final home = RaftLocation.at(
      serverSlug: owner.location.serverSlug,
      route: guest ? RaftRoute.settings : RaftRoute.home,
    );
    owner.navigation.navigate(
      home,
      kind: guest ? RaftNavigationKind.push : RaftNavigationKind.replace,
    );
    if (marks.isLost(owner.channel?.id)) {
      owner.channel = null;
      if (wide && !guest) {
        final next = owner.channels
            .where((channel) => channel.joined && !marks.isLost(channel.id))
            .firstOrNull;
        if (next != null) unawaited(owner.selectChannel(next, navigate: false));
      }
    }
    owner.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final guest = workspace.server?.string('role') == 'guest';
    final unavailable = access == WorkspaceChannelAccess.unavailable;
    return RaftProductEmptyState(
      key: ValueKey(
        unavailable ? 'conversation-unavailable' : 'channel-access-lost',
      ),
      title: raftText(
        context,
        unavailable
            ? "This conversation isn't available to you"
            : "You're no longer in this channel",
      ),
      titleHeading: true,
      icon: (_, size, color) =>
          RaftIcon(RaftGlyph.messageSquare, size: size, color: color),
      action: RaftButton(
        key: const Key('channel-access-lost-back'),
        uiVariant: RaftButtonVariant.standard,
        label: raftText(
          context,
          guest
              ? 'Open Settings'
              : unavailable && !wide
              ? 'Back to conversations'
              : 'Back to channels',
        ),
        onPressed: () => leave(guest),
      ),
    );
  }
}
