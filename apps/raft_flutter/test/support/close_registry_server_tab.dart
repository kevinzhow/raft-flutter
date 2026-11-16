import 'close_surface.dart';

const _esc = Affordance.esc,
    _scrim = Affordance.scrim,
    _back = Affordance.systemBack;

/// The phone bar's server tab popover as the app hosts it (Web v1.24
/// MobileServerTab.tsx: the server list, the switcher's actions and the
/// server's pages over the bottom bar). The component's own registration is
/// `mobile-nav-server-popover`; this one proves it closes inside the real
/// workspace shell, whose PopScope must close it before it leaves the page.
const serverTabSurfaces = <CloseSurface>[
  CloseSurface(
    'mobile-server-tab-popover',
    kind: SurfaceKind.popup,
    web:
        'MobileServerTab.tsx MobileNavServerPopoverContent: Esc, outside press, '
        'focus back to the server tab',
    phone: {_esc, _scrim, _back},
    none: {
      'fold': 'a wide layout has the left rail, not the bottom bar',
      'desktop': 'the desktop layout has the left rail, not the bottom bar',
    },
    files: ['lib/features/mobile_server_tab.dart'],
  ),
];
