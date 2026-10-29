#!/usr/bin/env python3
"""Append the members / agents / activity / saved cases to
tool/parity-ext/cases.json and write tool/parity-ext/fixtures/members.json.

Run after every other build-*.py (append-only: every `components.members-ext.*`
case is replaced, all other cases are kept in place, new ids go last).

Derivation (raft-source packages/web/src/components):
  layout/Sidebar.tsx         Members rail mode (Agents grouped by computer, Humans)
  agent/AgentDetailPanel.tsx tabs: profile, activity, chat, reminders, workspace,
                             integrations, mcp (+ ResetAgentDialog, ReportIssueDialog,
                             AgentProfileEditDialog)
  member/HumanDetailPanel.tsx, profile/ExternalIdentityDetailPanel.tsx
  member/InviteHumanDialog.tsx, member/RolePermissionHelpDialog.tsx
  agentMigration/*, saved/SavedPanel.tsx, layout MainLayout Activity master page

Ids (append-only, never rename): components.members-ext.<key>.<theme>
React: tool/parity-ext/host/MemberCases.tsx; Flutter:
apps/raft_flutter/test/parity/cases/ext_members.dart. Both read
tool/parity-ext/fixtures/members.json.
"""
import json
import os
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
COLUMN = DESKTOP  # the 240px Sidebar column is cropped out of the desktop viewport
PREFIX = 'components.members-ext.'
SID = 'visual-server'
AGENT_ID_FX = 'agent-product-ux'
CREATED = '2026-06-18T00:00:00.000Z'
SRC = 'packages/web/src/components/'

# ---------------------------------------------------------------- fixture
RAFT_SOURCE = pathlib.Path(os.environ.get(
    'PARITY_RAFT_SOURCE', '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source'))
ACTIVITY_FIXTURE = json.loads((RAFT_SOURCE / 'packages/visual-testing/shared/activityResultsFixture.json').read_text())
ACTIVITY_FIXTURE.pop('comment', None)
INBOX_EMPTY = {'items': [], 'hasMore': False, 'totalCount': 0, 'totalUnreadCount': 0}
OWNER_ID = 'visual-user'
MACHINES = {'mbp': 'computer-mbp', 'studio': 'computer-studio', 'long': 'computer-long-name',
            'daemon': 'computer-daemon-only', None: None}


def agent(aid, name, display, desc, machine, *, runtime='codex', model='gpt-5-codex', role='member',
          activity='working', detail=None, avatar='pixel:robot'):
    return {
        'id': aid, 'serverId': SID, 'name': name, 'displayName': display, 'avatarUrl': avatar,
        'description': desc, 'status': 'active', 'serverRole': role, 'model': model, 'runtime': runtime,
        'reasoningEffort': 'medium', 'executionMode': 'byoc',
        'envVars': {'RAFT_PROFILE': 'product-ux', 'SLOCK_VISUAL_PROVIDER': 'react'},
        'machineId': MACHINES[machine], 'sessionId': f'session-{aid}', 'runtimeProfile': None,
        'creatorType': 'user', 'creatorId': OWNER_ID,
        'creator': {'type': 'human', 'id': OWNER_ID, 'name': 'artin', 'displayName': 'artin',
                    'avatarUrl': None, 'gravatarHash': ''},
        'createdAgents': [], 'deletedAt': None, 'createdAt': CREATED,
        'activity': activity, 'activityDetail': detail,
    }


