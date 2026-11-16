import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

Widget _row({
  Key? key,
  bool selected = false,
  bool unread = false,
  bool badge = false,
  bool actions = true,
}) => RaftInboxItem(
  key: key,
  semanticLabel: 'Release notes, Draft is in the launch channel, 10:40',
  selected: selected,
  unread: unread,
  onOpen: () {},
  leading: const Icon(Icons.inbox, size: 18),
  leadingBadge: badge ? const Icon(Icons.circle, size: 10) : null,
  title: const Text('Release notes'),
  timestamp: const Text('10:40'),
  body: const Text('Draft is in the launch channel'),
  marks: const [Text('2')],
  actions: actions
      ? [
          RaftIconButton(
            glyph: RaftGlyph.checkCircle2,
            semanticLabel: 'Done',
            onPressed: () {},
          ),
        ]
      : const [],
);

@RaftPreviews('Inbox item states', size: Size(380, 340))
Widget inboxItemStatesPreview() => RaftInboxItemListGroup(
  heading: 'Today',
  first: true,
  children: [
    _row(),
    _row(unread: true, badge: true),
    _row(selected: true),
    const RaftInboxItemSkeleton(),
  ],
);
