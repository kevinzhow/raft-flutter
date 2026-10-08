import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Inline thread replies')
Widget inlineRepliesPreview() => const _Preview();

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  String result = 'Ready';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftThreadReplies(
          replyCount: 12,
          unreadCount: 2,
          hasDraft: true,
          replies: const [
            RaftThreadReplyPreview(
              id: 'human',
              author: '林 中文',
              preview: '设计已经完成。日本語確認',
              senderType: 'user',
              timestamp: '12:30',
            ),
            RaftThreadReplyPreview(
              id: 'agent',
              author: 'Cody',
              preview: 'The verification passed.',
              senderType: 'agent',
              timestamp: '12:31',
            ),
            RaftThreadReplyPreview(
              id: 'external',
              author: 'Project app',
              preview: 'A long review note is truncated within this row.',
              senderType: 'external_projection',
              timestamp: '12:32',
            ),
          ],
          onOpen: () => setState(() => result = 'Thread opened'),
          onOpenReply: (id) => setState(() => result = 'Reply $id opened'),
        ),
        const SizedBox(height: 16),
        Text(result),
      ],
    ),
  );
}
