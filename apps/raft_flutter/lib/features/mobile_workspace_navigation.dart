import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/mobile_tabbar_preferences.dart';
import '../data/source_activity_unread_store.dart';
import '../data/workspace_controller.dart';
import '../data/raft_location.dart';
import '../data/workspace_navigation.dart';
import '../platform/app_services.dart';
import '../platform/app_update.dart';
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

/// MobileTabBar (packages/web/src/components/layout/MobileTabBar.tsx): Home,
/// Tasks, Members (hidden for guests / without viewMembers) and Settings by
/// default; the device's Bottom bar setting chooses and orders the tabs.
class WorkspaceMobileTabBar extends StatelessWidget {
  const WorkspaceMobileTabBar({
    super.key,
    required this.controller,
    required this.selectedId,
    required this.onSelected,
    this.bottomInset = 0,
    this.tabs,
    this.activityUnread,
    this.appUpdate,
  });
  final WorkspaceController controller;

  /// Red dot on the Settings tab while a newer release is unseen.
  final AppUpdateService? appUpdate;

  /// The configurable tabs to show, in order (Settings is appended). Null is
  /// the default bar; callers pass the account-filtered device choice.
  final List<String>? tabs;

  /// The shared Activity unread total (the one the desktop rail's Activity
  /// attention reads); its count badges the Activity tab. The workspace owns
  /// the acquisition, so the bar starts no requests of its own.
  final SourceActivityUnreadStore? activityUnread;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    // A covered phone route keeps this bar mounted and does not rebuild it
    // from the shell. Read the root service here so a replacement releases
    // the previous one in that same frame.
    final live = AppServicesScope.maybeOf(context)?.appUpdate ?? appUpdate;
    final listenables = [?activityUnread, ?live];
    return listenables.isEmpty
        ? bar(context, live)
        : ListenableBuilder(
            listenable: Listenable.merge(listenables),
            builder: (context, _) => bar(context, live),
          );
  }

  Widget bar(BuildContext context, AppUpdateService? update) {
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
        glyph: RaftGlyph.checkSquare,
        key: const Key('mobile-tab-tasks'),
      ),
      MobileTabs.members => RaftMobileNavItem(
        id: id,
        label: tr('Members'),
        glyph: RaftGlyph.users,
        key: const Key('mobile-tab-members'),
      ),
      MobileTabs.computers => RaftMobileNavItem(
        id: id,
        label: tr('Computers'),
        glyph: RaftGlyph.monitor,
        key: const Key('mobile-tab-computers'),
      ),
      MobileTabs.activity => RaftMobileNavItem(
        id: id,
        label: tr('Activity'),
        glyph: RaftGlyph.activity,
        badgeCount: activityUnread?.totalUnreadCount ?? 0,
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
      onSelected: onSelected,
      items: [
        for (final id in tabIds) item(id),
        RaftMobileNavItem(
          id: 'settings',
          label: tr('Settings'),
          glyph: RaftGlyph.settings,
          key: const Key('mobile-tab-settings'),
          attention: update?.hasUnseen ?? false,
        ),
      ],
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
