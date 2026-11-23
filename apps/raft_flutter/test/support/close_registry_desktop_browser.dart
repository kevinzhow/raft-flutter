import 'close_surface.dart';

const desktopBrowserSurfaces = <CloseSurface>[
  CloseSurface(
    'desktop-browser',
    kind: SurfaceKind.panel,
    web: 'BrowserPanel.tsx: the cover has Back; the dock has Close. Escape in the chrome closes either.',
    phone: {Affordance.back, Affordance.esc},
    fold: {Affordance.x, Affordance.esc},
    desktop: {Affordance.x, Affordance.esc},
    files: ['lib/features/desktop_browser_panel.dart'],
  ),
  CloseSurface(
    'desktop-browser-more-tabs',
    kind: SurfaceKind.popup,
    web: 'BrowserTabStrip.tsx: DropdownMenuContent closes on Escape or an outside press.',
    phone: {Affordance.esc, Affordance.scrim},
    fold: {Affordance.esc, Affordance.scrim},
    desktop: {Affordance.esc, Affordance.scrim},
    files: ['lib/features/desktop_browser_tab_strip.dart'],
  ),
  CloseSurface(
    'desktop-browser-link-menu',
    kind: SurfaceKind.popup,
    web: 'MessageWebLink.tsx offers Open Beside in the desktop context menu, which closes on Escape or an outside press.',
    phone: {Affordance.esc, Affordance.scrim},
    fold: {Affordance.esc, Affordance.scrim},
    desktop: {Affordance.esc, Affordance.scrim},
    files: ['lib/features/web_link_open.dart'],
  ),
];
