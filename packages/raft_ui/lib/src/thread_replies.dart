import 'package:flutter/material.dart';

import 'components.dart';
import 'localization.dart';
import 'theme.dart';

@immutable
class RaftThreadReplyPreview {
  const RaftThreadReplyPreview({
    required this.id,
    required this.author,
    required this.preview,
    required this.senderType,
    this.timestamp = '',
  });
  final String id, author, preview, senderType, timestamp;
}

/// A muted conversation preview. Counts are authoritative; system events never
/// consume one of the three visible conversation slots.
class RaftThreadReplies extends StatelessWidget {
  const RaftThreadReplies({
    super.key,
    required this.replies,
    required this.replyCount,
    required this.onOpen,
    required this.onOpenReply,
    this.unreadCount = 0,
    this.hasDraft = false,
  });
  final List<RaftThreadReplyPreview> replies;
  final int replyCount, unreadCount;
  final bool hasDraft;
  final VoidCallback? onOpen;
  final ValueChanged<String>? onOpenReply;

  @override
  Widget build(BuildContext context) {
    final visible = replies
        .where(
          (r) =>
              r.id.isNotEmpty &&
              {'user', 'agent', 'external_projection'}.contains(r.senderType),
        )
        .take(3)
        .toList();
    if (replyCount <= 0 || visible.isEmpty) return const SizedBox.shrink();
    final tokens = RaftTokens.of(context);
    final count = raftFormat(
      context,
      replyCount == 1 ? '{count} reply' : '{count} replies',
      {'count': replyCount},
    );
    final suffix = [
      if (unreadCount > 0)
        raftFormat(context, '{count} new', {'count': unreadCount}),
      if (hasDraft) raftText(context, 'Draft'),
    ];
    final label = [count, ...suffix].join(' · ');
    final style = TextButton.styleFrom(
      alignment: Alignment.centerLeft,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      foregroundColor: tokens.muted,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: tokens.line)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                onPressed: onOpen,
                style: style,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
              for (final reply in visible)
                TextButton(
                  key: ValueKey('thread-preview-${reply.id}'),
                  onPressed: onOpenReply == null
                      ? null
                      : () => onOpenReply!(reply.id),
                  style: style,
                  child: Semantics(
                    label: raftFormat(
                      context,
                      'Open reply by {name}: {preview}',
                      {'name': reply.author, 'preview': reply.preview},
                    ),
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        if (reply.senderType == 'user')
                          RaftAvatar(name: reply.author, size: 20)
                        else
                          Icon(
                            reply.senderType == 'agent'
                                ? Icons.smart_toy_outlined
                                : Icons.apps,
                            size: 20,
                          ),
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 3,
                          child: Text(
                            reply.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 5,
                          child: Text(
                            reply.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        if (reply.timestamp.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            reply.timestamp,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
