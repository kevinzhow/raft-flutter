import 'close_surface.dart';

const appsSurfaces = <CloseSurface>[
  CloseSurface(
    'settings-apps-add-menu',
    kind: SurfaceKind.popup,
    web: 'IntegrationsSection.tsx: Add app closes on Escape and outside press.',
    phone: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    fold: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    files: ['../../packages/raft_ui/lib/src/settings_applications.dart'],
  ),
  CloseSurface(
    'apps-page',
    kind: SurfaceKind.panel,
    web: 'IntegrationsSection.tsx: Apps is a route with a narrow Back action and browser history.',
    phone: {Affordance.back, Affordance.systemBack},
    none: {
      'fold': 'Select another rail destination or use navigation history.',
      'desktop': 'Select another rail destination or use navigation history.',
    },
    files: ['lib/features/apps_route.dart'],
  ),
];
