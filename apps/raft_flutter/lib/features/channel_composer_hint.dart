import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'lounge_channel_presentation.dart' show loungeComposerHint;

/// The placeholder of a conversation's composer (Web ChatPanel
/// `MessageInput channelName`: `@name` for a DM, "{Name}'s Lounge" for an
/// agent's Lounge, `#name` for a channel).
String channelComposerHint(BuildContext context, WorkspaceController w) {
  final channel = w.channel;
  if (channel?.type == 'dm') {
    // Web ChatPanel: a DM composer reads `Message @<peer>`.
    return raftFormat(context, 'Message @{name}', {
      'name': channel!.string(
        'peerDisplayName',
        channel.string('peerName', channel.name),
      ),
    });
  }
  return loungeComposerHint(context, w) ??
      raftFormat(context, 'Message #{name}', {'name': channel?.name ?? ''});
}