ROSTER = [
    agent('agent-product-ux', 'Product-UX-Designer', 'Product UX Designer',
          'Turns product feedback, screenshots, and release notes into actionable UX specs.', 'mbp',
          detail='Capturing deterministic Activity tab state'),
    agent('agent-cindy', 'Cindy', 'Cindy', 'Keeps visual testing release notes aligned.', 'mbp',
          detail='Capturing visual testing baselines'),
    agent('agent-android-dev-4', 'Android-Developer-4', 'Android Developer 4',
          'Implements shared Android/KMP UI fixes.', 'mbp', activity='online', detail='Reviewing shared state'),
    agent('agent-cc-wow', 'CC-Wow', 'CC-Wow', 'Visual testing analysis and fixes.', 'studio', runtime='claude',
          model='claude-sonnet-5', activity='offline'),
    agent('agent-kmp-expert', 'KMP-专家', 'KMP-专家', 'Shared KMP architecture and runtime adaptation.',
          'studio', activity='online'),
    agent('agent-builder', 'Builder', 'Builder', 'File and repo automation', 'daemon', role='admin',
          detail='Automating file workflows'),
    agent('agent-no-computer', 'No-Computer-Probe', 'No Computer Probe', None, None, activity='offline'),
]


def enrich_product_ux(row):
    """The row the official agent-detail host primes (runtimeProfile, createdAgents)."""
    row['runtimeProfile'] = {
        'migrationStatus': 'stable',
        'current': {
            'daemonVersion': '0.65.0', 'machineId': 'computer-mbp', 'machineName': 'Jiachengs-MacBook-Pro',
            'runtime': 'codex', 'model': 'gpt-5-codex', 'reasoningEffort': 'medium', 'executionMode': 'byoc',
            'workspaceRef': {'label': 'AndroidStudioProjects/Slock',
                             'path': '/Users/artin/AndroidStudioProjects/Slock', 'reachable': True},
            'observedAt': '2026-06-19T12:28:00.000Z'}}
    row['createdAgents'] = [{'id': 'agent-visual-qa', 'name': 'visual-qa', 'displayName': 'Visual QA',
                             'avatarUrl': None, 'runtime': 'codex', 'status': 'inactive'}]
    return row


enrich_product_ux(ROSTER[0])


def human(uid, name, display, desc, role='member', email=None):
    return {'userId': uid, 'serverId': SID, 'email': email or f'{name}@slock.ai', 'gravatarHash': '',
            'name': name, 'displayName': display, 'description': desc, 'avatarUrl': None, 'role': role,
            'joinedAt': CREATED, 'membershipStatus': 'active'}


HUMANS = [
    human('visual-user', 'artin', 'artin', 'Owner', 'owner', 'artin@slock.ai'),
    human('visual-human-designer', 'designer', 'Designer', 'Product design'),
    human('visual-human-jiacheng', 'jiacheng', 'Jiacheng', 'Android'),
    human('visual-human-guest', 'reviewer', 'Guest Reviewer', 'External reviewer', 'guest'),
    human('visual-human-admin', 'maya', 'Maya Admin', 'Runs the design ops rota', 'admin'),
]

def created(aid, name, display, runtime='codex', status='active'):
    return {'id': aid, 'name': name, 'displayName': display, 'avatarUrl': 'pixel:robot', 'runtime': runtime,
            'status': status}


def profile(h, created_agents=()):
    p = dict(h)
    p['createdAgents'] = list(created_agents)
    return p


PROFILES = {
    'self': profile(HUMANS[0], [created('agent-product-ux', 'Product-UX-Designer', 'Product UX Designer'),
                                created('agent-cindy', 'Cindy', 'Cindy'),
                                created('agent-cc-wow', 'CC-Wow', 'CC-Wow', 'claude', 'inactive')]),
    'member': profile(HUMANS[1]),
    'admin': profile(HUMANS[4], [created('agent-builder', 'Builder', 'Builder')]),
    'guest': profile(HUMANS[3]),
    'no-description': profile(dict(HUMANS[2], description=None)),
}

def mcp_server(sid, name, provider, desc, url, *, auth='oauth', status='connected', usage=None, tools=(),
               enabled=True, error=None, headers=()):
    return {
        'id': sid, 'name': name, 'description': desc, 'provider': provider, 'authMode': auth,
        'oauthStatus': status if auth == 'oauth' else 'disconnected', 'transport': 'streamable_http',
        'endpointUrl': url, 'enabled': enabled, 'configVersion': 3, 'catalogVersion': 2,
        'toolCatalog': [{'name': n, 'title': t, 'description': d, 'inputSchema': {'type': 'object'}}
                        for n, t, d in tools],
        'lastCheckedAt': '2026-06-19T10:00:00.000Z', 'lastCheckError': error,
        'credentialHeaderNames': list(headers), 'hasCredentials': bool(headers),
        'assignment': {'enabled': True, 'allowedTools': None, 'version': 1} if usage else None,
        'usage': usage, 'createdAt': CREATED, 'updatedAt': '2026-06-19T10:00:00.000Z'}


