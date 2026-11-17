import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// The Activity split-preview rule. Web 1.24 has no `activity_sidebar_inbox_v0`
/// (the sidebar-inbox variant is retired), so there is nothing to evaluate:
/// the split preview exists at every width where the shell shows its
/// multi-column layout.
class DesktopActivityFlag extends ChangeNotifier {
  DesktopActivityFlag(WorkspaceController w);

  /// The Activity split preview exists from [RaftLayoutMetrics.desktopBreakpoint]
  /// (owner decision "Activity click C": first click previews, only the same
  /// row twice upgrades).
  bool masterDetail(double width) =>
      width >= RaftLayoutMetrics.desktopBreakpoint;
}
