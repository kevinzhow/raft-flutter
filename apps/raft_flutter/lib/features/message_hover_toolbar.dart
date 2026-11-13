import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/reaction_favorite.dart';

/// Web 1.24 MessageHoverToolbar's buttons, in order: the order follows the
/// message menu (reaction row, Reply in Thread, Forward, Save), and More opens
/// that menu.
enum MessageHoverToolbarAction { reaction, thread, forward, bookmark, more }

List<MessageHoverToolbarAction> messageHoverToolbarActions({
  required bool showThread,
  required bool canReact,
  required bool canForward,
  required bool canMore,
}) => [
  if (canReact) MessageHoverToolbarAction.reaction,
  if (showThread) MessageHoverToolbarAction.thread,
  if (canForward) MessageHoverToolbarAction.forward,
  MessageHoverToolbarAction.bookmark,
  if (canMore) MessageHoverToolbarAction.more,
];

/// The reaction button's name: Like / Remove like for 👍, React with / Remove
/// {emoji} otherwise.
String quickReactionLabel(
  BuildContext context,
  String emoji, {
  required bool reacted,
}) => emoji == defaultFavoriteReaction
    ? raftText(context, reacted ? 'Remove like' : 'Like')
    : raftFormat(context, reacted ? 'Remove {emoji}' : 'React with {emoji}', {
        'emoji': emoji,
      });

/// The hover toolbar of one message row. It is built only while it shows (the
/// row's portal), so the favorite reaction is read when it appears and kept
/// while it shows: the button never changes under the pointer.
class MessageHoverToolbar extends StatefulWidget {
  const MessageHoverToolbar({
    super.key,
    required this.messageId,
    required this.saved,
    required this.favorite,
    required this.reacted,
    required this.reactionOpen,
    required this.moreOpen,
    this.onThread,
    this.onReact,
    this.onReactionPicker,
    this.onForward,
    this.onSave,
    this.onMore,
  });
  final String messageId;
  final bool saved, reactionOpen, moreOpen;

  /// Reads the person's most-used reaction now.
  final String Function() favorite;

  /// Whether the person already reacted with [emoji] on this message.
  final bool Function(String emoji) reacted;
  final VoidCallback? onThread, onForward, onSave;

  /// Toggles that emoji on the message (a click, Enter or Space).
  final ValueChanged<String>? onReact;

  /// Opens every reaction at the button (a rest, or a tap by touch).
  final ValueChanged<BuildContext>? onReactionPicker;
  final ValueChanged<BuildContext>? onMore;

  @override
  State<MessageHoverToolbar> createState() => _MessageHoverToolbarState();
}

class _MessageHoverToolbarState extends State<MessageHoverToolbar> {
  late String favorite = widget.favorite();

  @override
  Widget build(BuildContext context) {
    final id = widget.messageId;
    final actions = messageHoverToolbarActions(
      showThread: widget.onThread != null,
      canReact: widget.onReact != null,
      canForward: widget.onForward != null,
      canMore: widget.onMore != null,
    );
    return RaftMessageToolbar(
      children: [
        for (final action in actions)
          switch (action) {
            MessageHoverToolbarAction.reaction => Builder(
              key: ValueKey('message-react-$id'),
              builder: (anchor) {
                final reacted = widget.reacted(favorite);
                final label = quickReactionLabel(
                  context,
                  favorite,
                  reacted: reacted,
                );
                return RaftMessageToolbarAction(
                  key: ValueKey('message-quick-react-$id'),
                  label: label,
                  tooltip: raftFormat(
                    context,
                    '{action} · hover for more reactions',
                    {'action': label},
                  ),
                  // Sooner than the app's tooltips, so the hint shows before
                  // the picker does (QUICK_REACTION_HINT_DELAY_MS).
                  tooltipDelay: const Duration(milliseconds: 250),
                  icon: RaftReactionGlyph(favorite, size: 16),
                  pressed: reacted,
                  popupOpen: widget.reactionOpen,
                  onPressed: () => widget.onReact!(favorite),
                  onTouchPressed: widget.onReactionPicker == null
                      ? null
                      : () => widget.onReactionPicker!(anchor),
                  onRest: widget.onReactionPicker == null
                      ? null
                      : () => widget.onReactionPicker!(anchor),
                );
              },
            ),
            MessageHoverToolbarAction.thread => RaftMessageToolbarAction(
              key: ValueKey('message-thread-$id'),
              label: raftText(context, 'Reply in thread'),
              icon: const RaftMessageThreadGlyph(),
              onPressed: widget.onThread,
            ),
            MessageHoverToolbarAction.forward => RaftMessageToolbarAction(
              key: ValueKey('message-forward-$id'),
              label: raftText(context, 'Forward'),
              icon: const RaftIcon(RaftGlyph.forward, size: 13),
              onPressed: widget.onForward,
            ),
            MessageHoverToolbarAction.bookmark => RaftMessageToolbarAction(
              key: ValueKey('message-save-$id'),
              label: raftText(
                context,
                widget.saved ? 'Remove from Saved' : 'Save',
              ),
              icon: RaftIcon(
                widget.saved ? RaftGlyph.bookmarkMinus : RaftGlyph.bookmark,
                size: 13,
              ),
              active: widget.saved,
              onPressed: widget.onSave,
            ),
            MessageHoverToolbarAction.more => Builder(
              key: ValueKey('message-more-$id'),
              builder: (anchor) => RaftMessageToolbarAction(
                label: raftText(context, 'More actions'),
                icon: const RaftIcon(RaftGlyph.ellipsis, size: 13),
                popupOpen: widget.moreOpen,
                onPressed: () => widget.onMore!(anchor),
              ),
            ),
          },
      ],
    );
  }
}
