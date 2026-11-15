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
  double width = profilePanelWidth.value;

  /// Focus enters the panel when a computer opens and returns to the rack
  /// row it came from when the panel closes (Web ProfilePanel.tsx:78-93).
  final panelScope = FocusScopeNode(debugLabel: 'computers-rack-side-panel');
  FocusNode? opener;

  String? get selected => widget.target?.kind == DesktopContentKind.computer
      ? widget.target!.id
      : null;

  @override
  void initState() {
    super.initState();
    if (selected != null) _focusPanel();
  }

  @override
  void didUpdateWidget(ComputersRackDesktopPage old) {
    super.didUpdateWidget(old);
    final before = old.target?.kind == DesktopContentKind.computer
        ? old.target!.id
        : null;
    if (before == null && selected != null) {
      // The row (or whatever had focus) that opened it.
      opener = FocusManager.instance.primaryFocus;
      _focusPanel();
    } else if (before != null && selected == null) {
      final back = opener;
      opener = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && back != null && back.context != null) {
          back.requestFocus();
        }
      });
    }
  }

  void _focusPanel() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || selected == null) return;
    panelScope.requestFocus();
    panelScope.nextFocus();
  });

  @override
  void dispose() {
    panelScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    return RaftRackSidePanelLayout(
      width: width,
      onResize: (value) => setState(
        () => width = value.clamp(profilePanelWidth.min, profilePanelWidth.max),
      ),
      onResizeEnd: () => profilePanelWidth.save(width),
      resizeLabel: raftText(context, 'Resize profile'),
      resizeMin: profilePanelWidth.min,
      resizeMax: profilePanelWidth.max,
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
          : FocusScope(node: panelScope, child: widget.detail!),
    );
  }
}
