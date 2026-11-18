import 'close_surface.dart';

const _popup = {Affordance.esc, Affordance.scrim, Affordance.systemBack};
const _dialog = {Affordance.esc, Affordance.systemBack};
const _file = ['lib/features/app_link_view.dart'];

const appLinkSurfaces = <CloseSurface>[
  CloseSurface(
    'app-link-confirmation',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'LinkCardActions.tsx LinkCardConfirmDialog. Cancel and Escape dismiss; outside presses leave the confirmation open.',
    phone: _dialog,
    fold: _dialog,
    desktop: _dialog,
    files: _file,
  ),
  CloseSurface(
    'app-link-consent-popover',
    kind: SurfaceKind.popup,
    web: 'AppLinkChip.tsx AppLinkConsentChip. Escape and outside press dismiss; Flutter system Back closes the pinned popover.',
    phone: _popup,
    fold: _popup,
    desktop: _popup,
    files: _file,
  ),
  CloseSurface(
    'app-link-hover-card',
    kind: SurfaceKind.popup,
    web: 'AppLinkChip.tsx AppLinkHoverCard. Pointer exit, Escape and outside press dismiss. Touch opens the browser.',
    desktop: {Affordance.esc, Affordance.scrim},
    none: {
      'phone': 'touch has no preview popover',
      'fold': 'touch has no preview popover',
    },
    files: _file,
  ),
  CloseSurface(
    'app-link-more-menu',
    kind: SurfaceKind.popup,
    web: 'LinkCardActions.tsx More menu. Escape and outside press dismiss and return focus to More.',
    phone: _popup,
    fold: _popup,
    desktop: _popup,
    files: _file,
  ),
];
