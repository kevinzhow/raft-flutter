import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Mounted directory rows: identity and selection', size: Size(390, 260))
Widget directoryNavigationPreview() {
  var selected = 'Cindy';
  return StatefulBuilder(
    builder: (context, update) => Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (name, agent, description) in [
            ('Cindy', true, 'Engineering operator'),
            ('Cody', true, 'Full stack developer'),
            ('Kevin', false, ''),
          ])
            RaftNavItem(
              label: name,
              conversationKind: RaftConversationNavKind.directory,
              selected: selected == name,
              description: description.isEmpty ? null : description,
              leading: RaftAvatar(
                name: name,
                kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
                mountedContext: RaftMountedAvatarContext.sidebarList,
              ),
              onTap: () => update(() => selected = name),
            ),
        ],
      ),
    ),
  );
}
