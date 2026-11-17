import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'channel_activity_session.dart';

Widget channelActivityHeader(
  WorkspaceController w,
  RaftChannel channel,
  Widget Function(BuildContext context, Widget? suffix) builder,
) {
  if (!isActivityChannel(channel)) {
    return Builder(builder: (context) => builder(context, null));
  }
  final session = ChannelActivitySession.of(w);
  return ListenableBuilder(
    listenable: session,
    builder: (context, _) =>
        builder(context, session.enabled ? const ChannelActivityBadge() : null),
  );
}

class ChannelActivityBadge extends StatelessWidget {
  const ChannelActivityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, 'Sorted by latest activity');
    return Semantics(
      label: label,
      image: true,
      child: RaftTooltip(
        message: label,
        excludeFromSemantics: true,
        child: RaftIcon(
          RaftGlyph.arrowDownWideNarrow,
          key: const ValueKey('channel-forum-order-badge'),
          size: 14,
          color: RaftTokens.of(context).colors['foreground-hint'],
        ),
      ),
    );
  }
}
