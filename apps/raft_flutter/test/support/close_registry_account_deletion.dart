import 'close_surface.dart';

const _x = Affordance.x, _esc = Affordance.esc, _sys = Affordance.systemBack;

/// Settings > Account > Delete Account: the confirmations and the proof.
const accountDeletionSurfaces = <CloseSurface>[
  CloseSurface(
    'account-deletion-confirm',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web:
        'AccountDeletionAgentRow.tsx ConfirmDialog (Archive) and '
        'ForceUnbindAgentsDialog.tsx -> ConfirmDialog.tsx:138-165 Dialog '
        'disablePointerDismissal: X + Esc, no scrim, all gated on loading. '
        'Move to another computer is the existing AgentMigrationDialog '
        "('agent-migration')",
    phone: {_x, _esc, _sys},
    fold: {_x, _esc, _sys},
    desktop: {_x, _esc, _sys},
    files: [
      'lib/features/account_deletion_agent_row.dart',
      'lib/features/account_deletion_checklist.dart',
    ],
    status: 'ok',
  ),
  CloseSurface(
    'account-deletion-proof',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web:
        'DeleteAccountVerifyDialog.tsx -> TwoStepVerificationSection.tsx:413 '
        'StepDialog `<Dialog disablePointerDismissal>` (password, emailed '
        'code) and VerifyItsYouDialog: X + Esc, no outside press; closing '
        'refused while busy; Cancel returns to the checklist',
    phone: {_x, _esc, _sys},
    fold: {_x, _esc, _sys},
    desktop: {_x, _esc, _sys},
    files: ['lib/features/account_deletion_verify.dart'],
    status: 'ok',
  ),
];
