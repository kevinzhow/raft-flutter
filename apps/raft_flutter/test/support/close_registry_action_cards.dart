import 'close_surface.dart';

const _close = {Affordance.x, Affordance.esc, Affordance.systemBack};
const _outside = {..._close, Affordance.scrim};

const actionCardSurfaces = <CloseSurface>[
  CloseSurface(
    'action-card-confirm',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'ActionCardSpecConfirmDialog.tsx ConfirmDialog',
    phone: _close,
    fold: _close,
    desktop: _close,
    files: ['lib/features/message_action_card.dart'],
  ),
  CloseSurface(
    'action-card-form',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.closes,
    web: 'ActionCardFormSheet.tsx DialogSheet: close, Escape and outside press',
    phone: _outside,
    fold: _outside,
    desktop: _outside,
    files: ['lib/features/action_card_form.dart'],
  ),
  CloseSurface(
    'action-card-install',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'InstallAppCardDialog.tsx:327 NarrowDialogContent, pointer dismissal disabled',
    phone: _close,
    fold: _close,
    desktop: _close,
    files: ['lib/features/action_card_install.dart'],
  ),
  CloseSurface(
    'action-card-feedback',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'FeedbackCardDialog.tsx:69 NarrowDialogContent, pointer dismissal disabled',
    phone: _close,
    fold: _close,
    desktop: _close,
    files: ['lib/features/message_action_card.dart'],
  ),
  CloseSurface(
    'action-card-mcp-default',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'McpConnectCardBody.tsx:307 ConfirmDialog',
    phone: _close,
    fold: _close,
    desktop: _close,
    files: ['lib/features/action_card_mcp.dart'],
  ),
  CloseSurface(
    'action-card-send-create-agent',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'actionCardIntentFlows.tsx:730 ConfirmDialog',
    phone: _close,
    fold: _close,
    desktop: _close,
    files: ['lib/features/message_action_card.dart'],
  ),
];
