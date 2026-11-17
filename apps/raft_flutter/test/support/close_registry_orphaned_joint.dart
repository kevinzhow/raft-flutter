import 'close_surface.dart';

const _x = Affordance.x, _esc = Affordance.esc, _sys = Affordance.systemBack;

/// Settings > Server > External channels nobody here is in: the Disconnect
/// confirmation (Web OrphanedJointChannelsSection.tsx: a ConfirmDialog, which
/// has X + Esc and no pointer dismissal).
const orphanedJointSurfaces = <CloseSurface>[
  CloseSurface(
    'orphaned-joint-disconnect-confirm',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web:
        'OrphanedJointChannelsSection.tsx ConfirmDialog: X + Esc, no scrim '
        'close, gated while disconnecting',
    phone: {_x, _esc, _sys},
    fold: {_x, _esc, _sys},
    desktop: {_x, _esc, _sys},
    files: ['lib/features/orphaned_joint_channels_section.dart'],
  ),
];
