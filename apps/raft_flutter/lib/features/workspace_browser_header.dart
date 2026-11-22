import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/desktop_title_bar.dart';
import 'quick_switcher_host.dart';
import 'workspace_host_scope.dart';
import 'workspace_history_controls.dart';
import 'paused_notifications_indicator.dart';
import 'system_notification_center.dart';

/// Shared browser/native workspace header composition; the workspace supplies navigation actions and
/// the quick switcher owns the search anchor across openings.
class WorkspaceBrowserHeader extends StatelessWidget {
  const WorkspaceBrowserHeader({
    super.key,
    required this.searchKey,
    this.searchFocus,
    required this.workspace,
    required this.working,
    required this.controller,
    required this.quickSwitcher,
    required this.onSearch,
    required this.onBilling,
    required this.onFeedback,
  });
  final GlobalKey searchKey;
  final FocusNode? searchFocus;
  final Widget workspace, working;
  final WorkspaceController controller;
  final QuickSwitcherHost quickSwitcher;
  final VoidCallback onSearch, onBilling, onFeedback;

  @override
  Widget build(BuildContext context) {
    final native = DesktopTitleBarScope.maybeOf(context);
    final desktop = WorkspaceHostScope.nativeDesktopOf(context);
    return RaftWorkspaceTopBar(
      key: const ValueKey('workspace-top-bar'),
      searchKey: searchKey,
      searchFocus: searchFocus,
      leadingInset: native?.leadingInset ?? 0,
      trailingInset: native?.trailingInset ?? 0,
      onDragStart: native?.onDragStart,
      onDoubleTap: native?.onDoubleTap,
      preserveTextFieldFocusOnDrag:
          desktop &&
          defaultTargetPlatform == TargetPlatform.macOS &&
          native?.onDragStart != null,
      navigation: desktop
          ? WorkspaceHistoryControls(
              controller: controller,
              quickSwitcher: quickSwitcher,
            )
          : null,
      workspace: workspace,
      onSearch: onSearch,
      trailing: [
        PausedNotificationsIndicator(controller: controller),
        working,
        SystemNotificationBell(
          key: const Key('topbar-notifications'),
          controller: controller,
          mobile: false,
          topBar: true,
          onBilling: onBilling,
          onFeedback: onFeedback,
        ),
      ],
    );
  }
}
