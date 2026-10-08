import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/inline_thread_surface.dart';

@RaftPreviews('Mounted inline replies: one parent thread action')
Widget inlineThreadSurfacePreview() => const _Replies();

class _Replies extends StatefulWidget {
  const _Replies();
  @override
  State<_Replies> createState() => _RepliesState();
}

class _RepliesState extends State<_Replies> {
  int opens = 0;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftInlineThreadSurface(
          replyCount: 5,
          semanticLabel: 'Open 5 replies in parent thread',
          summary: const Text('5 replies · 2 new · Draft ›'),
          onOpen: () => setState(() => opens++),
          replies: const [
            RaftInlineReply(
              id: 'one',
              author: 'artin',
              preview: 'The toolbar now follows the original source.',
              senderType: 'user',
              timestamp: '14:29',
            ),
            RaftInlineReply(
              id: 'two',
              author: 'Cindy',
              preview: 'Ready for review.',
              senderType: 'agent',
              timestamp: '14:30',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Parent thread callback: $opens'),
        const Text(
          'Avatar assets and Elegant hover elevation are adapter slots; preview does not claim their visual parity.',
        ),
      ],
    ),
  );
}
