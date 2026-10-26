import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/avatar_content.dart';
import 'src/components.dart';
import 'src/icons.dart';
import 'src/message_row_recipe.dart';
import 'src/raft/switch.dart' show RaftSwitch;

@RaftPreviews('Mounted message row: grouping and pointer actions')
Widget messageRowPreview() => const _Rows();

class _Rows extends StatefulWidget {
  const _Rows();
  @override
  State<_Rows> createState() => _RowsState();
}

class _RowsState extends State<_Rows> {
  bool saved = false, coarse = false, thread = false;
  String result = 'Ready';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        Row(
          spacing: 12,
          children: [
            RaftSwitch(
              value: coarse,
              onChanged: (value) => setState(() => coarse = value),
              semanticLabel: 'Coarse pointer',
            ),
            Flexible(child: Text('Coarse pointer')),
          ],
        ),
        Row(
          spacing: 12,
          children: [
            RaftSwitch(
              value: thread,
              onChanged: (value) => setState(() => thread = value),
              semanticLabel: 'Thread content context',
            ),
            Flexible(child: Text('Thread content context')),
          ],
        ),
        RaftMessageRow(
          rowContext: thread
              ? RaftMessageRowContext.thread
              : RaftMessageRowContext.main,
          author: 'Cindy',
          timestamp: '14:30',
          followedBy: RaftMessageFollowedBy.compact,
          coarsePointer: coarse,
          avatar: const RaftAvatar(
            name: 'Cindy',
            kind: RaftAvatarKind.agent,
            content: RaftAvatarContent(
              name: 'Cindy',
              kind: RaftAvatarContentKind.agent,
              pixelKey: 'robot',
            ),
          ),
          onActions: () => setState(() => result = 'Context callback'),
          content: const Text(
            'Public preview message. No API or private payload.',
          ),
          toolbar: RaftMessageToolbar(
            children: [
              RaftMessageToolbarAction(
                label: saved ? 'Remove from Saved' : 'Save Message',
                active: saved,
                icon: RaftIcon(
                  saved ? RaftGlyph.bookmarkFilled : RaftGlyph.bookmark,
                  size: 13,
                ),
                onPressed: () => setState(() {
                  saved = !saved;
                  result = saved ? 'Saved callback' : 'Removed callback';
                }),
              ),
            ],
          ),
        ),
        RaftMessageRow(
          rowContext: thread
              ? RaftMessageRowContext.thread
              : RaftMessageRowContext.main,
          author: 'Cindy',
          timestamp: '10/15 14:31',
          continuationTimestamp: '14:31',
          timestampTooltip: 'Oct 15, 2026, 14:31',
          continuation: true,
          content: const Text(
            'Same sender continuation; the avatar and name are omitted.',
          ),
          coarsePointer: coarse,
        ),
        Text(result),
      ],
    ),
  );
}