MCP_NOTION = mcp_server(
    'mcp-notion', 'Notion', 'notion', 'Search and edit the design wiki.', 'https://mcp.notion.com/mcp',
    usage={'invocationCount': 42, 'lastInvokedAt': '2026-06-19T11:30:00.000Z', 'lastToolName': 'notion-search'},
    tools=[('notion-search', 'Search', 'Search pages and databases in the workspace by keyword.'),
           ('notion-fetch', 'Fetch page', 'Fetch the full content of a page.'),
           ('notion-update', 'Update page', 'Update properties or content of a page.')])
MCP_LINEAR = mcp_server(
    'mcp-linear', 'Linear', 'linear', 'Issue tracker for the Android squad.', 'https://mcp.linear.app/mcp',
    status='error', enabled=False, error='Authorization expired. Reconnect Linear to refresh the tool list.',
    usage={'invocationCount': 3, 'lastInvokedAt': '2026-06-18T09:15:00.000Z', 'lastToolName': 'list_issues'},
    tools=[('list_issues', 'List issues', 'List issues matching a filter.')])
MCP_CUSTOM = mcp_server(
    'mcp-custom', 'Internal docs', 'custom', None, 'https://docs.internal.example/mcp', auth='headers',
    headers=['Authorization'], tools=[])

def chat_channel(cid, name, desc=None, ctype='channel', muted=False, seq=None, archived=False):
    return {'id': cid, 'name': name, 'description': desc, 'type': ctype, 'createdAt': CREATED,
            'archivedAt': '2026-06-19T00:00:00.000Z' if archived else None, 'activityMuted': muted,
            'muteFromSeq': seq}


CHAT_CHANNELS = [
    chat_channel('chat-ch-design', 'design', 'Product design reviews and UX specs for the next release.'),
    chat_channel('chat-ch-release', 'release-gates'),
    chat_channel('chat-ch-private', 'design-private', 'Private design notes.', ctype='private'),
    chat_channel('chat-ch-joint', 'partner-sync', 'Shared with the partner workspace.', ctype='joint', muted=True),
    chat_channel('chat-ch-archived', 'old-archive', archived=True),
]
CHAT_CHANNELS_MANY = CHAT_CHANNELS + [chat_channel(f'chat-ch-extra-{i}', f'extra-{i}') for i in range(1, 4)]


def chat_dm(did, peer_id, peer, display, preview, last='2026-06-17T12:00:00.000Z', avatar='pixel:robot'):
    return {'id': did, 'createdAt': CREATED, 'peerId': peer_id, 'peerName': peer, 'peerDisplayName': display,
            'peerAvatarUrl': avatar, 'lastMessageAt': last, 'lastMessagePreview': preview}


CHAT_DMS = [
    chat_dm('chat-dm-cindy', 'agent-cindy', 'Cindy', 'Cindy',
            'Handed over the release checklist. I did not change the Colvalley source and there is nothing '
            'left to hand over for this project, so this is only the status confirmation.'),
    chat_dm('chat-dm-builder', 'agent-builder', 'Builder', 'Builder', None, last=None),
]

