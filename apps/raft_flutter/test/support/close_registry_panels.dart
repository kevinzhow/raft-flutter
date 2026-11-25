import 'close_surface.dart';

const _x = Affordance.x,
    _back = Affordance.back,
    _esc = Affordance.esc,
    _scrim = Affordance.scrim,
    _sys = Affordance.systemBack;

/// Side panels, detail pages and full-page overlays of the workspace shell.
/// Web columns: components/ui/PanelHeader.tsx (`onMobileBack` is `md:hidden`
/// by default, `lg:hidden` for ThreadPanel, `backButtonVisibility="always"`
/// for Search / Activity content slots), profile/ProfilePanel.tsx (X
/// `hidden md:flex`, Escape), message/ThreadPanel.tsx (X `lg:flex`, Escape),
/// ui/OverflowSheet.tsx (Escape, outside press, swipe; no desktop X for the
/// channel drawer).
const panelSurfaces = <CloseSurface>[
  CloseSurface(
    'profile-human',
    kind: SurfaceKind.panel,
    web: 'HumanDetailPanel.tsx: Back md:hidden, X hidden md:flex; ProfilePanel Esc',
    phone: {_back, _sys},
    // A medium window covers the conversation with the pane on top: its head
    // draws Back in place of the desktop X.
    fold: {_back, _esc, _sys, _scrim},
    desktop: {_x, _esc, _sys, _scrim},
    files: ['lib/features/profile_side_panel.dart'],
    status: 'approved',
    fix:
        'scrim: owner-approved outside tap (docs/parity.md); fold: the pane '
        'covers and draws Back (screen classes, Kevin 2026-11-25)',
  ),
  CloseSurface(
    'profile-agent',
    kind: SurfaceKind.panel,
    web: 'AgentDetailPanel.tsx: Back md:hidden, X hidden md:flex; Esc',
    phone: {_back, _sys},
    fold: {_back, _esc, _sys, _scrim},
    desktop: {_x, _esc, _sys, _scrim},
    files: ['lib/features/agent_detail_view.dart'],
    status: 'approved',
    fix:
        'header X (97b3f5f7), outside tap (39e0c61c); fold: the pane covers '
        'and draws Back (screen classes, Kevin 2026-11-25)',
  ),
  CloseSurface(
    'profile-external',
    kind: SurfaceKind.panel,
    web: 'ExternalIdentityDetailPanel.tsx: Back md:hidden, X hidden md:flex',
    phone: {_back, _sys},
    fold: {_x, _esc, _sys, _scrim},
    desktop: {_x, _esc, _sys, _scrim},
    files: ['lib/features/external_identity.dart'],
    status: 'approved',
  ),
  CloseSurface(
    'computers-rack-side-panel',
    kind: SurfaceKind.panel,
    web: 'ProfilePanel -> MachinePanelHeader.tsx:51-63: X (hidden md:flex, aria-label Close); ProfilePanel.tsx:304 Escape (useShortcutLayer "panel": an overlay or a field handling Escape takes it first)',
    none: {
      'phone': 'a phone opens the computer as its own page (computer-detail), not beside the rack',
    },
    fold: {_x, _esc, _sys},
    desktop: {_x, _esc, _sys},
    files: [
      'lib/features/computers_rack/computers_rack_page.dart',
      'lib/features/computer_detail_view.dart',
    ],
    status: 'fixed',
    fix: 'header X added; closing returns to the Computers page (it went to Settings); Escape in a rename or description field cancels the edit only',
  ),
  CloseSurface(
    'thread-panel',
    kind: SurfaceKind.panel,
    web:
        'features/thread/ThreadPanelHeader.tsx: Back lg:hidden, X lg:flex, Esc',
    phone: {_back, _sys},
    fold: {_back, _esc, _sys},
    desktop: {_x, _esc, _sys},
    files: [
      'lib/features/workspace_view.dart',
      'lib/features/thread_workspace_header.dart',
      '../../packages/raft_ui/lib/src/thread_composition.dart',
    ],
  ),
  CloseSurface(
    'channel-settings',
    kind: SurfaceKind.drawer,
    web: 'OverflowSheet.tsx (hideDesktopClose): Back md:hidden, Esc, outside press, swipe',
    phone: {_back, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: [
      'lib/features/channel_settings.dart',
      '../../packages/raft_ui/lib/src/channel_settings_sheet.dart',
    ],
    status: 'fixed',
    fix: 'RaftDismissScope: Escape runs the unsaved-draft guard',
  ),
  CloseSurface(
    'channel-members-page',
    kind: SurfaceKind.page,
    web: 'ChannelMembers.tsx in the bare OverflowSheet (phone drawer): Back md:hidden',
    phone: {_back, _sys},
    none: {
      'fold': 'wide layouts open the members dialog (channel-members-dialog) or the drawer sub-page (channel-settings)',
      'desktop': 'wide layouts open the members dialog (channel-members-dialog) or the drawer sub-page (channel-settings)',
    },
    files: [
      'lib/features/channel_members.dart',
      // The phone's bare OverflowSheet the shell hosts the page in.
      '../../packages/raft_ui/lib/src/channel_overflow_sheet.dart',
    ],
  ),
  CloseSurface(
    'channel-members-dialog',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web: 'ChannelMembers.tsx:1090,1334 Modal (Esc, no backdrop close) + X',
    fold: {_x, _esc, _sys},
    desktop: {_x, _esc, _sys},
    none: {'phone': 'phones open channel-members-page'},
    files: ['lib/features/channel_members.dart'],
    status: 'fixed',
    fix: 'showRaftModal binds Escape (RaftDismissScope)',
  ),
  CloseSurface(
    'directory-human-detail',
    kind: SurfaceKind.page,
    web: 'Phone: a route page, HumanDetailPanel.tsx Back md:hidden. From 768 /human/:id opens the ProfilePanel on Members (useMembersProfileRedirect.tsx:38-52, MainLayout.tsx:814-817): HumanDetailPanel.tsx:613-621 X hidden md:flex, ProfilePanel.tsx:304 Escape',
    phone: {_back, _sys},
    desktop: {_x, _esc, _sys},
    fold: {_x, _esc, _sys},
    files: [
      'lib/features/member_profile_view.dart',
      'lib/features/desktop_detail_host.dart',
    ],
    status: 'fixed',
    fix: 'phone Back was missing; the desktop X was hidden (showClose false) and is shown for a directory detail',
  ),
  CloseSurface(
    'conversation-search',
    kind: SurfaceKind.page,
    web: 'MainLayout.tsx ConversationSearchRoute and SearchPageHeader.tsx scoped Back',
    phone: {_back, _esc, _sys},
    none: {
      'fold':
          'A wide conversation header opens the channel-seeded quick switcher',
      'desktop':
          'A wide conversation header opens the channel-seeded quick switcher',
    },
    files: [
      'lib/features/resource_view.dart',
      'lib/features/workspace_view.dart',
    ],
  ),
  CloseSurface(
    'search-agent-slot',
    kind: SurfaceKind.panel,
    web: 'MainLayout.tsx renderContentSlot: AgentById onBack=closeSlot. Escape belongs to the results rail.',
    phone: {_back, _sys},
    fold: {_back, _sys},
    desktop: {_back, _sys},
    files: ['lib/features/workspace_view.dart'],
    status: 'fixed',
    fix: 'FleetDetail.backAlways',
  ),
  CloseSurface(
    'search-human-slot',
    kind: SurfaceKind.panel,
    web: 'MainLayout.tsx renderContentSlot: HumanById onBack=closeSlot. Escape belongs to the results rail.',
    phone: {_back, _sys},
    fold: {_back, _sys},
    desktop: {_back, _sys},
    files: ['lib/features/workspace_view.dart'],
    status: 'fixed',
    fix: 'MemberProfileView.onBack in a Search / Activity slot',
  ),
];
