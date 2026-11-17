import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Danger action row', size: Size(640, 360))
Widget dangerActionRowPreview() => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      RaftDangerActionRow(
        title: 'Leave server',
        description:
            "You will lose access to this server's channels and DMs. You can rejoin if invited again.",
        actionLabel: 'Leave server',
        warning: true,
        onAction: () {},
      ),
      RaftDangerActionRow(
        title: 'Delete server',
        description:
            'Permanently remove this server and all its data. This cannot be undone.',
        actionLabel: 'Delete server',
        actionGlyph: RaftGlyph.trash2,
        onAction: () {},
      ),
    ],
  ),
);
