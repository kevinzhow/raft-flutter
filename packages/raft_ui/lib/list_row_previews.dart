import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('List row tones and subtitle', size: Size(380, 360))
Widget listRowTonesPreview() => RaftListRowGroup(
  children: [
    RaftListRow(
      variant: RaftListRowVariant.plain,
      onPressed: () {},
      children: const [
        RaftListRowIcon(RaftGlyph.search),
        RaftListRowBody(
          children: [
            RaftListRowTitle('Archive channel'),
            RaftListRowSubtitle('Hides it from the sidebar'),
          ],
        ),
      ],
    ),
    RaftListRow(
      variant: RaftListRowVariant.plain,
      tone: RaftListRowTone.warning,
      onPressed: () {},
      children: const [
        RaftListRowIcon(RaftGlyph.search),
        RaftListRowBody(children: [RaftListRowTitle('Stop agents')]),
      ],
    ),
    RaftListRow(
      variant: RaftListRowVariant.plain,
      tone: RaftListRowTone.danger,
      onPressed: () {},
      children: const [
        RaftListRowIcon(RaftGlyph.search),
        RaftListRowBody(children: [RaftListRowTitle('Delete channel')]),
      ],
    ),
    RaftListRow(
      variant: RaftListRowVariant.plain,
      interactive: false,
      attached: true,
      children: const [
        RaftListRowBody(children: [RaftListRowTitle('Attached detail row')]),
      ],
    ),
  ],
);

@RaftPreviews('List row skeleton', size: Size(380, 260))
Widget listRowSkeletonPreview() => const RaftListRowGroup(
  children: [
    RaftListRowSkeleton(),
    RaftListRowSkeleton(index: 1),
    RaftListRowSkeleton(index: 2),
  ],
);
