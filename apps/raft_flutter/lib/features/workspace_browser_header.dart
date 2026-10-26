import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/desktop_title_bar.dart';
import 'workspace_host_scope.dart';
import 'workspace_history_controls.dart';
import 'system_notification_center.dart';

/// Shared browser/native workspace header composition; the workspace supplies navigation actions and
/// the quick switcher owns the search anchor across openings.
class WorkspaceBrowserHeader extends StatelessWidget {
  const WorkspaceBrowserHeader({
    super.key,
    required this.searchKey,
    required this.workspace,
    required this.working,
    required this.controller,
    required this.onSearch,
    required this.onBilling,
    required this.onFeedback,
  });
  final GlobalKey searchKey;
  final Widget workspace, working;
  final WorkspaceController controller;
  final VoidCallback onSearch, onBilling, onFeedback;

  @override
  Widget build(BuildContext context) {
    final native = DesktopTitleBarScope.maybeOf(context);
    final desktop = WorkspaceHostScope.nativeDesktopOf(context);
    return RaftWorkspaceTopBar(
      key: const ValueKey('workspace-top-bar'),
      searchKey: searchKey,
      leadingInset: native?.leadingInset ?? 0,
      trailingInset: native?.trailingInset ?? 0,
      onDragStart: native?.onDragStart,
      onDoubleTap: native?.onDoubleTap,
      navigation: desktop
          ? WorkspaceHistoryControls(controller: controller)
          : null,
      workspace: workspace,
      onSearch: onSearch,
      trailing: [
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
