import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Workspace browser top bar', size: Size(856, 260))
Widget workspaceTopBarPreview() => const _WorkspaceTopBarPreview();

class _WorkspaceTopBarPreview extends StatefulWidget {
  const _WorkspaceTopBarPreview();
  @override
  State<_WorkspaceTopBarPreview> createState() =>
      _WorkspaceTopBarPreviewState();
}

class _WorkspaceTopBarPreviewState extends State<_WorkspaceTopBarPreview> {
  final menu = RaftMenuController();
  var selected = 'v';
  var searchOpen = false, notificationsOpen = false;
  @override
  void dispose() {
    menu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      RaftWorkspaceTopBar(
        workspace: RaftServerSwitcher(
          controller: menu,
          workspaceName: selected == 'v' ? 'Visual Server' : 'Archive',
          label: 'Switch Server',
          topBar: true,
          rows: [
            for (final (id, name) in [('v', 'Visual Server'), ('a', 'Archive')])
              RaftServerMenuRow(
                id: id,
                name: name,
                slug: id,
                current: selected == id,
                onSelected: () => setState(() => selected = id),
              ),
          ],
          actions: const [],
        ),
        onSearch: () => setState(() => searchOpen = !searchOpen),
        trailing: [
          RaftMobileNotificationButton(
            onFrame: true,
            open: notificationsOpen,
            onPressed: () =>
                setState(() => notificationsOpen = !notificationsOpen),
          ),
        ],
      ),
      Expanded(
        child: Center(
          child: Text(
            searchOpen
                ? 'Search opened'
                : notificationsOpen
                ? 'Notifications opened'
                : 'Workspace',
          ),
        ),
      ),
    ],
  );
}
