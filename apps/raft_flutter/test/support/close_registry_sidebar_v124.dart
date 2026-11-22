import 'close_surface.dart';

const _dialog = {Affordance.x, Affordance.esc, Affordance.systemBack};
const _modal = {..._dialog, Affordance.scrim};

const workspaceHistorySurface = CloseSurface(
  'workspace-history-menu',
  kind: SurfaceKind.popup,
  web: 'components/topbar/HistoryMenu.tsx DropdownMenu: Escape and outside press',
  desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
  none: {
    'phone': 'native phone navigation uses the page stack',
    'fold': 'History controls are native desktop chrome',
  },
  files: ['lib/features/workspace_history_controls.dart'],
);

const sidebarV124Dialogs = [
  CloseSurface(
    'sidebar-channel-leave-confirmation',
    kind: SurfaceKind.dialog,
    web: 'LeaveChannelConfirmDialog.tsx ConfirmDialog',
    webOutside: WebOutside.stays,
    phone: _dialog,
    fold: _dialog,
    desktop: _dialog,
    files: ['lib/features/workspace_view_sidebar_menus.dart'],
  ),
  CloseSurface(
    'sidebar-section-add-conversations',
    kind: SurfaceKind.dialog,
    web: 'SidebarSectionAddConversationsDialog.tsx DialogCard with closeOnBackdrop',
    webOutside: WebOutside.closes,
    phone: {..._modal, Affordance.drag},
    fold: _modal,
    desktop: _modal,
    files: [
      'lib/features/workspace_view_sidebar_menus.dart',
      '../../packages/raft_ui/lib/src/sidebar_section_dialog.dart',
    ],
  ),
  CloseSurface(
    'create-external-channel-invites',
    kind: SurfaceKind.dialog,
    web: 'CreateChannelDialog.tsx external review DialogCard',
    webOutside: WebOutside.stays,
    phone: _dialog,
    fold: _dialog,
    desktop: _dialog,
    files: [
      'lib/features/create_channel_dialog.dart',
      'lib/features/external_invite_channel_dialog.dart',
    ],
  ),
];
