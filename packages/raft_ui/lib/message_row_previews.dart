import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/avatar_content.dart';
import 'src/components.dart';
import 'src/icons.dart';
import 'src/message_row_recipe.dart';

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
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        title: const Text('Coarse pointer'),
        value: coarse,
        onChanged: (value) => setState(() => coarse = value),
      ),
      SwitchListTile(
        title: const Text('Thread content context'),
        value: thread,
        onChanged: (value) => setState(() => thread = value),
      ),
      RaftMessageRow(
        rowContext: thread
            ? RaftMessageRowContext.thread
            : RaftMessageRowContext.main,
        author: 'Cindy',
        timestamp: '14:30',
        nextContinuation: true,
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
              label: saved ? 'Remove from saved' : 'Save message',
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
        timestamp: '14:31',
        continuation: true,
        content: const Text(
          'Same sender continuation; the avatar and name are omitted.',
        ),
        coarsePointer: coarse,
      ),
      Text(result),
    ],
  );
}
