import 'package:raft_ui/raft_ui.dart';

/// Every panel surface that owns an attached left edge (Web `Panel
/// edge="attached"`, the drawer's `theme-brutal:border-l-2`, the master /
/// detail divider). The rule is ONE: `RaftPanelEdge` (raft_ui panel_edge.dart)
/// draws the line everywhere except on a full-width standalone phone page.
///
/// - `panel_edge_registry_test.dart` fails when a source file asks
///   `RaftPanelEdge` without being listed here, when a listed file does not ask
///   it, when a left border is gated by a width / "mobile" flag in code, and
///   when a surface has no mount in the matrix.
/// - `panel_edge_matrix_test.dart` mounts every surface at phone (390),
///   foldable (816, 841) and desktop (1280) in each theme and asserts the line
///   is painted (absent only on the phone page).
/// - A new panel: add an entry here and a mount in the matrix test, or the
///   static check fails.
class PanelEdgeSurface {
  const PanelEdgeSurface(
    this.id, {
    required this.web,
    required this.files,
    required this.style,
    this.elegantDraws = true,
  });

  /// Stable name; the matrix test mounts the surface under this id.
  final String id;

  /// The Web component that draws the line.
  final String web;

  /// Dart files that decide the edge (relative to apps/raft_flutter). Each
  /// must call `RaftPanelEdge`.
  final List<String> files;
  final RaftPanelEdgeStyle style;

  /// False when the Elegant theme has no such edge (the rounded drawer card).
  final bool elegantDraws;
}

const _ui = '../../packages/raft_ui/lib/src';

const panelEdgeSurfaces = <PanelEdgeSurface>[
  PanelEdgeSurface(
    'settings-panel',
    web: 'SettingsPanel.tsx `<Panel edge="attached">`',
    files: ['$_ui/settings_layout.dart'],
    style: RaftPanelEdgeStyle.attachedPanel,
  ),
  PanelEdgeSurface(
    'channel-drawer',
    web: 'OverflowSheet DrawerContent `theme-brutal:border-l-2`',
    files: ['$_ui/channel_overflow_sheet.dart'],
    style: RaftPanelEdgeStyle.drawer,
    elegantDraws: false,
  ),
  PanelEdgeSurface(
    'members-page',
    web: 'ChannelMembers presentation="page" bare in OverflowSheet',
    files: ['$_ui/channel_overflow_sheet.dart'],
    style: RaftPanelEdgeStyle.drawer,
    elegantDraws: false,
  ),
  PanelEdgeSurface(
    'channel-settings-sheet',
    web: 'EditChannelDialog sheet (DrawerContent)',
    files: ['$_ui/channel_settings_sheet.dart'],
    style: RaftPanelEdgeStyle.drawer,
    elegantDraws: false,
  ),
  PanelEdgeSurface(
    'task-thread-panel',
    web: 'ThreadPanelRoot (`Panel edge="attached"`) inside the task modal',
    files: ['$_ui/task_surface.dart'],
    style: RaftPanelEdgeStyle.attachedPanel,
  ),
  PanelEdgeSurface(
    'workspace-thread-panel',
    web: 'ThreadPanelRoot / ThreadPanel in the right column',
    files: ['$_ui/adaptive_workspace.dart'],
    style: RaftPanelEdgeStyle.attachedPanel,
  ),
  PanelEdgeSurface(
    'workspace-profile-panel',
    web: 'ProfilePanel `<Panel edge="attached">`',
    files: ['$_ui/adaptive_workspace.dart'],
    style: RaftPanelEdgeStyle.attachedPanel,
  ),
  PanelEdgeSurface(
    'activity-inbox',
    web:
        'ThreadsInbox `<ActivityInboxPanel edge="attached" '
        'className="theme-brutal:!border-l">`',
    files: ['lib/features/resource_view.dart'],
    style: RaftPanelEdgeStyle.activityInbox,
  ),
  PanelEdgeSurface(
    'activity-thread-detail',
    web:
        'MainLayout col-2 wrapper `border-r border-line-muted '
        'theme-brutal:border-black` (Activity: 1px), thread detail in col 3',
    files: ['lib/features/desktop_master_detail.dart'],
    style: RaftPanelEdgeStyle.attachedPanel,
  ),
  PanelEdgeSurface(
    'search-detail',
    web:
        'MainLayout col-2 wrapper `border-r border-line-muted '
        'theme-brutal:border-r-2 theme-brutal:border-black` (Search)',
    files: ['lib/features/desktop_master_detail.dart'],
    style: RaftPanelEdgeStyle.attachedPanel,
  ),
];

/// Left-edge borders that are intentionally NOT the shared rule, with the
/// reason. The static check accepts a width-gated `left: BorderSide` only in
/// these files.
const panelEdgeAllowlist = <String, String>{
  '$_ui/task_surface.dart':
      'LegacyTaskPanel docked side presentation (>= 1024, hairline edge) is '
      'its own Web component, not a Panel edge="attached"',
};
