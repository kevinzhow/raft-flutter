import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews(
  'Mounted directory rows: identity and selection',
  size: Size(390, 260),
)
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

@RaftPreviews(
  'Mounted sidebar: computer groups and human descriptions',
  size: Size(390, 420),
)
Widget mountedSidebarPreview() {
  var expanded = true;
  var selected = 'Cindy';
  return StatefulBuilder(
    builder: (context, update) => RaftMountedSidebarFrame(
      header: const RaftChatSidebarHeading(label: 'Members'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        children: [
          RaftSidebarMachineGroup(
            name: 'K8-Plus',
            count: 1,
            expanded: expanded,
            onExpandedChanged: (value) => update(() => expanded = value),
            children: [
              RaftNavItem(
                label: 'Cindy',
                description: 'Engineering operator',
                conversationKind: RaftConversationNavKind.directory,
                selected: selected == 'Cindy',
                leading: const RaftAvatar(
                  name: 'Cindy',
                  kind: RaftAvatarKind.agent,
                  mountedContext: RaftMountedAvatarContext.sidebarList,
                ),
                onTap: () => update(() => selected = 'Cindy'),
              ),
            ],
          ),
          RaftNavItem(
            label: 'Kevin',
            labelSuffix: '(you)',
            description: 'Product builder',
            conversationKind: RaftConversationNavKind.directory,
            selected: selected == 'Kevin',
            leading: const RaftAvatar(
              name: 'Kevin',
              kind: RaftAvatarKind.human,
              mountedContext: RaftMountedAvatarContext.sidebarList,
            ),
            onTap: () => update(() => selected = 'Kevin'),
          ),
        ],
      ),
    ),
  );
}
