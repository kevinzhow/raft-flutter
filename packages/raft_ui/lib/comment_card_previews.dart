import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Comment thread and private draft', size: Size(340, 230))
Widget commentCardPreview() => const Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: RaftSpace.x3,
  children: [
    RaftCommentCard(
      active: true,
      children: [
        Text('Review Owner · 5 minutes ago'),
        Text('Check the heading.'),
        Text('Heading updated.'),
      ],
    ),
    RaftCommentCard(
      privateDraft: true,
      children: [Text('Whole Artifact'), Text('Private note for the review.')],
    ),
  ],
);
