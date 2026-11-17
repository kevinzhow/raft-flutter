import 'close_registry_artifacts.dart';
import 'close_registry_community.dart';
import 'close_registry_dialogs.dart';
import 'close_registry_limit_notice.dart';
import 'close_registry_links.dart';
import 'close_registry_mobile_nav_server.dart';
import 'close_registry_panels.dart';
import 'close_registry_popups.dart';
import 'close_registry_rack_popovers.dart';
import 'close_registry_raftbench.dart';
import 'close_registry_server_tab.dart';
import 'close_registry_task_slot.dart';
import 'close_registry_viewers.dart';
import 'close_registry_web_link_choice.dart';
import 'close_surface.dart';

/// Every closable surface, across the family registries.
List<CloseSurface> get allCloseSurfaces => [
  ...panelSurfaces,
  ...communitySurfaces,
  ...dialogSurfaces,
  ...limitNoticeSurfaces,
  ...linkSurfaces,
  ...mobileNavServerSurfaces,
  ...popupSurfaces,
  ...rackPopoverSurfaces,
  ...raftbenchSurfaces,
  ...serverTabSurfaces,
  ...taskSlotSurfaces,
  ...viewerSurfaces,
  ...artifactSurfaces,
  ...webLinkChoiceSurfaces,
  ...webPreviewSurfaces,
];

/// Panels the shell (lib/features/workspace_view*.dart) hosts in its side
/// and detail columns, with the surfaces whose harnesses check their closes.
/// Many never call an opener API themselves (the shell supplies the column,
/// Esc and Back), so the file scan alone cannot require them; the registry
/// test requires every panel-like widget the shell builds to be listed here
/// or in [shellHostedContent]. Since COMP1 (#624) the person, agent and
/// computer details beside a page sit inside ProfileSidePanel's host
/// (desktop_detail_host.dart), so the shell builds only that panel.
const shellHostedPanels = <String, List<String>>{
  'ProfileSidePanel': ['profile-human', 'profile-agent', 'profile-external'],
  'ThreadAgentFollowersView': ['thread-followers'],
  'RaftOverflowBareSheet': ['channel-members-page'],
};

/// Panel-like widgets the shell builds that are not closable layers.
const shellHostedContent = <String, String>{
  'ConversationPanel':
      'the channel conversation is the shell\'s main content (Web '
      'ChannelView), not a layer that closes',
  'DesktopMasterDetail':
      'the list-and-detail layout itself; the details it shows are listed '
      'in shellHostedPanels',
};

/// Files that contain a surface API call but are not a surface themselves.
/// Each entry says why; a new entry needs a reviewer's agreement.
const closeScanExempt = <String, String>{
  'lib/features/computers_rack/computers_rack_view.dart':
      'only the Computers overview page itself: a top-level section page like '
      'Tasks or Activity (Web ComputersRackOverview has no Back or X); on a '
      "phone the shell's mobile page header owns Back. The computer it opens "
      'beside it on desktop is NOT covered by this entry: it is registered as '
      "the 'computers-rack-side-panel' panel surface, and the move dialog as "
      "'rack-move-dialog'",
  '../../packages/raft_ui/lib/src/raft_selection_area.dart':
      'the Quote / Copy pair beside a mouse selection is a non-modal toolbar '
      '(Web MessageSelectionShortcut): it closes with the next press, Escape '
      'or a changed selection and has no scrim or page of its own',
  'lib/platform/app_window.dart':
      'dispatches close commands to existing routes and the native window; '
      'opens no surface of its own',
  '../../packages/raft_ui/lib/src/preview_route.dart':
      'defines preview route types; the attachment and media browser callers '
      'that open previews are listed surfaces',
  'lib/features/private_route_guard.dart':
      'removes routes when access is revoked; opens no surface of its own',
  'lib/features/page_layout.dart':
      'RaftPageHeader primitive: each page that uses it is a listed surface',
  '../../packages/raft_ui/lib/src/error_presentation.dart':
      'RaftToastHost overlay only paints the toast viewport; a toast is not '
      'a closable layer',
  '../../packages/raft_ui/lib/src/panel_layout.dart': 'RaftPanelHeaderBar primitive: each panel that uses it is a listed surface',
  '../../packages/raft_ui/lib/src/large_content_viewer.dart':
      'Large Content Viewer overlay only lives while a finger is held on a '
      'bounded chrome item and goes away when it lifts; it is not a closable '
      'layer (same as iOS UILargeContentViewerInteraction)',
};
