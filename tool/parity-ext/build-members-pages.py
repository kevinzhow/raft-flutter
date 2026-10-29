#!/usr/bin/env python3
"""Members / agents / humans PAGE cases that the page inventory (area 7, rows 4.06 / 4.07) lists as MISSING.

Run after build-member-cases.py and build-channel-settings.py (it reuses their fixture and cases); idempotent:
every `components.members-pages.*` case is replaced, all other cases are kept. Writes
tool/parity-ext/fixtures/members-pages.json (= the members-ext fixture + the extra agents / routes these pages need,
so both providers read the same data).

Ids: components.members-pages.<platform>.<key>.<theme>   (platform = desktop | phone)
React: tool/parity-ext/host/MembersPagesCases.tsx (real MainLayout / Sidebar / dialogs).
Flutter: apps/raft_flutter/test/parity/cases/ext_members_pages.dart (real WorkspaceView / dialogs).

Web components (packages/web/src/components): layout/Sidebar.tsx (members rail), member/HumanDetailPanel.tsx,
member/InviteHumanDialog.tsx, member/RolePermissionHelpDialog.tsx, agent/AgentDetailPanel.tsx,
agent/AgentProfileEditDialog.tsx, agent/AgentProfileOverflowMenu.tsx, agent/AgentMcpTab.tsx,
agent/AgentUnavailablePanel.tsx, agent/ReportIssueDialog.tsx, agent/ExternalAgentToken.tsx,
settings/MemberGraphSection.tsx, agent/ChannelMembers.tsx + channel/useChannelMemberRemoval.tsx.
"""
import copy
import importlib.util
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
PHONE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.members-pages.'
SRC = 'packages/web/src/components/'
SID = 'visual-server'
FIXTURE_NAME = 'members-pages'

