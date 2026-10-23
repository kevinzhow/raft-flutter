import 'close_surface.dart';

const _x = Affordance.x,
    _esc = Affordance.esc,
    _scrim = Affordance.scrim,
    _sys = Affordance.systemBack;

/// Popovers, menus, selects, toasts and other transient overlays.
const popupSurfaces = <CloseSurface>[
  CloseSurface(
    'select-field',
    kind: SurfaceKind.popup,
    web:
        'ui/FormField.tsx:1 native <select> / SelectContent: Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: [
      '../../packages/raft_ui/lib/src/select_field.dart',
      'lib/features/connected_app_editor.dart',
      'lib/features/resource_view.dart',
    ],
  ),
  CloseSurface(
    'dropdown-menu',
    kind: SurfaceKind.popup,
    web: 'layout/Sidebar.tsx:1566 (create-agent menu Esc) + outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: [
      '../../packages/raft_ui/lib/src/design_primitives.dart',
      'lib/features/desktop_directory_view.dart',
      'lib/features/search_filter_bar.dart',
    ],
  ),
  CloseSurface(
    'sidebar-context-menu',
    kind: SurfaceKind.popup,
    web: 'layout/Sidebar.tsx:1761 (Esc) + DismissBackdrop (outside press)',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: [
      'lib/features/workspace_view_sidebar_menus.dart',
      '../../packages/raft_ui/lib/src/sidebar_menus.dart',
    ],
  ),
  CloseSurface(
    'sidebar-sort-menu',
    kind: SurfaceKind.popup,
    web: 'layout/Sidebar.tsx:1540 (Esc) + pointerdown outside',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['lib/features/sidebar_sort_menu.dart'],
  ),
  CloseSurface(
    'server-switcher',
    kind: SurfaceKind.popup,
    web: 'ui/ServerSwitcherMenu.tsx:279-283 (mousedown outside + Esc)',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['../../packages/raft_ui/lib/src/server_switcher.dart'],
  ),
  CloseSurface(
    'notification-center',
    kind: SurfaceKind.popup,
    web:
        'layout/NotificationTrigger.tsx:55-60 Base UI Popover: Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['lib/features/system_notification_center.dart'],
  ),
  CloseSurface(
    'thread-menu',
    kind: SurfaceKind.popup,
    web: 'message/ThreadOverflowMenu.tsx:24 Base UI Menu: Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['lib/features/thread_actions.dart'],
  ),
  CloseSurface(
    'message-context-menu',
    kind: SurfaceKind.popup,
    web:
        'message/MessageItem.tsx:5103-5109 DismissBackdrop (outside press), scroll/resize close',
    phone: {_scrim, _sys},
    fold: {_scrim, _sys},
    desktop: {_scrim, _sys},
    files: [
      'lib/features/chat_view.dart',
      'lib/features/resource_view.dart',
      '../../packages/raft_ui/lib/src/message_context_menu.dart',
    ],
  ),
  CloseSurface(
    'toast',
    kind: SurfaceKind.toast,
    web:
        'LocalizedToastProvider.tsx:35,61-69 ToastClose unless hasClose === false',
    phone: {_x},
    fold: {_x},
    desktop: {_x},
    files: [
      '../../packages/raft_ui/lib/src/toast.dart',
      'lib/features/workspace_view.dart',
      'lib/features/thread_agent_followers_view.dart',
    ],
    status: 'fixed',
    fix:
        'RaftToastPortal renders the Web default toast (icon + close + action); close was ignored in the icon-less layout',
  ),
  CloseSurface(
    'selection-toast',
    kind: SurfaceKind.toast,
    web:
        'ChatPanel.tsx:117, ThreadPanel.tsx:86 SELECTION_TOAST_OPTIONS dismissible:false; forwardToast.ts:28 hasClose false',
    none: {
      'phone':
          'Web gives the selection toast no close (auto timeout); asserted in chat_selection_consumer_test',
      'fold':
          'Web gives the selection toast no close (auto timeout); asserted in chat_selection_consumer_test',
      'desktop':
          'Web gives the selection toast no close (auto timeout); asserted in chat_selection_consumer_test',
    },
    files: ['lib/features/chat_view.dart'],
    status: 'fixed',
    fix: 'selectionToast.show(dismissible: false)',
  ),
  CloseSurface(
    'snackbar',
    kind: SurfaceKind.toast,
    web:
        'LocalizedToastProvider.tsx:61-69 (Web has no snackbar; every transient message is a toast with ToastClose)',
    phone: {_x},
    fold: {_x},
    desktop: {_x},
    files: [
      'lib/features/agent_scopes_view.dart',
      'lib/features/share_message_link.dart',
      'lib/features/workspace_browser.dart',
      'lib/features/fleet_views.dart',
      'lib/features/source_channel_files_actions.dart',
      'lib/features/chat_view.dart',
      'lib/features/attachment_view.dart',
      '../../packages/raft_ui/lib/src/announcement_modal.dart',
    ],
    status: 'fixed',
    fix: 'theme SnackBarThemeData.showCloseIcon (lead)',
  ),
  CloseSurface(
    'reaction-picker',
    kind: SurfaceKind.popup,
    web:
        'message/MessageItem.tsx:4009-4033 pointerdown outside, Esc, scroll, resize',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['lib/features/chat_view.dart'],
  ),
  CloseSurface(
    'thread-followers',
    kind: SurfaceKind.popup,
    web: 'thread/ThreadAgentFollowers.tsx Base UI Popover: Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: [
      '../../packages/raft_ui/lib/src/thread_followers.dart',
      'lib/features/thread_agent_followers_view.dart',
    ],
    status: 'fixed',
    fix:
        'RaftDismissScope: Escape closes the popover with focus still on the trigger',
  ),
  CloseSurface(
    'inline-badge-editor',
    kind: SurfaceKind.popup,
    web:
        'InlineBadgeEditor.tsx:173 mousedown outside + DropdownMenuPopup (Esc)',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['../../packages/raft_ui/lib/src/inline_badge_editor.dart'],
  ),
  CloseSurface(
    'agent-overflow-menu',
    kind: SurfaceKind.popup,
    web:
        'agent/AgentProfileOverflowMenu.tsx:108 DropdownMenu (Base UI): Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['../../packages/raft_ui/lib/src/agent_profile.dart'],
  ),
  CloseSurface(
    'admin-principal-picker',
    kind: SurfaceKind.popup,
    web:
        'settings/SettingsPanel.tsx:2626-2638 mousedown outside (no Escape in Web)',
    phone: {_scrim, _sys},
    fold: {_scrim, _sys},
    desktop: {_scrim, _sys},
    files: ['../../packages/raft_ui/lib/src/settings_administration.dart'],
  ),
  CloseSurface(
    'agent-select',
    kind: SurfaceKind.popup,
    web:
        'agent/RuntimeConfigFields.tsx:32 raft-ui Select (Base UI): Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['../../packages/raft_ui/lib/src/agent_create_form.dart'],
  ),
  CloseSurface(
    'agent-combobox',
    kind: SurfaceKind.popup,
    web:
        'agent/RuntimeChoiceCombobox.tsx Combobox (Base UI): Esc, outside press; the input is the field',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['../../packages/raft_ui/lib/src/agent_combobox.dart'],
  ),
  CloseSurface(
    'feedback-close-menu',
    kind: SurfaceKind.popup,
    web:
        'external hands-feedback ReporterCloseSplitButton (not in the Web source tree)',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['../../packages/raft_ui/lib/src/feedback_workspace.dart'],
    status: 'n/a',
  ),
  CloseSurface(
    'runtime-usage-card',
    kind: SurfaceKind.popup,
    web:
        'machine/RuntimeAccountUsageChip.tsx:520-540 pinned popover: Esc, pointerdown outside; CloseButton :234',
    fold: {_x, _esc, _scrim, _sys},
    desktop: {_x, _esc, _scrim, _sys},
    none: {
      'phone':
          'phones open the bottom sheet (dialog family: runtime-usage-sheet)',
    },
    files: [
      '../../packages/raft_ui/lib/src/hover_card.dart',
      '../../packages/raft_ui/lib/src/runtime_usage_card.dart',
    ],
    status: 'fixed',
    fix:
        'RaftHoverCard: a pinned card closes on Android Back (RaftBackDismiss)',
  ),
  CloseSurface(
    'section-emoji-picker',
    kind: SurfaceKind.popup,
    web:
        'layout/SidebarSectionEmojiPicker.tsx Popover (Base UI): Esc, outside press; the dialog stays open',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['../../packages/raft_ui/lib/src/sidebar_section_dialog.dart'],
  ),
  CloseSurface(
    'composer-suggestions',
    kind: SurfaceKind.popup,
    web:
        'hooks/useAutocomplete.ts:76 Escape dismisses (no outside-press handler; typing or blur ends the trigger)',
    phone: {_esc},
    fold: {_esc},
    desktop: {_esc},
    files: ['../../packages/raft_ui/lib/src/components.dart'],
  ),
  CloseSurface(
    'rail-help-menu',
    kind: SurfaceKind.popup,
    web:
        'layout/LeftRail.tsx:495-525 Popover (openOnHover): Esc, outside press',
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    none: {
      'phone':
          'the Help popover hangs off the wide rail only (LeftRail side === left)',
    },
    files: [
      '../../packages/raft_ui/lib/src/workspace_shell.dart',
      'lib/features/public_server_view.dart',
    ],
  ),
  CloseSurface(
    'tooltip',
    kind: SurfaceKind.popup,
    web: 'ui/Tooltip.tsx Base UI Tooltip: Esc (pointer-hover surface)',
    fold: {_esc},
    desktop: {_esc},
    none: {
      'phone':
          'tooltips are pointer-only (docs/parity.md); a touch never opens one',
    },
    files: ['../../packages/raft_ui/lib/src/tooltip.dart'],
    status: 'approved',
  ),
  CloseSurface(
    'hover-card',
    kind: SurfaceKind.popup,
    web:
        'Base UI PreviewCard: pointer-hover surface; Esc and outside press close it',
    fold: {_esc, _scrim},
    desktop: {_esc, _scrim},
    none: {
      'phone':
          'hover cards are pointer-only (docs/parity.md); a touch never opens one',
    },
    files: ['../../packages/raft_ui/lib/src/hover_card.dart'],
    status: 'approved',
  ),
  CloseSurface(
    'message-hover-toolbar',
    kind: SurfaceKind.popup,
    web:
        'message/MessageItem.tsx:4375 MessageHoverToolbar: follows the pointer, no close control',
    none: {
      'phone':
          'the strip is a hover affordance; touch reaches the same actions through the long-press menu',
      'fold': 'the strip follows the pointer (hover); Web has no close control',
      'desktop':
          'the strip follows the pointer (hover); Web has no close control',
    },
    files: ['../../packages/raft_ui/lib/src/message_row_recipe.dart'],
    status: 'n/a',
  ),
];