FIXTURE = {
    'rosters': {'default': ROSTER, 'empty': []},
    'humans': HUMANS,
    'profiles': PROFILES,
    'routes': {
        'GET /agents': ROSTER,
        f'GET /servers/{SID}/members': HUMANS,
        **{f'GET /servers/{SID}/members/{p["userId"]}/profile': p for p in PROFILES.values()},
        **{f'GET /agents/{a["id"]}': a for a in ROSTER},
        'GET /channels/inbox': ACTIVITY_FIXTURE,
        'POST /feature-flags/evaluate': {'evaluations': [{'key': 'server_guest_v0', 'enabled': False}]},
        f'GET /servers/{SID}/join-links': [{'id': 'join-link-1', 'token': 'visual-join-token', 'maxUses': None,
                                           'expiresAt': None, 'useCount': 0}],
        'POST /channels/inbox/done': {},
        'POST /channels/threads/done': {},
        f'GET /mcp/agents/{AGENT_ID_FX}': {'servers': [MCP_NOTION, MCP_LINEAR, MCP_CUSTOM], 'recommendations': []},
        f'GET /agents/{AGENT_ID_FX}/channels': CHAT_CHANNELS,
        f'GET /agents/{AGENT_ID_FX}/agent-dms': CHAT_DMS,
    },
    'routeSets': {
        'invite-guest': {'POST /feature-flags/evaluate': {'evaluations': [{'key': 'server_guest_v0', 'enabled': True}]}},
        'list-empty': {'GET /agents': [], f'GET /servers/{SID}/members': []},
        'list-loading': {'GET /agents': {'$pending': True}, f'GET /servers/{SID}/members': {'$pending': True}},
        'mcp-empty': {f'GET /mcp/agents/{AGENT_ID_FX}': {'servers': [MCP_CUSTOM], 'recommendations': []}},
        'mcp-loading': {f'GET /mcp/agents/{AGENT_ID_FX}': {'$pending': True}},
        'activity-empty': {'GET /channels/inbox': INBOX_EMPTY},
        'activity-loading': {'GET /channels/inbox': {'$pending': True}},
        'activity-error': {'GET /channels/inbox': {'$status': 500}},
        'saved-empty': {'GET /channels/saved': {'saved': [], 'hasMore': False, 'total': 0}},
        'saved-loading': {'GET /channels/saved': {'$pending': True}},
        'saved-error': {'GET /channels/saved': {'$status': 500}},
        'chat-many': {f'GET /agents/{AGENT_ID_FX}/channels': CHAT_CHANNELS_MANY},
        'chat-empty': {f'GET /agents/{AGENT_ID_FX}/channels': [], f'GET /agents/{AGENT_ID_FX}/agent-dms': []},
        'chat-sections-empty': {f'GET /agents/{AGENT_ID_FX}/channels': [CHAT_CHANNELS[0]],
                                f'GET /agents/{AGENT_ID_FX}/agent-dms': []},
        'agent-log-empty': {f'GET /agents/{AGENT_ID_FX}/activity-log': []},
        'agent-log-loading': {f'GET /agents/{AGENT_ID_FX}/activity-log': {'$pending': True}},
        'agent-log-error': {f'GET /agents/{AGENT_ID_FX}/activity-log': {'$status': 500}},
        'list-error': {f'GET /servers/{SID}/members': {'$status': 500}},
    },
}

# ------------------------------------------------------------------ cases
CASES = []


def add(key, title, kind, *, platform='desktop', viewport=DESKTOP, selector, android_key, hint,
        props=None, interactions=None, android_interactions=None, route_set=None):
    base = {'extCase': key, 'extKind': kind, 'platform': platform, 'extFixture': 'members'}
    base.update(props or {})
    if 'openRow' in base:
        # Flutter reaches the same route the way a user does: the directory row.
        entity, ident = base.pop('openRow').split(':')
        android_interactions = [{'type': 'tap', 'key': f'desktop-directory-{entity}-{ident}'},
                                *(android_interactions or [])]
    if route_set:
        base['routeSet'] = route_set
    if kind == 'main':
        # The shell lazy-loads its panels and reads the API after the first render.
        interactions = [{'type': 'wait', 'ms': 1500}, *(interactions or [])]
    CASES.append({'key': key, 'title': title, 'viewport': viewport, 'selector': selector,
                  'android_key': android_key, 'hint': hint, 'props': base,
                  'interactions': interactions or [], 'android_interactions': android_interactions or []})


