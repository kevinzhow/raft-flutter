// Desktop Computers (Web v1.24 MainLayout ComputersRoute, shellRouteLayout.ts
// isComputersFullPage): the rack is a full page beside the rail, like Tasks;
// a computer opens in the panel beside it (the profile panel's width) and its
// row stays selected.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../desktop_detail_host.dart';
import '../desktop_navigation_policy.dart';
import '../panel_width_store.dart';
import 'computers_rack_view.dart';

class ComputersRackDesktopPage extends StatefulWidget {
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
  State<ComputersRackDesktopPage> createState() =>
      _ComputersRackDesktopPageState();
}

class _ComputersRackDesktopPageState extends State<ComputersRackDesktopPage> {
  /// The panel's width while it is dragged; kept as the profile panel's
  /// (Web `ColumnResizeHandle column="detail"`).
  double width = profilePanelWidth.value.clamp(
    profilePanelWidth.min,
    rackPanelMax,
  );

  /// The rack's side panel keeps its 300 to 600 (the shared width can be
  /// wider, dragged beside the Members list).
  static const rackPanelMax = 600.0;

  String? get selected => widget.target?.kind == DesktopContentKind.computer
      ? widget.target!.id
      : null;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    return DesktopDetailFocus(
      open: selected != null && widget.detail != null,
      builder: (scope) => RaftRackSidePanelLayout(
        width: width,
        onResize: (value) => setState(
          () => width = value.clamp(profilePanelWidth.min, rackPanelMax),
        ),
        onResizeEnd: () => profilePanelWidth.save(width),
        resizeLabel: raftText(context, 'Resize profile'),
        resizeMin: profilePanelWidth.min,
        resizeMax: rackPanelMax,
        resizeDefault: profilePanelWidth.fallback,
        rack: ComputersRackView(
          controller: widget.controller,
          selectedId: selected,
          onOpenComputer: (row) {
            final id = row['id'];
            if (id is String) {
              widget.onSelected(
                DesktopContentTarget(DesktopContentKind.computer, id),
              );
            }
          },
        ),
        panel: selected == null || widget.detail == null
            ? null
            : FocusScope(node: scope, child: widget.detail!),
      ),
    );
  }
}
