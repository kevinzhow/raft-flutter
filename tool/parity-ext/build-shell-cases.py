#!/usr/bin/env python3
"""Append the shell & navigation cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Run after build-cases.py, build-channel-header.py,
build-announcements.py and build-search-overlay-cases.py (when present);
idempotent: every `components.shell.*` case is replaced, all other cases are
kept. Also writes tool/parity-ext/fixtures/shell.json, the data both providers
render (channels, DMs, unread counts, drafts, sidebar order presets).

Derivation (raft-source packages/web/src):
  components/layout/Sidebar.tsx        (ChannelRow / DmRow / AgentDmRow, sections,
                                        sort menu, row / section / surface menus)
  components/layout/LeftRail.tsx       (workspace rail, server switcher, help)
  components/layout/SidebarSectionDialog.tsx + SidebarSectionEmojiPicker.tsx
  components/ui/ServerSwitcherMenu.tsx, ConfirmDialog.tsx, BottomSheet.tsx,
  OverflowSheet.tsx, Banner.tsx, EmptyState.tsx, raft-ui toast
Ids: components.shell.<platform>.<surface>.<theme>. Props `preset` (a key of
fixtures/shell.json `presets`) selects the seeded workspace; capture
interactions open the menus / dialogs on both providers.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path, raft_source  # noqa: E402
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
SERVER = 'visual-server'
CREATED = '2026-06-18T00:00:00.000Z'


def channel(cid, name, description=None, kind='channel', joined=True, **extra):
    return {'id': cid, 'serverId': SERVER, 'name': name, 'description': description, 'type': kind,
            'createdAt': CREATED, 'joined': joined, **extra}


def dm(cid, peer_id, peer_type, name, display, description=None, **extra):
    return {'id': cid, 'serverId': SERVER, 'name': f'dm-{peer_id}', 'description': None, 'type': 'dm',
            'createdAt': CREATED, 'joined': True, 'peerId': peer_id, 'peerType': peer_type,
            'peerName': name, 'peerDisplayName': display, 'peerDescription': description, **extra}


CHANNELS = [
    channel('shell-general', 'general', 'Company-wide announcements'),
    channel('shell-design', 'design', 'Product and UI decisions'),
    channel('shell-engineering', 'engineering', 'Build and release'),
    channel('shell-leadership', 'leadership', 'Planning', kind='private'),
    channel('shell-random', 'random', 'Off-topic', activityMuted=True),
    channel('shell-support', 'support', 'Customer questions'),
    channel('shell-ideas', 'ideas', 'Things to try', joined=False),
    channel('shell-long', 'release-candidate-validation-and-regression-tracking', 'Long name'),
]
JOINT = channel('shell-partner', 'partner-sync', 'Shared with Acme', kind='joint',
                jointRole='host', jointPeerStatus='active', jointPeerServerName='Acme')
DMS = [
    dm('shell-dm-designer', 'visual-human-designer', 'user', 'designer', 'Designer'),
    dm('shell-dm-cindy', 'agent-cindy', 'agent', 'Cindy', 'Cindy', 'Keeps visual testing release notes aligned.'),
    dm('shell-dm-product', 'agent-product-ux', 'agent', 'Product-UX-Designer', 'Product UX Designer',
       'Turns product feedback, screenshots, and release notes into actionable UX specs.'),
    dm('shell-dm-jiacheng', 'visual-human-jiacheng', 'user', 'jiacheng', 'Jiacheng'),
]
ACTIVITY = {c['id']: f'2026-06-19T12:{20 - i:02d}:00.000Z' for i, c in enumerate([*CHANNELS, JOINT, *DMS])}

DEFAULT_ORDER = ['system:pinned', 'system:joint', 'system:channels', 'system:dms']
BASE = {
    'channels': [c['id'] for c in CHANNELS],
    'joint': [JOINT['id']],
    'dms': [d['id'] for d in DMS],
    'unread': {'shell-general': 12, 'shell-random': 4, 'shell-support': 2, 'shell-dm-cindy': 2,
               'shell-dm-jiacheng': 105},
    'drafts': {'shell-engineering': 'Looking at the build', 'shell-dm-product': 'Can you check'},
    'mentions': ['shell-support'],
    'pinned': [{'kind': 'channel', 'id': 'shell-engineering'}, {'kind': 'agent', 'id': 'agent-cindy'}],
    'customSections': [],
    'sectionOrder': DEFAULT_ORDER,
    'placements': [],
    'sortModes': {},
    'selected': 'shell-design',
    'loading': False,
}
CUSTOM_ORDER = ['system:pinned', 'sec-launch', 'sec-backlog', 'system:joint', 'system:channels', 'system:dms']
PRESETS = {
    'default': {},
    'empty': {'channels': [], 'joint': [], 'dms': [], 'unread': {}, 'drafts': {}, 'mentions': [],
              'pinned': [], 'selected': None},
    'mobile': {'selected': None},
    'loading': {'channels': [], 'joint': [], 'dms': [], 'unread': {}, 'drafts': {}, 'mentions': [],
                'pinned': [], 'selected': None, 'loading': True},
    'custom': {
        'customSections': [
            {'id': 'sec-launch', 'name': 'Launch', 'emoji': '\U0001F680', 'sortMode': 'manual'},
            {'id': 'sec-backlog', 'name': 'Backlog', 'emoji': None, 'sortMode': 'az'},
        ],
        'sectionOrder': CUSTOM_ORDER,
        'placements': [
            {'kind': 'channel', 'id': 'shell-support', 'sectionId': 'sec-launch', 'position': 0},
            {'kind': 'channel', 'id': 'shell-dm-product', 'sectionId': 'sec-launch', 'position': 1},
        ],
    },
    'sorted': {'sortModes': {'channels': 'az', 'dms': 'az', 'pinned': 'recent'}},
}
PRESETS = {name: {**BASE, **override} for name, override in PRESETS.items()}
# phone home with custom sections and no conversation open (build-list-pages.py section dialogs)
PRESETS['mobile-custom'] = {**PRESETS['custom'], 'selected': None}
PRESETS['profile-reader'] = {**PRESETS['default'], 'viewerRole': 'member'}

SERVERS = [
    {'id': SERVER, 'name': 'Visual Server', 'slug': 'visual'},
    {'id': 'shell-server-acme', 'name': 'Acme Design', 'slug': 'acme'},
    {'id': 'shell-server-side', 'name': 'Side Project', 'slug': 'side'},
]
SERVER_UNREAD = {
    SERVER: {'unreadCount': 7, 'serverPushMuted': False, 'activityUnreadCount': 3},
    'shell-server-acme': {'unreadCount': 3, 'serverPushMuted': False, 'activityUnreadCount': 3},
    'shell-server-side': {'unreadCount': 12, 'serverPushMuted': True, 'activityUnreadCount': 12},
}

ROW_PARENT = {
    'id': 'shell-parent', 'channelId': 'shell-design', 'serverId': SERVER,
    'messageType': 'chat', 'senderType': 'user', 'senderId': 'visual-human-designer',
    'senderName': 'Designer', 'content': 'The visual review is ready.',
    'createdAt': '2026-06-19T12:00:00.000Z', 'seq': 1, 'threadId': 'shell-thread',
}
ROW_REPLY = {
    **ROW_PARENT, 'id': 'shell-reply', 'channelId': 'shell-thread', 'threadId': None,
    'content': 'I checked the desktop and phone captures.',
    'createdAt': '2026-06-19T12:01:00.000Z', 'seq': 2,
}
ROW_MEMBER = {
    'id': 'visual-human-designer', 'userId': 'visual-human-designer',
    'serverId': SERVER, 'name': 'designer', 'displayName': 'Designer',
    'description': 'Reviews the visual fixtures.', 'role': 'member',
    'avatarUrl': None, 'joinedAt': CREATED,
}
RACK_MACHINES = [{
    'id': 'shell-rack', 'name': 'Review computer', 'hostname': 'review-computer',
    'description': 'Captures release fixtures.', 'os': 'linux', 'status': 'online',
    'statusVersion': 1, 'runtimes': ['codex'], 'isComputer': True,
    'computerVersion': '0.0.50', 'daemonVersion': '0.65.0', 'createdAt': CREATED,
}]

PRIMITIVES = {
    'confirms': {
        'danger': {'title': 'Delete channel',
                   'message': 'Delete #design? This permanently removes the channel and its messages.',
                   'confirmLabel': 'Delete channel'},
        'warning': {'title': 'Stop agent',
                    'message': 'Stop Cindy? She stays offline until you start her again.',
                    'confirmLabel': 'Stop agent', 'variant': 'warning'},
        'ack': {'title': 'Heads up', 'message': 'This workspace is read-only until billing is updated.',
                'confirmLabel': 'Got it', 'variant': 'primary', 'hideCancel': True},
    },
    'banners': [
        {'intent': 'warning', 'text': 'Your plan is over its agent limit.'},
        {'intent': 'destructive', 'icon': True, 'title': 'Sync failed',
         'text': 'We could not reach the server. Check your connection.'},
        {'intent': 'info', 'icon': True, 'text': 'A new version is available.', 'action': 'Reload'},
        {'intent': 'success', 'icon': True, 'title': 'Saved', 'text': 'Your changes are live.'},
        {'intent': 'warning', 'density': 'sm', 'text': 'Compact warning banner.'},
        {'intent': 'info', 'density': 'lg', 'icon': True, 'title': 'Large banner',
         'text': 'Roomier padding for page-level notices.'},
    ],
    'empties': {
        'full': {'icon': 'inbox', 'title': 'No saved messages',
                 'description': 'Messages you save show up here.', 'action': 'Browse channels'},
        'title': {'icon': 'search', 'title': 'No results'},
    },
    'toasts': {
        'success': {'kind': 'success', 'title': 'Link copied'},
        'error': {'kind': 'error', 'title': 'Could not update notifications'},
        'info': {'kind': 'info', 'title': 'Agent restarted', 'description': 'Cindy is back online.'},
        'plain': {'kind': 'success', 'title': 'Copied 3 message links', 'plain': True},
        'action': {'kind': 'info', 'title': 'Channel archived', 'action': 'Undo'},
    },
}

fixture = {
    'name': 'raft-flutter parity extension: shell & navigation',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'channels': [*CHANNELS, JOINT],
    'dms': DMS,
    'activity': ACTIVITY,
    'servers': SERVERS,
    'serverUnread': SERVER_UNREAD,
    'presets': PRESETS,
    'primitives': PRIMITIVES,
    # The rail's Settings dot reads the feedback unread total; the settings
    # fixture (same /api routes, every case) has unread replies.
    'routes': {
        'GET /product-feedback/tickets': {'tickets': [], 'unread_total': 0, 'next_cursor': None},
        # The rail refetches the cross-server summary on mount.
        'GET /servers/unread-summary': [{'serverId': k, **v} for k, v in SERVER_UNREAD.items()],
    },
    'routeSets': {
        'home': {
            'GET /channels': [*CHANNELS, JOINT],
            'GET /channels/dm': DMS,
            'GET /messages/channel/shell-general': {'messages': [], 'hasMore': False},
        },
        'refused': {
            'GET /channels': [*CHANNELS, JOINT],
            'GET /channels/dm': DMS,
            'GET /channels/shell-refused': {
                '$status': 404,
                '$body': {'error': 'Channel not found or not visible'},
            },
        },
        'row': {
            'GET /channels': [*CHANNELS, JOINT],
            'GET /channels/dm': DMS,
            'GET /channels/shell-design': CHANNELS[1],
            'GET /channels/shell-design/threads/shell-parent': {'threadChannelId': 'shell-thread'},
            'GET /channels/shell-thread': channel('shell-thread', 'visual-review', kind='thread'),
            'GET /messages/channel/shell-design': {
                'messages': [ROW_PARENT], 'hasMore': False,
                'threadSummariesByParentMessageId': {
                    'shell-parent': {'threadChannelId': 'shell-thread', 'replyCount': 1},
                },
            },
            'GET /messages/context/shell-parent': {
                'messages': [ROW_PARENT], 'targetMessageId': 'shell-parent',
                'hasOlder': False, 'hasNewer': False,
            },
            'GET /messages/channel/shell-thread': {'messages': [ROW_REPLY], 'hasMore': False},
            'GET /tasks/channel/shell-design': [],
            f'GET /servers/{SERVER}/members/visual-human-designer/profile': ROW_MEMBER,
            f'PATCH /servers/{SERVER}/sidebar-order': {},
        },
        'rack': {
            f'GET /servers/{SERVER}/machines': {
                'machines': RACK_MACHINES, 'latestComputerVersion': '0.0.50',
            },
            f'GET /servers/{SERVER}/machines/shell-rack/workspaces': [],
        },
    },
}
fixture['routeSets']['row-profile-reader'] = {
    **fixture['routeSets']['row'],
    f'GET /servers/{SERVER}/members/visual-human-designer/profile': {
        **ROW_MEMBER, 'membershipStatus': 'active',
    },
}
(here / 'fixtures' / 'shell.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')

# (surface id) -> spec. `region` is the data-testid / ValueKey of the crop.
SIDEBAR_REGION = 'shell-sidebar'


def spec(platform, surface, *, preset='default', region, interactions=None, android=None, title,
         viewport=None, props=None, themes=None,
         hint='packages/web/src/components/layout/Sidebar.tsx'):
    return {'platform': platform, 'surface': surface, 'preset': preset, 'region': region,
            'interactions': interactions or [], 'android': android or [], 'title': title,
            'viewport': viewport or (DESKTOP if platform == 'desktop' else MOBILE),
            'props': props or {}, 'themes': themes, 'hint': hint}


def click(selector):
    return {'type': 'click', 'target': selector}


def tid(testid):
    return f'[data-testid="{testid}"]'


def row(channel_id):
    return f'[data-sidebar-channel-id="{channel_id}"]'


def rightclick(selector, x=None, y=None):
    step = {'type': 'rightclick', 'target': selector}
    if x is not None:
        step.update(x=x, y=y)
    return step


def hover(selector):
    return {'type': 'hover', 'target': selector}


def tap(key, scroll=True):
    step = {'type': 'tap', 'key': key}
    if not scroll:
        step['scroll'] = False  # already on screen: Playwright does not scroll, ensureVisible would
    return step


def secondary(key, x=None, y=None):
    step = {'type': 'secondaryTap', 'key': key}
    if key.startswith(('sidebar-channel-', 'sidebar-agent:')):
        step['row'] = True
    if x is not None:
        step.update(x=x, y=y)
    return step


def hover_key(key):
    return {'type': 'hover', 'key': key}


RAIL = 'shell-rail-sidebar'
DIALOG_CARD = '[data-slot="modal-backdrop"] [data-slot="dialog-card"]'
DIALOG_CONTENT = '[data-slot="dialog-content"]'
HELP_POPUP = '[data-slot="popover-content"]'
HELP_FIRST_ITEM = HELP_POPUP + ' [data-slot="menu-item"]'
HELP_POPUP_THEMES = {'raft': 'raft-light', 'raft-dark': 'raft-dark'}
EXTRA = {'extra': 280}
SECTION_TOGGLE = 'sidebar-section-toggle-'
ANDROID_KEYS = {
    DIALOG_CARD: 'sidebar-section-dialog',
    DIALOG_CONTENT: 'shell-dialog',
    HELP_POPUP: 'workspace-help-popup',
    tid('shell-banners'): 'shell-banners',
    tid('shell-empty'): 'shell-empty',
    tid('shell-bottom-sheet'): 'shell-bottom-sheet',
    tid('shell-overflow-sheet'): 'shell-overflow-sheet',
    tid('localized-toast-row'): 'shell-toast',
}
SPECS = [
    spec('desktop', 'sidebar.default', region=RAIL, title='Rail and sidebar, default state'),
    spec('desktop', 'sidebar.empty', preset='empty', region=RAIL, title='Rail and sidebar, empty sections'),
    spec('desktop', 'sidebar.loading', preset='loading', region=RAIL, title='Rail and sidebar, loading rows'),
    spec('desktop', 'sidebar.custom', preset='custom', region=RAIL, title='Rail and sidebar, custom sections'),
    spec('desktop', 'sidebar.sorted', preset='sorted', region=RAIL, title='Rail and sidebar, alphabetical and recent sort'),
    spec('desktop', 'sidebar.collapsed', region=RAIL, title='Rail and sidebar, collapsed sections',
         interactions=[click(tid(SECTION_TOGGLE + 'channels')), click(tid(SECTION_TOGGLE + 'dms')),
                       click(tid(SECTION_TOGGLE + 'pinned'))],
         android=[tap('sidebar-disclosure-system:channels'), tap('sidebar-disclosure-system:dms'),
                  tap('sidebar-disclosure-system:pinned')]),
    spec('desktop', 'sidebar.row-hover', region=RAIL, title='Sidebar row hovered',
         interactions=[hover(row('shell-general'))], android=[hover_key('sidebar-channel-shell-general')]),
    spec('desktop', 'sidebar.sort-menu', region=RAIL, title='Sidebar section sort menu',
         interactions=[click('[data-sort-section="channels"]')],
         android=[tap('sidebar-sort-system:channels')]),
    spec('desktop', 'menu.channel', region=RAIL, props=EXTRA, title='Channel row context menu',
         interactions=[rightclick(row('shell-general'))], android=[secondary('sidebar-channel-shell-general')]),
    spec('desktop', 'menu.channel-muted', region=RAIL, props=EXTRA, title='Muted channel row context menu',
         interactions=[rightclick(row('shell-random'))], android=[secondary('sidebar-channel-shell-random')]),
    spec('desktop', 'menu.dm', region=RAIL, props=EXTRA, title='Human DM row context menu',
         interactions=[rightclick(row('shell-dm-designer'))], android=[secondary('sidebar-channel-shell-dm-designer')]),
    spec('desktop', 'menu.agent-dm', region=RAIL, props=EXTRA, title='Pinned agent DM row context menu',
         interactions=[rightclick('[data-slot="sidebar-item"]:has-text("Cindy")')],
         android=[secondary('sidebar-agent:agent-cindy')]),
    spec('desktop', 'menu.section', region=RAIL, props=EXTRA, title='Channels section context menu',
         interactions=[rightclick(tid(SECTION_TOGGLE + 'channels'), 30, 12)],
         android=[secondary('sidebar-section-system:channels', 38, 24)]),
    spec('desktop', 'menu.section-custom', preset='custom', region=RAIL, props=EXTRA,
         title='Custom section context menu',
         interactions=[rightclick('[data-testid="sidebar-custom-section-sec-launch"] button[aria-expanded]', 30, 12)],
         android=[secondary('sidebar-section-sec-launch', 38, 24)]),
    spec('desktop', 'menu.surface', region=RAIL, props=EXTRA, title='Sidebar surface context menu',
         interactions=[click(tid(SECTION_TOGGLE + 'channels')), click(tid(SECTION_TOGGLE + 'dms')),
                       click(tid(SECTION_TOGGLE + 'pinned')),
                       rightclick(tid('sidebar-scroll-surface'), 120, 500)],
         android=[tap('sidebar-disclosure-system:channels'), tap('sidebar-disclosure-system:dms'),
                  tap('sidebar-disclosure-system:pinned'), secondary('workspace-sidebar', 120, 500)]),
    spec('desktop', 'menu.move-to-section', preset='custom', region=RAIL, props={'extra': 520},
         title='Row context menu with Move to section submenu',
         interactions=[rightclick(row('shell-general')), hover('text=Move to section')],
         android=[secondary('sidebar-channel-shell-general'), hover_key('sidebar-menu-move-to-section')]),
    spec('desktop', 'dialog.new-section', region=DIALOG_CARD, props={'dialog': 'card'},
         title='New section dialog', hint='packages/web/src/components/layout/SidebarSectionDialog.tsx',
         interactions=[rightclick(tid(SECTION_TOGGLE + 'channels'), 30, 12), click('text=New section')],
         android=[secondary('sidebar-section-system:channels', 38, 24), tap('sidebar-menu-new-section')]),
    spec('desktop', 'dialog.edit-section', preset='custom', region=DIALOG_CARD, props={'dialog': 'card'},
         title='Rename section dialog', hint='packages/web/src/components/layout/SidebarSectionDialog.tsx',
         interactions=[rightclick('[data-testid="sidebar-custom-section-sec-launch"] button[aria-expanded]', 30, 12),
                       click('text=Rename / change icon')],
         android=[secondary('sidebar-section-sec-launch', 38, 24), tap('sidebar-menu-rename-section')]),
    spec('desktop', 'dialog.delete-section', preset='custom', region=DIALOG_CONTENT,
         title='Delete section confirm', hint='packages/web/src/components/ConfirmDialog.tsx',
         interactions=[rightclick('[data-testid="sidebar-custom-section-sec-launch"] button[aria-expanded]', 30, 12),
                       click('text=Delete section')],
         android=[secondary('sidebar-section-sec-launch', 38, 24), tap('sidebar-menu-delete-section')]),
    spec('desktop', 'dialog.archive-channel', region=DIALOG_CONTENT, title='Archive channel confirm',
         hint='packages/web/src/components/ConfirmDialog.tsx',
         interactions=[rightclick(row('shell-general')), click('text=Archive')],
         android=[secondary('sidebar-channel-shell-general'), tap('sidebar-menu-archive')]),
    spec('desktop', 'rail.help-menu', region=RAIL, props={'extra': 300}, title='Rail help menu',
         hint='packages/web/src/components/layout/LeftRail.tsx',
         interactions=[click(tid('left-rail-help'))], android=[tap('rail-help')]),
    spec('desktop', 'server.menu', region=RAIL, props=EXTRA, title='Server switcher menu',
         interactions=[click('[data-testid="workspace-left-rail"] button[aria-label^="Switch server"]')],
         android=[tap('rail-workspace')], hint='packages/web/src/components/ui/ServerSwitcherMenu.tsx'),
]

# New component-bounds contracts open the real LeftRail/WorkspaceView Help
# entry. The historical rail.help-menu whole-shell cases above stay unchanged:
# a popup-only result does not replace their frame/placement conclusions.
for compact in (False, True):
    for state in ('default', 'hover', 'focus'):
        interactions = [click(tid('left-rail-help'))]
        android = [tap('rail-help')]
        if state == 'hover':
            interactions.append(hover(HELP_FIRST_ITEM))
            android.append({'type': 'hover', 'finder': {
                'text': 'Raft Documentation', 'in': 'workspace-help-popup'}})
        elif state == 'focus':
            # Establish keyboard modality before focusing the real first row.
            # The Flutter focus interaction also sends Tab before requesting
            # that row's existing interactive node; neither provider fakes it.
            interactions += [{'type': 'tab', 'count': 1},
                             {'type': 'focus', 'target': HELP_FIRST_ITEM}]
            android.append({'type': 'focus', 'finder': {
                'text': 'Raft Documentation', 'in': 'workspace-help-popup'}})
        name = f'compact-{state}' if compact else state
        SPECS.append(spec(
            'desktop', f'rail.help-popup.{name}', region=HELP_POPUP,
            title=f'Actual Help popup bounds, {name}',
            viewport={**DESKTOP, 'height': 560} if compact else DESKTOP,
            props={'helpPopupState': state}, themes=HELP_POPUP_THEMES,
            hint='packages/web/src/components/layout/LeftRail.tsx (HelpPopover)',
            interactions=interactions, android=android))

# New current-Raft popup-bounds cases; historical rail/sidebar cases stay intact.
SORT_POPUP = '[data-slot="popover-content"]:has(button)'
ANDROID_KEYS[SORT_POPUP] = 'sidebar-sort-popover'
for sort_state in ('default', 'hover', 'focus'):
    sort_steps = [click('[data-sort-section="channels"]')]
    sort_android = [tap('sidebar-sort-system:channels')]
    if sort_state == 'hover':
        sort_steps.append(hover(SORT_POPUP + ' button:has-text("Recent")'))
        sort_android.append(hover_key('sidebar-sort-recent'))
    elif sort_state == 'focus':
        sort_steps.extend([
            {'type': 'tab', 'count': 1},
            {'type': 'focus', 'target': SORT_POPUP + ' button:has-text("Recent")'},
        ])
        sort_android.append({'type': 'focus', 'key': 'sidebar-sort-recent'})
    SPECS.append(spec(
        'desktop', f'sidebar.sort-popup.{sort_state}', region=SORT_POPUP,
        title=f'Actual Sidebar sort popup bounds, {sort_state}',
        props={'sortPopupState': sort_state, 'lang': 'en'}, themes=HELP_POPUP_THEMES,
        hint='packages/web/src/components/layout/SidebarSortMenu.tsx',
        interactions=sort_steps, android=sort_android))

MOBILE_HOME = 'shell-mobile-home'
SPECS += [
    spec('mobile', 'sidebar.default', preset='mobile', region=MOBILE_HOME, title='Mobile home sidebar, default state'),
    spec('mobile', 'sidebar.collapsed', preset='mobile', region=MOBILE_HOME, title='Mobile home sidebar, collapsed sections',
         interactions=[click(tid(SECTION_TOGGLE + 'channels')), click(tid(SECTION_TOGGLE + 'dms')),
                       click(tid(SECTION_TOGGLE + 'pinned'))],
         android=[tap('sidebar-disclosure-system:channels'), tap('sidebar-disclosure-system:dms'),
                  tap('sidebar-disclosure-system:pinned')]),
    spec('mobile', 'menu.channel', preset='mobile', region=MOBILE_HOME, title='Mobile channel row context menu',
         interactions=[rightclick(row('shell-general'))], android=[secondary('sidebar-channel-shell-general')]),
    spec('mobile', 'sidebar.sort-menu', preset='mobile', region=MOBILE_HOME, title='Mobile section sort menu',
         interactions=[click('[data-sort-section="channels"]')], android=[tap('sidebar-sort-system:channels', scroll=False)]),
]
SPECS += [
    spec('desktop', 'activity.frame', preset='mobile', region='shell-activity-frame', props={'route': 'activity'},
         title='Activity page, rail and master column edge',
         hint='packages/web/src/components/layout/MainLayout.tsx (masterDetailShellClassName) + LeftRail thinDivider'),
    spec('mobile', 'activity.frame', preset='mobile', region='shell-activity-frame', props={'route': 'activity'},
         title='Mobile Activity page, left edge',
         hint='packages/web/src/components/thread/ThreadsInbox.tsx'),
]
for platform in ('desktop', 'mobile'):
    for variant in ('danger', 'warning', 'ack'):
        SPECS.append(spec(platform, f'confirm.{variant}', region=DIALOG_CONTENT, title=f'Confirm dialog ({variant})',
                          hint='packages/web/src/components/ConfirmDialog.tsx'))
    SPECS.append(spec(platform, 'banner.all', region=tid('shell-banners'), title='Banner intents and densities',
                      hint='packages/web/src/components/ui/Banner.tsx'))
    for variant in ('full', 'title'):
        SPECS.append(spec(platform, f'empty.{variant}', region=tid('shell-empty'), title=f'Empty state ({variant})',
                          hint='packages/web/src/components/ui/EmptyState.tsx'))
    SPECS.append(spec(platform, 'bottomsheet.default', region=tid('shell-bottom-sheet'), title='Bottom sheet',
                      hint='packages/web/src/components/ui/BottomSheet.tsx'))
    SPECS.append(spec(platform, 'overflow.default', region=tid('shell-overflow-sheet'), title='Overflow sheet',
                      hint='packages/web/src/components/ui/OverflowSheet.tsx'))
    for variant in ('success', 'error', 'info', 'plain'):
        SPECS.append(spec(platform, f'toast.{variant}', region=tid('localized-toast-row'), title=f'Toast ({variant})',
                          hint='packages/web/src/components/LocalizedToastProvider.tsx'))

if (raft_source() / 'packages/web/src/store/channelAccessLoss.ts').is_file():
    current_themes = {suffix: THEMES[suffix] for suffix in ('brutal', 'elegant-dark')}
    desktop_review = {**DESKTOP, 'height': 900}
    unavailable = tid('shell-route') + ':has(' + tid('conversation-unavailable') + ')'
    ANDROID_KEYS[unavailable] = 'shell-route'
    for platform in ('desktop', 'mobile'):
        shell_hint = 'packages/web/src/components/layout/MainLayout.tsx'
        viewport = desktop_review if platform == 'desktop' else MOBILE
        SPECS.extend([
            spec(platform, 'home.index', preset='mobile', region='shell-route', viewport=viewport,
                 props={'extFixture': 'shell', 'routeSet': 'home', 'shell': 'browser'},
                 title='Home index route', themes=current_themes, hint=shell_hint),
            spec(platform, 'channel.access-lost', region='shell-route', viewport=viewport,
                 props={'extFixture': 'shell', 'routeSet': 'home', 'shell': 'browser'},
                 title='Channel lost after access was revoked', themes=current_themes,
                 hint='packages/web/src/features/channel/ChannelAccessLost.tsx'),
            spec(platform, 'channel.unavailable', preset='mobile', region=unavailable, viewport=viewport,
                 props={'route': 'channel/shell-refused', 'extFixture': 'shell', 'routeSet': 'refused', 'shell': 'browser'},
                 title='Channel link declined', themes=current_themes,
                 hint='packages/web/src/features/channel/ChannelAccessLost.tsx'),
            spec(platform, 'offline.cached', preset='mobile', viewport=viewport, region=(
                     tid('shell-route') + ':has(' + tid('offline-indicator') + ')'),
                 props={'extFixture': 'shell', 'shell': 'browser'},
                 title='Cached workspace while offline', themes=current_themes,
                 hint='packages/web/src/components/layout/OfflineServerLayout.tsx'),
        ])
    profile_open = tid('shell-route') + ':has(' + tid('profile-panel') + ')'
    offline_open = tid('shell-route') + ':has(' + tid('offline-indicator') + ')'
    profile_expanded = profile_open + ':has([data-testid="row-expand-profile"][aria-pressed="true"])'
    thread_open = profile_open + ':has(' + tid('thread-side-column') + ')'
    rack_open = tid('shell-route') + ':has(' + tid('computer-profile') + ')'
    for selector in (offline_open, profile_expanded, thread_open, rack_open):
        ANDROID_KEYS[selector] = 'shell-route'
    row_props = {
        'route': 'channel/shell-design', 'routeQuery': 'profile=human:visual-human-designer',
        'extFixture': 'shell', 'routeSet': 'row', 'shell': 'browser',
    }
    SPECS.extend([
        spec('desktop', 'row.profile-expanded', preset='profile-reader', region=profile_expanded,
             viewport={'width': 1600, 'height': 900, 'density': 1},
             props={**row_props, 'routeSet': 'row-profile-reader'},
             interactions=[click(tid('row-expand-profile'))],
             android=[tap('channel-profile-expand', scroll=False)],
             title='Conversation profile expanded', themes=current_themes, hint=shell_hint),
        spec('desktop', 'row.profile-moved', region=thread_open,
             viewport={'width': 1600, 'height': 900, 'density': 1},
             props={**row_props, 'routeQuery': row_props['routeQuery'] + '&thread=shell-design:shell-parent'},
             interactions=[click(tid('profile-overflow-trigger')), click(tid('column-move-left-profile'))],
             android=[tap('channel-profile-move', scroll=False), {'type': 'tapText', 'text': 'Move left'}],
             title='Profile after moving left of the thread', themes=current_themes, hint=shell_hint),
        spec('desktop', 'rack.profile', preset='mobile', region=rack_open,
             viewport=desktop_review,
             props={'route': 'computers', 'extFixture': 'shell', 'routeSet': 'rack', 'shell': 'browser'},
             interactions=[click(tid('rack-row-name-shell-rack'))],
             android=[tap('rack-row-shell-rack', scroll=False)],
             title='Computer profile open beside its rack', themes=current_themes, hint=shell_hint),
    ])

if (raft_source() / 'packages/web/src/components/topbar/HistoryMenu.tsx').is_file():
    history_popup = tid('desktop-history-menu')
    ANDROID_KEYS[history_popup] = 'topbar-history-menu'
    for variant in ('empty', 'recent'):
        SPECS.append(spec(
            'desktop', f'history.{variant}', region=history_popup,
            viewport={**DESKTOP, 'height': 900},
            props={'route': 'members', 'extFixture': 'shell', 'routeSet': 'home', 'shell': 'native'},
            interactions=[click(tid('desktop-history-trigger'))],
            android=[tap('topbar-history', scroll=False)],
            title=f'History menu ({variant})',
            themes={suffix: THEMES[suffix] for suffix in ('brutal', 'elegant-dark')},
            hint='packages/web/src/components/topbar/HistoryMenu.tsx',
        ))


def build_cases():
    cases = []
    for s in SPECS:
        for suffix, theme in (s['themes'] or THEMES).items():
            cid = f'components.shell.{s["platform"]}.{s["surface"]}.{suffix}'
            props = {'extCase': f'{s["platform"]}.{s["surface"]}', 'extKind': 'shell', 'parityTheme': theme,
                     'platform': s['platform'], 'surface': s['surface'], 'preset': s['preset'], **s['props']}
            capture = {
                'selector': s['region'] if s['region'].startswith('[') else f'[data-testid="{s["region"]}"]',
                'crop': 'element',
                'contract': 'component-bounds',
                'androidKey': ANDROID_KEYS.get(s['region'], s['region']),
                'interactions': s['interactions'],
                'androidInteractions': s['android'],
            }
            cases.append({
                'id': cid,
                'title': f'{s["title"]} {s["platform"]} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'shell',
                'category': 'extension/shell',
                'suite': 'raft-flutter-extension',
                'viewport': s['viewport'],
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': capture,
                'reactPathHint': s['hint'],
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_shell.dart '{s['platform']}.{s['surface']}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
    return cases


cases = build_cases()
path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.shell.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} shell cases appended ({len(manifest["cases"])} total)')
