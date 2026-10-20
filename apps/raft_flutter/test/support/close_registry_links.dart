import 'close_surface.dart';

/// Dialogs a link opens from message content (not part of the dialog suite,
/// whose per-file case count is capped by the test budget).
const linkSurfaces = <CloseSurface>[
  CloseSurface(
    'custom-protocol-link-confirm',
    kind: SurfaceKind.dialog,
    web: 'CustomProtocolLink.tsx AlertDialog: Cancel + Esc, no X, no outside press',
    phone: {Affordance.esc, Affordance.systemBack},
    fold: {Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.esc, Affordance.systemBack},
    files: ['lib/features/custom_protocol_link.dart'],
  ),
];
