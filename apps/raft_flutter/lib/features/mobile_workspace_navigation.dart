import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/mobile_tabbar_preferences.dart';
import '../data/source_activity_unread_store.dart';
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
    _ => null,
  };
}

/// Root visibility comes from the accepted URL, never a retained data window.
String? mobileWorkspaceRootTabForLocation(
  RaftLocation location, {
  Set<String> tabs = const {},
}) => (WorkspaceNavigation(initial: location)..mobileTabs = tabs).mobileRootTab;

String mobileWorkspaceBackSection(String section) => switch (section) {
  'computers' ||
  'workspace-settings' ||
  'providers' ||
  'integrations' ||
  'im-bridges' ||
  'administration' ||
  'billing' => 'settings',
  _ => 'home',
};

/// MobileTabBar (Web v1.24 MainLayout.tsx): Home, Activity, Tasks and Search,
/// then the server tab ([serverTab]), which opens the server list and the
/// server's pages (Members, Computers, Settings are pushed pages, not tabs).
/// The device's Bottom bar setting chooses and orders the four tabs.
class WorkspaceMobileTabBar extends StatelessWidget {
  const WorkspaceMobileTabBar({
    super.key,
    required this.controller,
    required this.selectedId,
    required this.onSelected,
    this.onReselected,
    this.bottomInset = 0,
    this.tabs,
    this.activityUnread,
    this.serverTab,
  });
  final WorkspaceController controller;

  /// The configurable tabs to show, in order (the server tab is appended).
  /// Null is the default bar; callers pass the account-filtered device choice.
  final List<String>? tabs;

  /// The shared Activity unread total (the one the desktop rail's Activity
  /// attention reads): the Activity tab shows a dot while it has attention and
  /// is not selected, never a number. The workspace owns the acquisition, so
  /// the bar starts no requests of its own.
  final SourceActivityUnreadStore? activityUnread;

  /// The bar's last cell ([MobileServerTab]); never selected.
  final Widget? serverTab;
  final String selectedId;
  final ValueChanged<String> onSelected;

  /// A tap on the tab that is already selected: no navigation. Home / Tasks
  /// scroll to the top, Search focuses its field, Activity goes to its next
  /// unread (WP-INBOX).
  final ValueChanged<String>? onReselected;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final unread = activityUnread;
    return unread == null
        ? bar(context, false)
        : ListenableBuilder(
            listenable: unread,
            builder: (context, _) => bar(context, unread.hasAttention),
          );
  }

  Widget bar(BuildContext context, bool activityAttention) {
    String tr(String s) => raftText(context, s);
    final w = controller;
    final nativeMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final tabIds =
        tabs ??
        MobileTabbarSettings.defaults.effective(
          guest: w.server?.string('role') == 'guest',
          can: w.can,
        );
    RaftMobileNavItem item(String id) => switch (id) {
      MobileTabs.tasks => RaftMobileNavItem(
        id: id,
        label: tr('Tasks'),
        glyph: RaftGlyph.listTodo,
        key: const Key('mobile-tab-tasks'),
      ),
      MobileTabs.search => RaftMobileNavItem(
        id: id,
        label: tr('Search'),
        glyph: RaftGlyph.search,
        key: const Key('mobile-tab-search'),
      ),
      MobileTabs.activity => RaftMobileNavItem(
        id: id,
        label: tr('Activity'),
        glyph: RaftGlyph.activity,
        // A dot, never a number, and never on the tab that is showing.
        attention: activityAttention && selectedId != MobileTabs.activity,
        attentionKey: const Key('mobile-tab-activity-unread-dot'),
        attentionLabel: 'Unread activity',
        key: const Key('mobile-tab-activity'),
      ),
      _ => RaftMobileNavItem(
        id: MobileTabs.home,
        label: tr('Home'),
        glyph: RaftGlyph.home,
        key: const Key('mobile-tab-home'),
      ),
    };
    Widget navigation = RaftMobileNav(
      key: const Key('workspace-mobile-navigation'),
      selectedId: selectedId,
      bottomInset: bottomInset,
      onSelected: (id) => id == selectedId && onReselected != null
          ? onReselected!(id)
          : onSelected(id),
      items: [for (final id in tabIds) item(id)],
      trailing: serverTab,
    );
    navigation = Semantics(
      container: true,
      explicitChildNodes: true,
      label: tr('Primary'),
      child: navigation,
    );
    if (nativeMobile) {
      // The bar is the only consumer of the bottom system inset on tab roots.
      // It reads the stable system bar height (viewPadding), never the
      // keyboard-aware padding, so it cannot follow or outlive the keyboard.
      navigation = ColoredBox(
        color: RaftTokens.of(context).colors['layer-mobile-nav-system']!,
        child: Padding(
          padding: EdgeInsets.only(bottom: raftSystemBottomInset(context)),
          child: navigation,
        ),
      );
      // The in-flow bar paints beneath the system navigation / home indicator;
      // the floating capsule has no strip fill.
    }
    return navigation;
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
    this.workingSummary,
  });
  final WorkspaceController controller;
  final VoidCallback onServer;
  final VoidCallback onBilling;
  final Widget? serverSwitcher;

  /// The working-agents summary, before the bell.
  final Widget? workingSummary;

  @override
  Widget build(BuildContext context) =>
      serverSwitcher ??
      RaftMobileRootHeader(
        leading: RaftMobileServerSelector(
          key: const Key('mobile-server-selector'),
          label: controller.server?.name ?? raftText(context, 'Server'),
          onPressed: onServer,
        ),
        actions: [
          ?workingSummary,
          SystemNotificationBell(
            key: const Key('mobile-home-notifications'),
            controller: controller,
            onBilling: onBilling,
          ),
        ],
      );
}
