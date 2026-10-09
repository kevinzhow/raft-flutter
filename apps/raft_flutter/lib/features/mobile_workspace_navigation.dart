import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/raft_location.dart';
import '../data/workspace_navigation.dart';
import 'system_notification_center.dart';

/// Route-level mobile navigation, following MainLayout.tsx's root/detail cuts.
/// This is independent of the selected channel retained for draft restoration.
String? mobileWorkspaceRootTab(
  String section, {
  required bool threadOpen,
  required bool settingsDetail,
}) {
  if (threadOpen) return null;
  return switch (section) {
    'home' => 'chat',
    'tasks' => 'tasks',
    'members' => 'members',
    'settings' when !settingsDetail => 'settings',
    _ => null,
  };
}

/// Root visibility comes from the accepted URL, never a retained data window.
String? mobileWorkspaceRootTabForLocation(RaftLocation location) =>
    WorkspaceNavigation(initial: location).mobileRootTab;

String mobileWorkspaceBackSection(String section) => switch (section) {
  'computers' ||
  'workspace-settings' ||
  'sidebar-settings' ||
  'providers' ||
  'integrations' ||
  'im-bridges' ||
  'administration' ||
  'billing' => 'settings',
  _ => 'home',
};

/// MobileTabBar (packages/web/src/components/layout/MobileTabBar.tsx): Home,
/// Tasks, Members (hidden for guests / without viewMembers) and Settings.
class WorkspaceMobileTabBar extends StatelessWidget {
  const WorkspaceMobileTabBar({
    super.key,
    required this.controller,
    required this.selectedId,
    required this.onSelected,
    this.bottomInset = 0,
  });
  final WorkspaceController controller;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final w = controller;
    return RaftMobileNav(
      key: const Key('workspace-mobile-navigation'),
      selectedId: selectedId,
      bottomInset: bottomInset,
      onSelected: onSelected,
      items: [
        RaftMobileNavItem(
          id: 'chat',
          label: tr('Home'),
          glyph: RaftGlyph.home,
          key: const Key('mobile-tab-home'),
        ),
        RaftMobileNavItem(
          id: 'tasks',
          label: tr('Tasks'),
          glyph: RaftGlyph.checkSquare,
          key: const Key('mobile-tab-tasks'),
        ),
        if (w.server?.string('role') != 'guest' && w.can('viewMembers'))
          RaftMobileNavItem(
            id: 'members',
            label: tr('Members'),
            glyph: RaftGlyph.users,
            key: const Key('mobile-tab-members'),
          ),
        RaftMobileNavItem(
          id: 'settings',
          label: tr('Settings'),
          glyph: RaftGlyph.settings,
          key: const Key('mobile-tab-settings'),
        ),
      ],
    );
  }
}

/// Mobile home titlebar (Sidebar.tsx HomeTitlebarSurface, mobileInline): the
/// server selector and the notification-center trigger.
class WorkspaceMobileHomeHeader extends StatelessWidget {
  const WorkspaceMobileHomeHeader({
    super.key,
    required this.controller,
    required this.onServer,
    required this.onBilling,
    this.serverSwitcher,
  });
  final WorkspaceController controller;
  final VoidCallback onServer;
  final VoidCallback onBilling;
  final Widget? serverSwitcher;

  @override
  Widget build(BuildContext context) =>
      serverSwitcher ??
      RaftMobileRootHeader(
        leading: RaftMobileServerSelector(
          key: const Key('mobile-server-selector'),
          label: controller.server?.name ?? raftText(context, 'Workspace'),
          onPressed: onServer,
        ),
        actions: [
          SystemNotificationBell(
            key: const Key('mobile-home-notifications'),
            controller: controller,
            onBilling: onBilling,
          ),
        ],
      );
}
