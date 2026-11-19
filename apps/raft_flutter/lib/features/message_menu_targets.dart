import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'external_sender.dart';
import 'forward_messages_dialog.dart';
import 'message_select_text_sheet.dart';

/// The message menu entries that act beyond the row itself (Web v1.24
/// MessageItem.tsx:2866-2876 Forward, 3782-3842 Mark as Unread and Select
/// Text; messageMenuMarkUnread.ts, threadUnreadHold.ts). A null id or a false
/// flag leaves its entry out of the menu.
class MessageMenuTargets {
  const MessageMenuTargets._({
    required this.threadChannelId,
    required this.markThread,
    required this.markConversation,
    required this.dm,
    required this.forward,
    required this.selectText,
  });

  /// [threadPanel]: the row is in a thread panel (its parent or a reply).
  /// [active]: the conversation is the one presented (the toolbar's gate).
  factory MessageMenuTargets.of(
    BuildContext context,
    WorkspaceController w,
    RaftMessage message, {
    required bool threadPanel,
    required bool parentTile,
    required Object? summary,
    required bool active,
  }) {
    final followed = w.services.followedThreads;
    final own =
        followed.threadChannelIdFor(message.id) ??
        (summary is Map ? summary['threadChannelId'] : null) ??
        message.json['threadChannelId'] ??
        (parentTile ? w.threadChannelId : null);
    final parent = w.messageDomain.state.threadParent?.id;
    final channel = w.channel;
    return MessageMenuTargets._(
      threadChannelId: own is String ? own : null,
      // In a thread panel every row offers the thread's own Mark as Unread
      // (useEnclosingThreadMarkUnread); in a list, a row whose thread the
      // person follows. Both only for a followed thread.
      markThread: threadPanel
          ? (parent != null && followed.isFollowing(parent)
                ? w.threadChannelId
                : null)
          : (followed.isFollowing(message.id) && own is String ? own : null),
      // The sidebar row's Mark as Unread, from a channel's or DM's list; not
      // in a channel the person has not joined (the sidebar has no row).
      markConversation:
          threadPanel || channel == null || channel.json['joined'] == false
          ? null
          : channel.id,
      dm: channel?.type == 'dm',
      forward: active && messageForwardable(message),
      selectText:
          RaftInteraction.of(context).touch &&
          message.string('messageType') != 'system' &&
          message.content.trim().isNotEmpty,
    );
  }

  /// The message's thread channel (Unfollow's target), when known.
  final String? threadChannelId;
  final String? markThread, markConversation;
  final bool dm, forward, selectText;

  /// Runs [choice] when it is one of these entries. Mark as Unread is one
  /// `POST /channels/{id}/unread` and a count reload, as Web's; a failure
  /// leaves the reloaded counts and no message, as Web's.
  Future<void> run(
    BuildContext context,
    WorkspaceController w,
    RaftMessage message,
    String choice, {
    required String Function() time,
    required ValueChanged<String> quote,
  }) async {
    final unread = switch (choice) {
      'mark-thread-unread' => markThread,
      'mark-conversation-unread' => markConversation,
      _ => null,
    };
    if (unread != null) {
      if (choice == 'mark-thread-unread' && unread == w.threadChannelId) {
        return w.conversationReads.markOpenThreadUnread(unread);
      }
      return w.conversationReads.markUnread(unread).catchError((_) {});
    }
    await switch (choice) {
      'forward' => forwardMessages(context, w, [message]),
      'select-text' => showMessageSelectTextSheet(
        context,
        senderName: messageSenderName(context, message),
        time: time(),
        markdown: message.content,
        onQuote: quote,
      ),
      _ => null,
    };
  }
}
