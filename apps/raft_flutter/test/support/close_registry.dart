import 'close_registry_dialogs.dart';
import 'close_registry_links.dart';
import 'close_registry_panels.dart';
import 'close_registry_popups.dart';
import 'close_registry_viewers.dart';
import 'close_surface.dart';

/// Every closable surface, across the family registries.
List<CloseSurface> get allCloseSurfaces => [
  ...panelSurfaces,
  ...dialogSurfaces,
  ...linkSurfaces,
  ...popupSurfaces,
  ...viewerSurfaces,
];

/// Files that contain a surface API call but are not a surface themselves.
/// Each entry says why; a new entry needs a reviewer's agreement.
const closeScanExempt = <String, String>{
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
  '../../packages/raft_ui/lib/src/panel_layout.dart':
      'RaftPanelHeaderBar primitive: each panel that uses it is a listed surface',
  '../../packages/raft_ui/lib/src/large_content_viewer.dart':
      'Large Content Viewer overlay only lives while a finger is held on a '
      'bounded chrome item and goes away when it lifts; it is not a closable '
      'layer (same as iOS UILargeContentViewerInteraction)',
};
