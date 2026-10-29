import 'close_surface.dart';

/// Surfaces a link opens from message content (not part of the dialog suite,
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
  CloseSurface(
    'artifact-viewer',
    kind: SurfaceKind.viewer,
    web: 'Flutter-only: Web opens an artifact link in a browser tab; the in-app browser follows the attachment preview (page below 768, full-bleed dialog above): Back / X, Esc, system back',
    phone: {Affordance.back, Affordance.esc, Affordance.systemBack},
    fold: {Affordance.x, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.x, Affordance.esc, Affordance.systemBack},
    files: ['lib/features/artifact_viewer.dart'],
    status: 'no-web',
  ),
  CloseSurface(
    'human-login-sheet',
    kind: SurfaceKind.dialog,
    web: 'Flutter-only: Web does this step in a page (HumanLoginSetupPage, /login-with-raft/setup); the in-app browser shows it as a form window (sheet below 768, dialog above): X, Esc, scrim, system back, drag',
    phone: {
      Affordance.x,
      Affordance.esc,
      Affordance.scrim,
      Affordance.systemBack,
      Affordance.drag,
    },
    fold: {
      Affordance.x,
      Affordance.esc,
      Affordance.scrim,
      Affordance.systemBack,
    },
    desktop: {
      Affordance.x,
      Affordance.esc,
      Affordance.scrim,
      Affordance.systemBack,
    },
    files: ['lib/features/human_login_sheet.dart'],
    status: 'no-web',
  ),
];
