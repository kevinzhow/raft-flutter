import 'close_surface.dart';

const _formExits = {Affordance.x, Affordance.esc, Affordance.systemBack};
const _popupExits = {Affordance.esc, Affordance.scrim, Affordance.systemBack};

const managedMcpSurfaces = <CloseSurface>[
  CloseSurface(
    'managed-mcp-editor',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'McpAppEditor.tsx uses FormDialog with a Close app form button.',
    phone: _formExits,
    fold: _formExits,
    desktop: _formExits,
    files: [
      'lib/features/mcp_app_editor.dart',
      'lib/features/integrations_views.dart',
    ],
  ),
  CloseSurface(
    'managed-mcp-connection-menu',
    kind: SurfaceKind.popup,
    web: 'McpConnectionRow.tsx uses DropdownMenu for connection actions.',
    phone: _popupExits,
    fold: _popupExits,
    desktop: _popupExits,
    files: ['lib/features/mcp_app_connections.dart'],
  ),
  CloseSurface(
    'managed-mcp-agent-access',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.closes,
    web: 'McpAgentConnectionDrawer.tsx closes the connection drawer via Cancel, Escape or outside press.',
    phone: {..._formExits, Affordance.scrim},
    fold: {..._formExits, Affordance.scrim},
    desktop: {..._formExits, Affordance.scrim},
    files: [
      'lib/features/agent_mcp_access.dart',
      'lib/features/agent_apps_view.dart',
    ],
  ),
];