LIST_HINT = SRC + 'layout/Sidebar.tsx (members rail mode, SidebarItem rows)'
LIST_SEL = '[data-visual-case]'

add('list.default', 'Members list: agents by computer + humans', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT, props={'route': '/members'})
add('list.empty', 'Members list: nothing yet', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT,
    props={'route': '/members', 'roster': 'empty', 'humans': 'none'}, route_set='list-empty')
add('list.loading', 'Members list: loading', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT,
    props={'route': '/members', 'roster': 'empty', 'humans': 'none', 'loading': 'true'}, route_set='list-loading')
add('list.error', 'Members list: humans failed to load', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT,
    props={'route': '/members', 'humans': 'none', 'membersError': 'true'}, route_set='list-error')


add('list.selected-agent', 'Members list: agent selected (detail open)', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT, props={'route': '/agent/agent-product-ux', 'selected': 'agent:agent-product-ux'})
add('list.selected-human', 'Members list: human selected (detail open)', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT,
    props={'route': '/human/visual-human-designer', 'selected': 'human:visual-human-designer'})
add('list.row-hover', 'Members list: hovered agent row', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT, props={'route': '/members'},
    interactions=[{'type': 'hover', 'target': '[data-agent-id="agent-cindy"]'}],
    android_interactions=[{'type': 'hover', 'key': 'desktop-directory-agent-agent-cindy'}])
add('list.group-collapsed', 'Members list: computer group collapsed', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT, props={'route': '/members'},
    interactions=[{'type': 'click', 'target': '[data-testid="sidebar-agent-machine-group-toggle-computer-studio"]'}],
    android_interactions=[{'type': 'tap', 'key': 'directory-machine-disclosure-computer-studio'}])
add('list.humans-collapsed', 'Members list: Humans section collapsed', 'list', viewport=COLUMN, selector=LIST_SEL,
    android_key=None, hint=LIST_HINT, props={'route': '/members'},
    interactions=[{'type': 'click', 'target': '[data-testid="sidebar-section-toggle-humans"]'}],
    android_interactions=[{'type': 'tap', 'key': 'desktop-directory-toggle-human'}])


HUMAN_HINT = SRC + 'member/HumanDetailPanel.tsx (HumanRoute in MainLayout, desktop shell)'
HUMAN_SEL = '[data-testid="thread-main-column"]'
for key, title, who in [
    ('human.self', 'Human profile: own profile (owner)', 'self'),
    ('human.member', 'Human profile: member seen by the owner', 'member'),
    ('human.admin', 'Human profile: admin with a created agent', 'admin'),
    ('human.guest', 'Human profile: guest', 'guest'),
    ('human.no-description', 'Human profile: no description', 'no-description'),
]:
    add(key, title, 'main', selector=HUMAN_SEL, android_key='desktop-content-detail', hint=HUMAN_HINT,
        props={'route': f'/human/{PROFILES[who]["userId"]}', 'openRow': f'human:{PROFILES[who]["userId"]}'})


AGENT_HINT = SRC + 'agent/AgentDetailPanel.tsx (AgentRoute in MainLayout, desktop shell)'
AGENT_ID = 'agent-product-ux'
WEB_TABS = {'profile': 'profile', 'activity': 'activity', 'chat': 'chat', 'reminders': 'reminders',
            'workspace': 'workspace', 'apps': 'integrations', 'mcp': 'mcp'}


def agent_case(key, title, tab, *, viewport=DESKTOP, agent=AGENT_ID, extra_props=None, interactions=None, android_interactions=None,
               selector=HUMAN_SEL, android_key='desktop-content-detail', route_set=None):
    props = {'route': f'/agent/{agent}', 'openRow': f'agent:{agent}'}
    if tab != 'profile':
        props['routeQuery'] = f'agentTab={WEB_TABS[tab]}'
    props.update(extra_props or {})
    flutter = [{'type': 'tap', 'key': f'panel-tab-{tab}'}] if tab != 'profile' else []
    add(key, title, 'main', viewport=viewport, selector=selector, android_key=android_key, hint=AGENT_HINT, props=props,
        interactions=interactions, android_interactions=flutter + (android_interactions or []),
        route_set=route_set)


