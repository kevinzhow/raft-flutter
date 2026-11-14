// Desktop Computers (Web v1.24 MainLayout ComputersRoute, shellRouteLayout.ts
// isComputersFullPage): the rack is a full page beside the rail, like Tasks;
// a computer opens in the panel beside it (the profile panel's width) and its
// row stays selected.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../desktop_navigation_policy.dart';
import '../panel_width_store.dart';
import 'computers_rack_view.dart';

class ComputersRackDesktopPage extends StatelessWidget {
  const ComputersRackDesktopPage({
    super.key,
    required this.controller,
    required this.target,
    required this.onSelected,
    this.detail,
  });
  final WorkspaceController controller;
  final DesktopContentTarget? target;
  final ValueChanged<DesktopContentTarget> onSelected;

  /// The open computer's page, beside the rack.
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final selected = target?.kind == DesktopContentKind.computer
        ? target!.id
        : null;
    return RaftRackSidePanelLayout(
      width: profilePanelWidth.value,
      rack: ComputersRackView(
        controller: controller,
        selectedId: selected,
        onOpenComputer: (row) {
          final id = row['id'];
          if (id is String) {
            onSelected(DesktopContentTarget(DesktopContentKind.computer, id));
          }
        },
      ),
      panel: selected == null ? null : detail,
    );
  }
}
