import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'lounge_channel_presentation.dart' show loungeComposerHint;

/// The placeholder of a conversation's composer (Web ChatPanel
/// `MessageInput channelName`: `@name` for a DM, "{Name}'s Lounge" for an
/// agent's Lounge, `#name` for a channel).
String channelComposerHint(BuildContext context, WorkspaceController w) {
  final channel = w.channel;
  // One Web key covers all three (`message.composer.messagePlaceholder`,
  // "Message {channel}"): Web passes the whole display name, sigil included,
  // as `{channel}` (`<MessageInput channelName="#general">`). Splitting the
  // sigil out into the English source would leave the string without a Web
  // match, so every language would fall back to English — and a language that
  // puts the name first ("{channel} へのメッセージ") could not be expressed.
  if (channel?.type == 'dm') {
    final peer = channel!.string(
      'peerDisplayName',
      channel.string('peerName', channel.name),
    );
    return raftFormat(context, 'Message {channel}', {'channel': '@$peer'});
  }
  return loungeComposerHint(context, w) ??
      raftFormat(context, 'Message {channel}', {
        'channel': '#${channel?.name ?? ''}',
      });
}