for tab in WEB_TABS:
    agent_case(f'agent.{tab}', f'Agent detail: {tab} tab (desktop)', tab)
agent_case('agent.chat-many', 'Agent detail: Chat tab, more than five channels (desktop)', 'chat', route_set='chat-many')
agent_case('agent.chat-empty', 'Agent detail: Chat tab, no chats (desktop)', 'chat', route_set='chat-empty')
agent_case('agent.chat-sections-empty', 'Agent detail: Chat tab, no agent DMs (desktop)', 'chat',
           route_set='chat-sections-empty')
agent_case('agent.mcp-empty', 'Agent detail: MCP tab without usage (desktop)', 'mcp', route_set='mcp-empty')
agent_case('agent.mcp-loading', 'Agent detail: MCP tab loading (desktop)', 'mcp', route_set='mcp-loading')


DLG = '[data-slot="dialog-content"]'
CARD_DLG = '.fixed.inset-0 [data-slot="dialog-card"]'
click = lambda sel: {'type': 'click', 'target': sel}
tap = lambda key: {'type': 'tap', 'key': key}

# Reset / restart agent dialog (ResetAgentDialog), opened from the inline header action.
RESET_HINT = SRC + 'agent/ResetAgentDialog.tsx (via the profile header restart/reset action)'
RESET_BTN = '[data-testid="agent-profile-inline-restart-reset"]'
for key, title, options in [
    ('agent.reset-restart', 'Reset agent dialog: restart (default)', []),
    ('agent.reset-session', 'Reset agent dialog: reset session', ['session']),
    ('agent.reset-full', 'Reset agent dialog: full reset (warning)', ['full']),
]:
    agent_case(key, title, 'profile', selector=DLG, android_key='agent-dialog',
               interactions=[click(RESET_BTN), *[click(f'[data-testid="agent-reset-option-{o}"]') for o in options]],
               android_interactions=[tap('agent-profile-inline-restart-reset'),
                                     *[tap(f'agent-reset-option-{o}') for o in options]])
    CASES[-1]['hint'] = RESET_HINT

# Profile edit dialogs (AgentProfileEditDialog), one per pencil.
EDIT_HINT = SRC + 'agent/AgentProfileEditDialog.tsx (via the profile pencils)'
for key, title, label, fkey in [
    ('agent.edit-name', 'Agent profile edit dialog: display name', 'Edit display name', 'agent-edit-display-name'),
    ('agent.edit-description', 'Agent profile edit dialog: description', 'Edit description', 'agent-edit-description'),
    ('agent.edit-role', 'Agent profile edit dialog: role', 'Edit role', 'agent-edit-role'),
]:
    agent_case(key, title, 'profile', selector=DLG, android_key='agent-dialog',
               interactions=[click(f'button[aria-label="{label}"]')], android_interactions=[tap(fkey)])
    CASES[-1]['hint'] = EDIT_HINT

# Invite human dialog (InviteHumanDialog), mounted like the official host does.
INVITE_HINT = SRC + 'member/InviteHumanDialog.tsx'
for key, title, guest in [('invite.default', 'Invite human dialog', 'false'),
                          ('invite.guest', 'Invite human dialog: per-row role (guest invites on)', 'true')]:
    add(key, title, 'invite', selector=CARD_DLG, android_key='invite-dialog', hint=INVITE_HINT,
        props={'guest': guest}, route_set='invite-guest' if guest == 'true' else None)

# Human profile dialogs / editing.
add('human.remove-confirm', 'Human profile: remove member confirmation', 'main', selector=DLG,
    android_key='agent-dialog', hint=HUMAN_HINT,
    props={'route': f'/human/{PROFILES["member"]["userId"]}', 'openRow': f'human:{PROFILES["member"]["userId"]}'},
    interactions=[click('button:has-text("Remove Member")')], android_interactions=[tap('member-remove')])