# ------------------------------------------------------------------ fixture
spec = importlib.util.spec_from_file_location('build_member_cases', here / 'build-member-cases.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

FIXTURE = copy.deepcopy(base.FIXTURE)
AGENT_ID = base.AGENT_ID_FX
ROUTES = FIXTURE['routes']
ROUTE_SETS = FIXTURE['routeSets']

# An external agent (runtime "external"): the profile shows the external setup block with the token manager.
EXTERNAL = base.agent('agent-external', 'Hermes-Bridge', 'Hermes Bridge', 'Runs outside Raft and connects with a token.',
                      None, runtime='external', model='external', activity='offline')
EXTERNAL['external'] = True
FIXTURE['rosters']['external'] = FIXTURE['rosters']['default'] + [EXTERNAL]
ROUTE_SETS['roster-external'] = {'GET /agents': FIXTURE['rosters']['external']}
ROUTES[f'GET /agents/{EXTERNAL["id"]}'] = EXTERNAL
# A Codex agent saved in Fast mode: the server stores it ONLY in runtimeConfig.mode ({kind: "fast"}); there is no flat
# fastMode column, so the profile's Mode row must read the structured config (Web hydrateRuntimeConfigForm).
FAST = base.agent('agent-fast-mode', 'Fast-Codex', 'Fast Codex', 'Runs Codex in Fast mode.', 'mbp', activity='online')
FAST['reasoningEffort'] = 'high'
FAST['runtimeConfig'] = {'version': 1, 'runtime': 'codex', 'model': {'kind': 'preset', 'id': 'gpt-5-codex'},
                         'mode': {'kind': 'fast'}, 'reasoningEffort': 'high', 'envVars': FAST['envVars']}
FIXTURE['rosters']['fast'] = FIXTURE['rosters']['default'] + [FAST]
ROUTE_SETS['roster-fast'] = {'GET /agents': FIXTURE['rosters']['fast']}
ROUTES[f'GET /agents/{FAST["id"]}'] = FAST
ROUTES[f'GET /agents/{EXTERNAL["id"]}/credentials'] = {
    'agentId': EXTERNAL['id'],
    'credentials': [{'id': 'cred-1234abcd', 'maskedToken': 'sk_agent_ab12***9f3e', 'name': None,
                     'createdAt': '2026-06-18T09:00:00.000Z', 'lastUsedAt': None, 'revokedAt': None}]}
ROUTES[f'GET /agents/{EXTERNAL["id"]}/external-status'] = {
    'setupState': 'credential_minted', 'credentialLastUsedAt': None}

# Member graph (GET /servers/:id/member-graph): humans, agents, channels and who is in which channel.
GRAPH_HUMANS = [{'type': 'human', 'id': h['userId'], 'name': h['name'], 'displayName': h['displayName'],
                 'avatarUrl': None, 'gravatarHash': '', 'role': h['role'],
                 'channelIds': ['ch-design', 'ch-release'] if i < 3 else ['ch-design']}
                for i, h in enumerate(base.HUMANS)]
GRAPH_AGENTS = [{'type': 'agent', 'id': a['id'], 'name': a['name'], 'displayName': a['displayName'], 'avatarUrl': a['avatarUrl'],
                 'status': 'active', 'runtime': a['runtime'], 'channelIds': ['ch-design'] if i % 2 else ['ch-release']}
                for i, a in enumerate(base.ROSTER[:4])]
GRAPH_CHANNELS = [
    {'id': 'ch-design', 'name': 'design', 'type': 'channel', 'archivedAt': None, 'humanCount': 5, 'agentCount': 2, 'memberCount': 7},
    {'id': 'ch-release', 'name': 'release-gates', 'type': 'channel', 'archivedAt': None, 'humanCount': 3, 'agentCount': 2, 'memberCount': 5},
]
ROUTES[f'GET /servers/{SID}/member-graph'] = {
    'humans': GRAPH_HUMANS, 'agents': GRAPH_AGENTS, 'channels': GRAPH_CHANNELS,
    'edges': [{'channelId': cid, 'memberType': m['type'], 'memberId': m['id']}
              for m in GRAPH_HUMANS + GRAPH_AGENTS for cid in m['channelIds']]}

# Runtime config editor needs the runtime catalog / machine runtimes the profile already loads; nothing extra.

# Report issue dialog reads the agent's recent activity for the diagnostic bundle.
ROUTES[f'GET /agents/{AGENT_ID}/activity-log'] = [
    {'timestamp': 1781872080000, 'entry': {'kind': 'status', 'activity': 'working', 'detail': 'Capturing deterministic state'}}]

# Agent Activity / Workspace tab states (tool/parity-ext/agent_activity_data.py): every Activity row kind and
# variant, the empty / loading / error states and the workspace tree states.
import agent_activity_data as aad  # noqa: E402
ROUTE_SETS.update(aad.activity_routes(AGENT_ID))
ROUTE_SETS.update(aad.workspace_routes(AGENT_ID))

# Billing summary of the Free plan with every human seat used (Flutter reads it over the API; the React host
# seeds the same numbers into the server store).
BILLING_SEAT_LIMIT = {'plan': 'free', 'displayName': 'Free', 'serverPlan': 'free', 'source': 'server',
                      'capacity': {'maxHumans': 2, 'maxAgents': 2, 'maxUniversalSeats': -1},
                      'usage': {'humans': 2, 'agents': 2, 'universalSeats': 0}}
ROUTE_SETS['invite-seat-limit'] = {'GET /billing/subscription': BILLING_SEAT_LIMIT}

# The skills the profile lists (the official provider answers the same two for every agent).
SKILLS = {
    'global': [{'name': 'visual-testing', 'displayName': 'visual-testing',
                'description': 'Cross-platform fixture ownership', 'sourcePath': 'notes/product', 'userInvocable': False}],
    'workspace': [{'name': 'feature-map', 'displayName': 'feature-map', 'description': 'React/KMP parity maps',
                   'sourcePath': 'notes/product', 'userInvocable': False}],
}
for _a in FIXTURE['rosters']['external'] + [FAST]:
    ROUTES[f'GET /agents/{_a["id"]}/skills'] = SKILLS

# Phone/desktop "delete agent" and "stop agent" mutations answer an empty body.
ROUTES[f'POST /agents/{AGENT_ID}/stop'] = {}
ROUTES[f'DELETE /agents/{AGENT_ID}'] = {}

# ------------------------------------------------------------------ cases
CASES = []
click = lambda sel: {'type': 'click', 'target': sel}
tap = lambda key: {'type': 'tap', 'key': key}
# `scroll: False`: the target is already on screen, where Playwright does not scroll either.
tap_here = lambda key: {'type': 'tap', 'key': key, 'scroll': False, 'mouse': True}
tap_text = lambda text, scroll_in=None: {'type': 'tapText', 'text': text, **({'in': scroll_in} if scroll_in else {})}
wait = lambda ms: {'type': 'wait', 'ms': ms}

DLG = '[data-slot="dialog-content"]'
CARD_DLG = '.fixed.inset-0 [data-slot="dialog-card"]'
VIEW = '[data-visual-case]'
MAIN = '[data-testid="thread-main-column"]'
ROLE_HELP_BTN = 'role=button[name="Role permissions"]'
# The agent profile's help button carries no accessible name: the first button of the Role term.
AGENT_ROLE_HELP_BTN = 'dt:has-text("Role") >> button >> nth=0'


def add(platform, key, title, kind, *, selector, android_key, hint, props=None, interactions=None,
        android_interactions=None, route_set=None, flutter=True, note=None):
    """One case in 3 themes. `flutter=False`: the Flutter app has no such page (React case only)."""
    viewport = DESKTOP if platform == 'desktop' else PHONE
    base_props = {'extCase': f'{platform}.{key}', 'extKind': kind, 'platform': 'desktop' if platform == 'desktop' else 'mobile',
                  'extFixture': FIXTURE_NAME}
    base_props.update(props or {})
    android_interactions = list(android_interactions or [])
    if 'openRow' in base_props:
        # Flutter reaches the same route the way a user does: the directory row.
        entity, ident = base_props.pop('openRow').split(':')
        android_interactions = [tap(f'desktop-directory-{entity}-{ident}'), *android_interactions]
    if route_set:
        base_props['routeSet'] = route_set
    interactions = list(interactions or [])
    if kind == 'main':
        interactions = [wait(1500), *interactions]
    CASES.append({'platform': platform, 'key': key, 'title': title, 'kind': kind, 'viewport': viewport,
                  'selector': selector, 'android_key': android_key, 'hint': hint, 'props': base_props,
                  'interactions': interactions, 'android_interactions': android_interactions, 'flutter': flutter,
                  'note': note})


LIST_HINT = SRC + 'layout/Sidebar.tsx (members rail mode, mobileInline)'
HUMAN_HINT = SRC + 'member/HumanDetailPanel.tsx (HumanRoute in MainLayout)'
AGENT_HINT = SRC + 'agent/AgentDetailPanel.tsx (AgentRoute in MainLayout)'
WEB_TABS = {'profile': 'profile', 'activity': 'activity', 'chat': 'chat', 'reminders': 'reminders',
            'workspace': 'workspace', 'apps': 'integrations', 'mcp': 'mcp'}
MEMBER = base.PROFILES['member']['userId']
SELF = base.PROFILES['self']['userId']


def agent_main(platform, key, title, *, tab='profile', agent=AGENT_ID, selector=None, android_key='auto', hint=AGENT_HINT,
               interactions=None, android_interactions=None, route_set=None, props=None, flutter=True, open_row=True,
               note=None):
    desktop = platform == 'desktop'
    p = {'route': f'/agent/{agent}'}
    if open_row and desktop:
        p['openRow'] = f'agent:{agent}'
    if tab != 'profile':
        p['routeQuery'] = f'agentTab={WEB_TABS[tab]}'
    p.update(props or {})
    # Phone: the Flutter host opens the route page on the tab itself (initialTab).
    steps = [tap(f'panel-tab-{tab}')] if tab != 'profile' and desktop else []
    add(platform, key, title, 'main', selector=selector or (MAIN if desktop else VIEW),
        android_key=(('desktop-content-detail' if desktop else None) if android_key == 'auto' else android_key),
        hint=hint, props=p,
        interactions=interactions, android_interactions=steps + list(android_interactions or []),
        route_set=route_set, flutter=flutter, note=note)


def human_main(platform, key, title, who=MEMBER, *, selector=None, android_key='auto', interactions=None,
               android_interactions=None, flutter=True, note=None):
    desktop = platform == 'desktop'
    add(platform, key, title, 'main', selector=selector or (MAIN if desktop else VIEW),
        android_key=(('desktop-content-detail' if desktop else None) if android_key == 'auto' else android_key), hint=HUMAN_HINT,
        props={'route': f'/human/{who}', **({'openRow': f'human:{who}'} if desktop else {})}, interactions=interactions,
        android_interactions=android_interactions, flutter=flutter, note=note)


for platform in ('desktop', 'phone'):
    phone = platform == 'phone'
    # ---- 7.02 members list empty / loading / error (phone; the desktop column cases exist)
    if phone:
        add(platform, 'list.empty', 'Members page: nothing yet', 'main', selector=VIEW, android_key=None, hint=LIST_HINT,
            props={'route': '/members', 'roster': 'empty', 'humans': 'none'}, route_set='list-empty')
        add(platform, 'list.loading', 'Members page: loading', 'main', selector=VIEW, android_key=None, hint=LIST_HINT,
            props={'route': '/members', 'roster': 'empty', 'humans': 'none', 'loading': 'true'}, route_set='list-loading')
        add(platform, 'list.error', 'Members page: humans failed to load', 'main', selector=VIEW, android_key=None,
            hint=LIST_HINT, props={'route': '/members', 'humans': 'none', 'membersError': 'true'}, route_set='list-error')

    # ---- L2 whole-window pages (visual levels, docs/parity.md): the members list, a human profile and the agent
    # profile as the whole window (desktop: top bar + rail + sidebar + content; phone: the page + tab bar). The
    # desktop cases above crop the content column; these are the same routes captured whole.
    add(platform, 'window.members', 'Members page, whole window', 'main', selector=VIEW, android_key=None, hint=LIST_HINT,
        props={'route': '/members'})
    human_main(platform, 'window.human', 'Human profile, whole window', selector=VIEW, android_key=None)
    agent_main(platform, 'window.agent', 'Agent profile, whole window', selector=VIEW, android_key=None)

    # ---- 7.04 human profile actions (phone) / 7.05 role help
    if phone:
        human_main(platform, 'human.edit-role', 'Human profile: editing the role',
                   interactions=[click('button[aria-label="Edit role"]')], android_interactions=[tap('member-edit-role')])
        human_main(platform, 'human.remove-confirm', 'Human profile: remove member confirmation',
                   interactions=[click('button:has-text("Remove Member")')], android_interactions=[tap('member-remove')])
    human_main(platform, 'human.role-help', 'Human profile: role permissions help dialog',
               selector=CARD_DLG if not phone else VIEW, android_key='role-help-dialog' if not phone else None,
               interactions=[click(ROLE_HELP_BTN)], android_interactions=[tap_here('member-role-help')])
    agent_main(platform, 'agent.role-help', 'Agent profile: role permissions help dialog',
               selector=CARD_DLG if not phone else VIEW, android_key='role-help-dialog' if not phone else None,
               interactions=[click(AGENT_ROLE_HELP_BTN)], android_interactions=[tap_here('agent-role-help')])

    # ---- 7.14 MCP tab (phone)
    if phone:
        agent_main(platform, 'agent.mcp', 'Agent detail: MCP tab', tab='mcp')
        agent_main(platform, 'agent.mcp-empty', 'Agent detail: MCP tab without usage', tab='mcp', route_set='mcp-empty')
        agent_main(platform, 'agent.mcp-loading', 'Agent detail: MCP tab loading', tab='mcp', route_set='mcp-loading')

    # ---- 7.16 agent profile edit dialogs (phone)
    if phone:
        for key, title, label, fkey in [
            ('agent.edit-name', 'Agent profile edit dialog: display name', 'Edit display name', 'agent-edit-display-name'),
            ('agent.edit-description', 'Agent profile edit dialog: description', 'Edit description', 'agent-edit-description'),
            ('agent.edit-role', 'Agent profile edit dialog: role', 'Edit role', 'agent-edit-role'),
        ]:
            agent_main(platform, key, title, interactions=[click(f'button[aria-label="{label}"]')],
                       android_interactions=[tap_here(fkey)])

    # ---- agent Activity tab: empty / loading / error and every row kind (AgentActivityLog.tsx)
    ACT_HINT = SRC + 'agent/AgentActivityLog.tsx (+ RefText.tsx)'
    for key, title, rs in [
        ('activity-empty', 'Agent Activity tab: no entries', 'act-empty'),
        ('activity-loading', 'Agent Activity tab: loading (Web shows the empty state)', 'act-loading'),
        ('activity-error', 'Agent Activity tab: failed to load (Web shows the empty state)', 'act-error'),
        ('activity-status', 'Agent Activity tab: status rows (every status label and detail)', 'act-status'),
        ('activity-subagent', 'Agent Activity tab: Subagent badge on status and tool rows', 'act-subagent'),
        ('activity-tools', 'Agent Activity tab: humanised tool names and inputs', 'act-tools'),
        ('activity-text', 'Agent Activity tab: Thinking and Output rows (short, long, multi-line)', 'act-text'),
        ('activity-slock', 'Agent Activity tab: action / system / compaction rows with reference pills', 'act-slock'),
        ('activity-long-path', 'Agent Activity tab: long unbreakable paths and commands', 'act-long-path'),
    ]:
        agent_main(platform, f'agent.{key}', title, tab='activity', hint=ACT_HINT, route_set=rs)

    # ---- agent Workspace tab: loading / empty / error and the tree states (AgentWorkspace.tsx)
    WS_HINT = SRC + 'agent/AgentWorkspace.tsx'
    WS_FILE = 'button:has(> span:text-is("summary.md"))'
    for key, title, rs, steps_web, steps_flutter in [
        ('workspace-loading', 'Agent Workspace tab: file tree loading', 'ws-loading', [], []),
        ('workspace-empty', 'Agent Workspace tab: no files', 'ws-empty', [], []),
        ('workspace-error', 'Agent Workspace tab: file tree failed to load (Retry)', 'ws-error', [], []),
        ('workspace-rows', 'Agent Workspace tab: tree rows (memory.md, long names, folders)', 'ws-rows', [], []),
        ('workspace-truncated', 'Agent Workspace tab: truncated listing hint', 'ws-truncated', [], []),
        ('workspace-dir-loading', 'Agent Workspace tab: folder listing loading', 'ws-dir-loading',
         [click('button:has(> span:text-is("notes"))'), wait(300)], [tap_text('notes'), wait(300)]),
        ('workspace-dir-open', 'Agent Workspace tab: folder expanded', 'ws-rows',
         [click('button:has(> span:text-is("notes"))'), wait(300)], [tap_text('notes'), wait(300)]),
        ('workspace-file-loading', 'Agent Workspace tab: file preview loading', 'ws-file-loading',
         [click(WS_FILE), wait(300)], [tap_text('summary.md'), wait(300)]),
        ('workspace-file-error', 'Agent Workspace tab: file failed to load', 'ws-file-error',
         [click(WS_FILE), wait(300)], [tap_text('summary.md'), wait(300)]),
    ]:
        agent_main(platform, f'agent.{key}', title, tab='workspace', hint=WS_HINT, route_set=rs,
                   interactions=steps_web, android_interactions=steps_flutter)

    # ---- 7.17 runtime config editor
    agent_main(platform, 'agent.runtime-edit', 'Agent profile: runtime config editor open',
               interactions=[click('button[aria-label="Edit runtime config"]')],
               android_interactions=[tap_here('agent-edit-runtime')])

    # ---- 7.18 stop / delete confirmations and the overflow menu
    if phone:
        agent_main(platform, 'agent.overflow-menu', 'Agent profile: overflow menu (Stop, Restart / Reset)',
                   interactions=[click('[data-testid="agent-profile-overflow-trigger"]'), wait(200)],
                   android_interactions=[tap('agent-profile-overflow-trigger')])
        agent_main(platform, 'agent.stop-confirm', 'Agent profile: stop agent confirmation',
                   interactions=[click('[data-testid="agent-profile-overflow-trigger"]'),
                                 click('[data-testid="agent-profile-overflow-start-stop"]'), wait(200)],
                   android_interactions=[tap('agent-profile-overflow-trigger'), tap_text('Stop Agent')])
    else:
        agent_main(platform, 'agent.stop-confirm', 'Agent profile: stop agent confirmation', selector=DLG,
                   android_key='agent-dialog',
                   interactions=[click('[data-testid="agent-profile-inline-start-stop"]'), wait(200)],
                   android_interactions=[tap('agent-profile-inline-start-stop')])
    # v1.21.23: deleting an agent is archiving it (AgentArchiveDialog); the case id keeps its name.
    agent_main(platform, 'agent.delete-confirm', 'Agent profile: archive agent confirmation',
               selector=DLG if not phone else VIEW, android_key='agent-dialog' if not phone else None,
               interactions=[click('button:has-text("Archive Agent")'), wait(200)],
               android_interactions=[tap_text('Archive Agent', 'fleet-detail')])

    # ---- 7.20 agent unavailable (terminated / no access)
    agent_main(platform, 'agent.unavailable', 'Agent unavailable (terminated or no access)', agent='agent-gone',
               open_row=False, android_interactions=[], props={'unavailable': 'true'})

    # ---- 7.23 external agent setup
    agent_main(platform, 'agent.external', 'External agent profile: setup, token manager and Hermes steps',
               agent=EXTERNAL['id'], props={'roster': 'external'}, route_set='roster-external')

    # ---- profile runtime rows read the structured runtimeConfig (Fast mode)
    agent_main(platform, 'agent.profile-fast-mode', 'Agent profile: Runtime Config rows with Fast mode (runtimeConfig.mode)',
               agent=FAST['id'], props={'roster': 'fast'}, route_set='roster-fast')

    # ---- 7.25 member graph
    add(platform, 'graph', 'Member graph (/members/graph)', 'main', selector=MAIN if not phone else VIEW,
        android_key='desktop-content-detail' if not phone else None, hint=SRC + 'settings/MemberGraphSection.tsx',
        props={'route': '/members/graph'}, android_interactions=[tap('desktop-directory-graph')] if not phone else [])

# ---- 7.06 invite dialog states (both platforms; the dialog is mounted alone like the official host)
INVITE_HINT = SRC + 'member/InviteHumanDialog.tsx'
for platform in ('desktop', 'phone'):
    box = {'desktop': (1280, 800), 'phone': (390, 844)}[platform]
    sel = CARD_DLG if platform == 'desktop' else VIEW
    akey = 'invite-dialog' if platform == 'desktop' else None
    common = {'boxW': str(box[0]), 'boxH': str(box[1])}
    if platform == 'phone':
        add(platform, 'invite.default', 'Invite human dialog', 'invite', selector=sel, android_key=akey, hint=INVITE_HINT,
            props={**common, 'guest': 'false'})
        add(platform, 'invite.guest', 'Invite human dialog: per-row role (guest invites on)', 'invite', selector=sel,
            android_key=akey, hint=INVITE_HINT, props={**common, 'guest': 'true'}, route_set='invite-guest')
    add(platform, 'invite.link', 'Invite human dialog: By link tab', 'invite', selector=sel, android_key=akey,
        hint=INVITE_HINT, props={**common, 'guest': 'false'},
        interactions=[click('[data-testid="invite-tab-link"]'), wait(300)], android_interactions=[tap_text('By Link')])

    # Seat limit: the Free plan's 2 human seats are used; typing an email trips the email path.
    add(platform, 'invite.seat-limit', 'Invite human dialog: human seat limit reached (email typed)', 'invite',
        selector=sel, android_key=akey, hint=INVITE_HINT, props={**common, 'guest': 'false', 'seatLimit': 'true'},
        interactions=[{'type': 'fill', 'target': '[aria-label="Email address"]', 'value': 'new.teammate@company.com'},
                      wait(200)],
        android_interactions=[{'type': 'enterText', 'key': 'invite-email-0', 'text': 'new.teammate@company.com'}],
        route_set='invite-seat-limit')

# ---- 7.19 report issue dialog (mounted alone; gated on VITE_FEEDBACK_EXPORT_URL in the Web build)
for platform in ('desktop', 'phone'):
    add(platform, 'report-issue', 'Report issue dialog', 'report',
        selector=CARD_DLG if platform == 'desktop' else VIEW,
        android_key='report-issue-dialog' if platform == 'desktop' else None, hint=SRC + 'agent/ReportIssueDialog.tsx',
        props={'boxW': str({'desktop': 1280, 'phone': 390}[platform]),
               'boxH': str({'desktop': 800, 'phone': 844}[platform])})

# ---- 7.07 avatar management (desktop; the official phone case components.members.avatar-management exists)
agent_main('desktop', 'agent.avatar-change', 'Agent profile: change avatar dialog', selector=VIEW,
           android_key=None, interactions=[click('[data-testid="agent-change-avatar"]'), wait(200)],
           android_interactions=[tap_here('agent-profile-avatar-trigger')])
human_main('desktop', 'human.avatar-view', 'Human profile (self): avatar upload button', who=SELF)

# ---- 4.06 / 4.07 + channel members page actions: derived from the channel-settings drawer cases
# (build-channel-settings.py: `members-page`). Same host stores, same Flutter workspace; the data comes from
# fixtures/members-pages-channel.json = the channelsettings fixture + a role-actions variant.
CH_FIXTURE_NAME = 'members-pages-channel'
CH_FIXTURE = None
CHANNEL_DERIVED = []   # (platform, key, title, base state, extra React interactions, extra Flutter interactions, selector, key, route_set)
ROW = '[data-testid="member-page-section-humans-panel"] .group >> nth=1'
ROW_ID = 'member-page-row-human-visual-human-designer'
DESIGNER_REMOVE = f'{ROW} >> [aria-label^="Remove "]'
CONFIRM_SEL, CONFIRM_KEY = DLG, 'channel-member-remove-dialog'
for platform in ('desktop', 'mobile'):
    CHANNEL_DERIVED += [
        (platform, 'remove-confirm', 'Channel members page: remove member confirmation', 'members-page',
         [{'type': 'hover', 'target': ROW}, {'type': 'click', 'target': DESIGNER_REMOVE}, wait(400)],
         [{'type': 'hover', 'key': ROW_ID}, tap(f'{ROW_ID}-remove'), wait(400)], CONFIRM_SEL, CONFIRM_KEY, None),
        (platform, 'row-profile', 'Channel members page: a row opens the member profile', 'members-page',
         [{'type': 'click', 'target': f'{ROW} >> button.text-left'}, wait(600)],
         [tap(f'{ROW_ID}-open'), wait(600)], '[data-testid="channel-overflow-sheet"]', 'channel-overflow-sheet', None),
        (platform, 'role-action', 'Channel members page: hover role action (Make admin) and remove', 'members-page',
         [{'type': 'hover', 'target': ROW}, wait(200)], [{'type': 'hover', 'key': ROW_ID}, wait(200)],
         None, None, 'role-actions'),
    ]
# Phone add view: the drawer's dashed + tile lands straight in the add view (the page's own Add button is
# disabled while the roster has no one left to add).
CHANNEL_DERIVED.append(('mobile', 'add-view', 'Channel members page: add view', 'owner',
                        [click('[data-testid="channel-overflow-members-add-tile"]'), wait(400)],
                        [tap('channel-overflow-members-add-tile'), wait(400)],
                        '[data-testid="member-page"]', 'member-page', None))


def build_channel_cases(manifest):
    """Copies of the channel-settings members page cases with extra interactions (one per theme)."""
    global CH_FIXTURE
    src = here / 'fixtures' / 'channelsettings.json'
    if not src.is_file():
        return []
    CH_FIXTURE = copy.deepcopy(json.loads(src.read_text()))
    members_route = f'GET /channels/{[c for c in CH_FIXTURE["channels"]][0]["id"]}/members'
    owner_cid = CH_FIXTURE['channels'][0]['id']
    role_members = copy.deepcopy(CH_FIXTURE['routes'][f'GET /channels/{owner_cid}/members'])
    for row in role_members['humans'][1:] + role_members['agents'][:1]:
        row['canChangeChannelRole'] = True
    CH_FIXTURE['routeSets']['role-actions'] = {members_route: role_members}
    # Flutter evaluates the flag through the API (Web: the host seeds it).
    CH_FIXTURE['routes']['POST /feature-flags/evaluate'] = {
        'evaluations': [{'key': 'channel_manager_role_actions_v0', 'enabled': True}]}
    out = []
    by_id = {c['id']: c for c in manifest['cases']}
    for platform, key, title, base_state, extra, extra_android, selector, android_key, route_set in CHANNEL_DERIVED:
        for suffix, theme in THEMES.items():
            base_case = by_id.get(f'components.channelsettings.{platform}.{base_state}.{suffix}')
            if base_case is None:
                continue
            case = copy.deepcopy(base_case)
            props = case['variants'][0]['props']
            props.update({'extCase': f'channel.{platform}.{key}', 'extKind': 'channel', 'extFixture': CH_FIXTURE_NAME,
                          'platform': 'desktop' if platform == 'desktop' else 'mobile'})
            if route_set:
                props['routeSet'] = route_set
            cap = case['capture']
            cap['interactions'] = [*cap['interactions'], *extra]
            cap['androidInteractions'] = [*cap['androidInteractions'], *extra_android]
            if selector:
                cap['selector'] = selector
                cap['androidKey'] = android_key
            case.update({
                'id': f'{PREFIX}{platform if platform == "desktop" else "phone"}.channel-members.{key}.{suffix}',
                'title': f'{title} ({"desktop" if platform == "desktop" else "phone"}, {theme})',
                'surface': 'members-pages', 'category': 'extension/members-pages',
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_members_pages.dart "
                                   f"'channel.{platform}.{key}' (base: {base_case['id']})",
                'reactPathHint': SRC + 'agent/ChannelMembers.tsx + channel/ChannelMemberList.tsx + channel/useChannelMemberRemoval.tsx',
            })
            out.append(case)
    return out


# ---------------------------------------------------------------- build


def build_cases():
    out = []
    for c in CASES:
        for suffix, theme in THEMES.items():
            props = dict(c['props'])
            props['parityTheme'] = theme
            case = {
                'id': f'{PREFIX}{c["platform"]}.{c["key"]}.{suffix}',
                'title': f'{c["title"]} ({c["platform"]}, {theme})',
                'captureType': 'component-fixture',
                'surface': 'members-pages',
                'category': 'extension/members-pages',
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
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_members_pages.dart '{c['platform']}.{c['key']}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            }
            if c['note']:
                case['notes'] = c['note']
            out.append(case)
    return out


def write_keys(channel_keys):
    """Case key -> kind of the cases Flutter implements (case_map registers one builder per key and theme)."""
    rows = ',\n'.join(f"  '{c['platform']}.{c['key']}': '{c['kind']}'" for c in CASES if c['flutter'])
    ch = ',\n'.join(f"  '{k}'" for k in channel_keys)
    out = here.parent.parent / 'apps/raft_flutter/test/parity/cases/ext_members_pages_keys.g.dart'
    out.write_text('// GENERATED by tool/parity-ext/build-members-pages.py; do not edit.\n'
                   '// Case key -> extKind of every components.members-pages.* case Flutter implements.\n'
                   f'const extMembersPagesCaseKinds = {{\n{rows},\n}};\n'
                   '// `<platform>.channel-members.<key>` cases derived from the channel-settings drawer cases.\n'
                   f'const extMembersPagesChannelKeys = <String>[\n{ch},\n];\n')


def main():
    (here / 'fixtures' / f'{FIXTURE_NAME}.json').write_text(json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n')
    path = manifest_path()
    manifest = json.loads(path.read_text())
    cases = build_cases()
    channel_cases = build_channel_cases(manifest)
    write_keys(sorted({c['id'][len(PREFIX):].rsplit('.', 1)[0] for c in channel_cases}))
    cases += channel_cases
    if CH_FIXTURE is not None:
        (here / 'fixtures' / f'{CH_FIXTURE_NAME}.json').write_text(json.dumps(CH_FIXTURE, indent=1, ensure_ascii=False) + '\n')
    manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
    print(f'{len(cases)} members-pages cases appended ({len(manifest["cases"])} total)')


if __name__ == '__main__':
    main()
