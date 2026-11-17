import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Workspace button on the frame band', size: Size(390, 240))
Widget workspaceButtonPreview() => const _WorkspaceButtonPreview();

class _WorkspaceButtonPreview extends StatelessWidget {
  const _WorkspaceButtonPreview();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (name, attention, live) in const [
        ('Dev Workspace', false, false),
        ('Alpha', true, true),
        (
          'A server with a very long name that has to truncate at 200',
          false,
          false,
        ),
      ])
        RaftMobileRootHeader(
          workspace: true,
          leading: RaftMobileServerSelector(
            label: name,
            attention: attention,
            attentionLabel: 'Other servers have unread messages',
            publicPageLive: live,
            onPressed: () {},
          ),
          actions: [RaftMobileNotificationButton(mobileHeader: true)],
        ),
    ],
  );
}
