import 'close_surface.dart';

const _dialog = {Affordance.x, Affordance.esc, Affordance.systemBack};
const _menu = {Affordance.esc, Affordance.scrim, Affordance.systemBack};

const externalInviteCloseSurfaces = [
  CloseSurface(
    'add-external-member-dialog',
    kind: SurfaceKind.dialog,
    web: 'AddExternalMemberDialog.tsx uses DialogCard with X and Escape',
    webOutside: WebOutside.stays,
    phone: _dialog,
    fold: _dialog,
    desktop: _dialog,
    files: ['lib/features/external_invite_channel_dialog.dart'],
  ),
  CloseSurface(
    'external-invite-withdraw-dialog',
    kind: SurfaceKind.dialog,
    web: 'ExternalInviteRows.tsx uses ConfirmDialog with X and Escape',
    webOutside: WebOutside.stays,
    phone: _dialog,
    fold: _dialog,
    desktop: _dialog,
    files: ['lib/features/external_invite_channel_members.dart'],
  ),
  CloseSurface(
    'external-invite-cancel-dialog',
    kind: SurfaceKind.dialog,
    web: 'ExternalInvitePage.tsx CancelRequestConfirm uses ConfirmDialog with X and Escape',
    webOutside: WebOutside.stays,
    phone: _dialog,
    fold: _dialog,
    desktop: _dialog,
    files: ['lib/features/external_invite_page.dart'],
  ),
  CloseSurface(
    'joint-disconnect-dialog',
    kind: SurfaceKind.dialog,
    web: 'JointServerDisconnectAction.tsx uses ConfirmDialog with X and Escape',
    webOutside: WebOutside.stays,
    phone: _dialog,
    fold: _dialog,
    desktop: _dialog,
    files: ['lib/features/channel_joint_section_actions.dart'],
  ),
  CloseSurface(
    'member-connect-dialog',
    kind: SurfaceKind.dialog,
    web: 'ConnectYourServersDialog.tsx uses DialogCard with X and Escape',
    webOutside: WebOutside.stays,
    phone: _dialog,
    fold: _dialog,
    desktop: _dialog,
    files: ['lib/features/channel_joint_section_actions.dart'],
  ),
  CloseSurface(
    'joint-connect-menu',
    kind: SurfaceKind.popup,
    web: 'ConnectedServersMenu.tsx DropdownMenu closes on Escape and outside press',
    phone: _menu,
    fold: _menu,
    desktop: _menu,
    files: ['lib/features/channel_joint_section_actions.dart'],
  ),
];
