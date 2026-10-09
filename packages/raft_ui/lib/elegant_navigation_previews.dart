import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Rail identity and numeric count recipes', size: Size(390, 240))
Widget railIdentityRecipePreview() => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftMountedAvatarFrame(
            name: 'Visual Server',
            identity: RaftMountedAvatarIdentity.server,
          ),
          SizedBox(width: 16),
          RaftMountedAvatarFrame(
            name: 'Visual Server',
            identity: RaftMountedAvatarIdentity.server,
            extent: 32,
          ),
          SizedBox(width: 16),
          RaftRailUnreadCount(count: 12),
          SizedBox(width: 16),
          RaftRailUnreadCount(count: 104),
        ],
      ),
      const SizedBox(height: 24),
      RaftConversationTabs(
        tabs: const [
          RaftConversationTab(id: RaftConversationTabId.chat, label: 'Chat'),
          RaftConversationTab(id: RaftConversationTabId.files, label: 'Files'),
        ],
        value: RaftConversationTabId.chat,
        onChanged: (_) {},
      ),
    ],
  ),
);
