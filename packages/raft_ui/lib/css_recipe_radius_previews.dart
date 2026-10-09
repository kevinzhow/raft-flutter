import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Recipe rounded-full at actual sizes', size: Size(390, 220))
Widget recipeRadiusPreview() => const Padding(
  padding: EdgeInsets.all(24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        children: [
          RaftRecipeBadge('Member'),
          RaftRecipeBadge('Installed'),
          RaftRecipeBadge('A longer label'),
        ],
      ),
      SizedBox(height: 20),
      Row(
        children: [
          RaftAvatarSlot(
            name: 'Kevin',
            slot: RaftAvatarSlotContext.panelHeader,
            agent: false,
            sizeOverride: 24,
          ),
          SizedBox(width: 16),
          RaftAvatarSlot(
            name: 'Kevin',
            slot: RaftAvatarSlotContext.panelHeader,
            agent: false,
            sizeOverride: 64,
          ),
        ],
      ),
    ],
  ),
);