add('human.edit-role', 'Human profile: editing the role', 'main', selector=HUMAN_SEL,
    android_key='desktop-content-detail', hint=HUMAN_HINT,
    props={'route': f'/human/{PROFILES["member"]["userId"]}', 'openRow': f'human:{PROFILES["member"]["userId"]}'},
    interactions=[click('button[aria-label="Edit role"]')], android_interactions=[tap('member-edit-role')])

# Agent activity tab states (trajectory log).
agent_case('agent.activity-empty', 'Agent detail: Activity tab, no entries', 'activity', route_set='agent-log-empty')
agent_case('agent.activity-loading', 'Agent detail: Activity tab, loading', 'activity', route_set='agent-log-loading')
agent_case('agent.activity-error', 'Agent detail: Activity tab, failed to load', 'activity', route_set='agent-log-error')

# Activity / Saved panels, mounted like the official `components.home.*.results` cases
# (342x620 box) on the desktop viewport: the mobile page header is the owner's native design,
# not Web's PanelHeader, so these states are compared with the desktop header.
RES_SEL = '[data-visual-case]'
ACT_HINT = SRC + 'thread/ThreadsInbox.tsx'
SAVED_HINT = SRC + 'saved/SavedPanel.tsx'
for key, title, panel, state, rs in [
    ('activity.empty', 'Activity: empty inbox', 'activity', 'empty', 'activity-empty'),
    ('activity.loading', 'Activity: loading', 'activity', 'loading', 'activity-loading'),
    ('activity.error', 'Activity: failed to load', 'activity', 'error', 'activity-error'),
    ('saved.empty', 'Saved: empty', 'saved', 'empty', 'saved-empty'),
    ('saved.loading', 'Saved: loading', 'saved', 'loading', 'saved-loading'),
    ('saved.error', 'Saved: failed to load', 'saved', 'error', 'saved-error'),
]:
    add(key, title, 'resource', platform='desktop', viewport=DESKTOP, selector=RES_SEL, android_key=None,
        hint=ACT_HINT if panel == 'activity' else SAVED_HINT, props={'panel': panel, 'state': state}, route_set=rs)
# activity.mark-done is not covered: the Flutter Activity list has no per-row
# "Mark as Done" action (listed as missing in docs/parity.md).



def build_cases():
    out = []
    for c in CASES:
        for suffix, theme in THEMES.items():
            props = dict(c['props'])
            props['parityTheme'] = theme
            out.append({
                'id': f'{PREFIX}{c["key"]}.{suffix}',
                'title': f'{c["title"]} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'members-ext',
                'category': 'extension/members',
                'suite': 'raft-flutter-extension',
                'viewport': c['viewport'],
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': {'selector': c['selector'], 'crop': 'element', 'contract': 'component-bounds',
                            **({'androidKey': c['android_key']} if c['android_key'] else {}),
                            'interactions': c['interactions'],
                            'androidInteractions': c['android_interactions']},
                'reactPathHint': c['hint'],
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_members.dart '{c['key']}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
    return out


def write_keys():
    """Case keys for ext_members.dart (case_map registers one builder per key and theme)."""
    keys = ',\n'.join(f"  '{c['key']}': '{c['props']['extKind']}'" for c in CASES)
    out = (here.parent.parent / 'apps/raft_flutter/test/parity/cases/ext_members_keys.g.dart')
    out.write_text('// GENERATED by tool/parity-ext/build-member-cases.py; do not edit.\n'
                   '// Case key -> extKind of every components.members-ext.* case.\n'
                   f'const extMemberCaseKinds = {{\n{keys},\n}};\n')


def main():
    write_keys()
    (here / 'fixtures' / 'members.json').write_text(json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n')
    path = manifest_path()
    manifest = json.loads(path.read_text())
    cases = build_cases()
    manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
    print(f'{len(cases)} members-ext cases appended ({len(manifest["cases"])} total)')


if __name__ == '__main__':
    main()
