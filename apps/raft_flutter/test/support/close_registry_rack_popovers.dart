import 'close_surface.dart';

const _esc = Affordance.esc, _scrim = Affordance.scrim;

/// The rack row's two Popovers (RackRowAction.tsx:96-150). A Web Popover
/// closes on Esc and an outside press and gives focus back to its trigger; it
/// has no X, no Android back and no drag.
const rackPopoverSurfaces = <CloseSurface>[
  CloseSurface(
    'rack-manual-upgrade-popover',
    kind: SurfaceKind.popup,
    web: 'features/computer/RackRowAction.tsx:117-135 Popover (side bottom, align end): Esc, outside press, focus back to the trigger',
    phone: {_esc, _scrim},
    fold: {_esc, _scrim},
    desktop: {_esc, _scrim},
    files: [
      'lib/features/computers_rack/rack_upgrade_popovers.dart',
      '../../packages/raft_ui/lib/src/rack_row_popover.dart',
    ],
  ),
  CloseSurface(
    'rack-upgrade-hint-popover',
    kind: SurfaceKind.popup,
    web: 'features/computer/RackRowAction.tsx:96-150 Popover (side bottom, align end) behind the warning icon: Esc, outside press, focus back to the trigger',
    phone: {_esc, _scrim},
    fold: {_esc, _scrim},
    desktop: {_esc, _scrim},
    files: [
      'lib/features/computers_rack/rack_upgrade_popovers.dart',
      '../../packages/raft_ui/lib/src/rack_row_popover.dart',
    ],
  ),
];
