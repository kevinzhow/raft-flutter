import 'close_surface.dart';

const _esc = Affordance.esc,
    _scrim = Affordance.scrim,
    _back = Affordance.systemBack;

/// The phone tab bar's server popover (raft-ui 0.95.3 MobileNavServerPopover,
/// a Base UI Popover over the bar). It has no X and no drag. A press outside
/// closes it, as does Escape, and focus goes back to the server tab.
const mobileNavServerSurfaces = <CloseSurface>[
  CloseSurface(
    'mobile-nav-server-popover',
    kind: SurfaceKind.popup,
    web: 'raft-ui mobile-nav-server.mjs MobileNavServerPopoverContent (Popover, side top over the tab bar): Esc, outside press, focus back to the server tab; MobileServerTab.tsx',
    phone: {_esc, _scrim, _back},
    fold: {_esc, _scrim, _back},
    desktop: {_esc, _scrim, _back},
    files: ['../../packages/raft_ui/lib/src/mobile_nav_server.dart'],
  ),
];
