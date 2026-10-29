#!/usr/bin/env python3
"""Generate the raft-flutter EXTENSION suite for the official visual-testing
framework: the run-time manifest ($PARITY_EXT_MANIFEST) (same schema as raft-source
packages/visual-testing/shared/sharedCases.json, so the official CLI runs it
unmodified via --manifest) and tool/parity-ext/fixtures/computers.json (data
both providers render).

Extension ids never collide with official ids: every case is
`components.computers.<surface>.<theme>`; variant props carry `parityTheme`
(the React render host receives it as a URL param, the Flutter harness reads
it from the props) and `extCase` (the theme-free key both hosts dispatch on).

Derivation: every surface and state of the Web Computers rail and
MachineDetailPanel at raft-source 26f77ef -
  Sidebar.tsx:3884-3935 computers mode + ComputerRow (:662-760);
  MachineDetailPanel.tsx sections (header, identity, Name, Description, Info,
  Agents on this computer + selection/bulk, Agent Workspaces, Actions:
  Computer card / Recovery guide / Delete, offline recovery card, legacy
  migrate block, disk-low banner) and their dialogs; AddMachineDialog.tsx
  (type + connect steps, ComputerCommandGuide.tsx).
"""
import copy
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
SID = 'visual-server'

# ---------------------------------------------------------------- fixture
CREATED = '2026-06-18T00:00:00.000Z'
creator = {'id': 'visual-user', 'name': 'artin', 'displayName': 'artin', 'avatarUrl': None, 'gravatarHash': None}


def machine(mid, name, **extra):
    m = {'id': mid, 'name': name, 'description': None, 'hostname': f'{mid}.local', 'os': 'linux',
         'status': 'online', 'statusVersion': 1, 'apiKeyPrefix': None, 'runtimes': ['codex'],
         'daemonVersion': '0.65.0', 'computerVersion': '0.0.50', 'isComputer': True,
         'lastHeartbeat': None, 'createdAt': CREATED}
    m.update(extra)
    return m


machines = {
    # The two official fixture machines (fixtureData.machines.primary/studio).
    'computer-mbp': machine('computer-mbp', 'Jiachengs-MacBook-Pro', hostname='Jiachengs-MacBook-Pro.local',
                            os='darwin', statusVersion=7, apiKeyPrefix='slk_vis', runtimes=['codex', 'claude'],
                            computerVersion='0.0.48', lastHeartbeat='2026-06-19T12:28:00.000Z'),
    'computer-studio': machine('computer-studio', 'Studio Test Rig', hostname='studio-test-rig.local',
                               status='offline', statusVersion=3, apiKeyPrefix='slk_off'),
    'computer-build': machine('computer-build', 'Build Server', description='Runs nightly Android builds',
                              runtimes=['claude', 'codex', 'opencode'], creator=creator),
    'computer-qa': machine('computer-qa', 'QA Laptop', os='darwin', computerVersion='0.0.48',
                           upgradeRequest={'id': 'upgrade-qa', 'targetVersion': '0.0.50',
                                           'requestedAt': '2026-06-19T12:00:00.000Z', 'state': 'pending',
                                           'observedVersion': None, 'reason': None, 'resolvedAt': None}),
    'computer-disk': machine('computer-disk', 'Render Box',
                             diskStatus={'availableBytes': 3 * 1024 ** 3, 'totalBytes': 500 * 1024 ** 3}),
    'computer-legacy': machine('computer-legacy', 'Old Daemon Host', isComputer=False, computerVersion=None,
                               daemonVersion='0.40.2'),
}
one_click = copy.deepcopy(machines['computer-mbp'])
one_click.update({'computerUpgradeAvailable': True, 'remoteUpgradeSupported': True,
                  'computerBroadcastPolicy': {'eligibility': 'eligible', 'targetVersion': '0.0.50', 'targetRole': None,
                                              'migrationClass': 'seamless', 'policyRevision': 'r1',
                                              'reasonCode': 'eligible'}})
lists = {
    'default': ['computer-mbp', 'computer-studio'],
    'states': ['computer-mbp', 'computer-studio', 'computer-build', 'computer-qa', 'computer-disk', 'computer-legacy'],
    'empty': [],
}
# The two official fixture agents (fixtureData.agents.cindy/productUx), placed
# on computer-mbp with the activity the official render host seeds.
OFFICIAL = json.loads((pathlib.Path(__import__('os').environ.get(
    'PARITY_RAFT_SOURCE', '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source'))
    / 'packages/visual-testing/shared/fixtureData.json').read_text())
agents = []
for key, activity, detail in [('cindy', 'working', 'Capturing visual testing baselines'), ('productUx', 'online', None)]:
    a = OFFICIAL['agents'][key]
    agents.append({'id': a['id'], 'name': a['name'], 'displayName': a['displayName'], 'avatarUrl': a['avatar'],
                   'description': a['description'], 'runtime': a['runtime'], 'model': a['model'],
                   'machineId': 'computer-mbp', 'status': 'active', 'activity': activity, 'activityDetail': detail})
workspaces = [
    {'directoryName': 'agent-cindy', 'totalSizeBytes': 48 * 1024 ** 2, 'lastModified': '2026-06-19T12:00:00.000Z',
     'fileCount': 312, 'status': 'active', 'agentName': 'Cindy', 'agentStatus': 'active'},
    {'directoryName': 'agent-product-ux', 'totalSizeBytes': 12 * 1024 ** 2 + 300 * 1024,
     'lastModified': '2026-06-18T08:00:00.000Z', 'fileCount': 54, 'status': 'stopped',
     'agentName': 'Product UX Designer', 'agentStatus': 'inactive'},
    {'directoryName': 'agent-retired', 'totalSizeBytes': 2 * 1024 ** 2, 'lastModified': '2026-06-10T08:00:00.000Z',
     'fileCount': 9, 'status': 'deleted', 'agentName': 'Retired Helper', 'agentStatus': None},
    {'directoryName': 'agent-0f3c9a', 'totalSizeBytes': 640 * 1024, 'lastModified': '2026-06-01T08:00:00.000Z',
     'fileCount': 3, 'status': 'orphan', 'agentName': None, 'agentStatus': None},
]
# Endpoints the mounted components call after first render. Both providers
# answer them from here (React: page.route in the generated provider spec;
# Flutter: the fixture client).
routes = {
    f'GET /servers/{SID}/machines/computer-mbp/workspaces': workspaces,
    f'POST /servers/{SID}/machines/computer-mbp/computer/restart': {},
    f'POST /servers/{SID}/machines': {'machine': machine('computer-new', 'my-computer', status='offline',
                                                         computerVersion=None, runtimes=[]),
                                      'apiKey': 'slk_fixture_not_a_real_key'},
}
# RuntimeAccountUsageChip hover card (Detected Runtimes): a Computer the
# viewer attached, with a fresh Claude snapshot and no Codex snapshot. Times
# are relative to the official fixture instant both providers render at.
NOW_MS = int(OFFICIAL['locale']['nowEpochMillis'])


def iso(offset_ms):
    import datetime
    t = datetime.datetime.fromtimestamp((NOW_MS + offset_ms) / 1000, datetime.timezone.utc)
    return t.strftime('%Y-%m-%dT%H:%M:%S.000Z')


machines['computer-usage'] = machine('computer-usage', 'Usage Rig', runtimes=['claude', 'codex'],
                                     runtimeVersions={'claude': '2.1.3'}, creator=creator,
                                     computerAttachedByCurrentUser=True)
lists['usage'] = ['computer-usage']
USAGE = f'/servers/{SID}/machines/computer-usage/runtime-account-usage'
routes[f'GET {USAGE}/claude'] = {
    'state': 'fresh',
    'snapshot': {
        'protocolVersion': 2, 'provider': 'claude', 'collectedAt': iso(-5 * 60_000),
        'staleAfter': iso(55 * 60_000), 'collectorVersion': '1',
        'accounts': [{
            'accountKey': 'a' * 64, 'planLabel': 'Claude Max', 'maskedLabel': 'art****@example.com',
            'health': 'ok',
            'windows': [
                {'id': 'five_hour', 'label': '5-hour', 'status': 'ok', 'usedRatio': 0.42,
                 'resetsAt': iso(3 * 3_600_000)},
                {'id': 'weekly', 'label': 'Weekly', 'status': 'limit_reached', 'usedRatio': 1,
                 'resetsAt': iso(2 * 86_400_000)},
            ],
        }],
    },
}
routes[f'GET {USAGE}/codex'] = {'state': 'missing', 'snapshot': None}
routes[f'POST {USAGE}/codex/refresh'] = {'accepted': False, 'state': 'computer_offline'}
fixture = {
    'name': 'raft-flutter parity extension: computers',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'latestComputerVersion': '0.0.50',
    'machines': {**machines, 'computer-mbp-one-click': one_click},
    'lists': lists,
    'agents': agents,
    'routes': routes,
}

# ------------------------------------------------------------------ cases
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
TALL = {'width': 1280, 'height': 2000, 'density': 1}
MDP = 'packages/web/src/components/machine/MachineDetailPanel.tsx'
SIDEBAR = 'packages/web/src/components/layout/Sidebar.tsx (computers mode, ComputerRow)'
ADD = 'packages/web/src/components/machine/AddMachineDialog.tsx'
DIALOG = '[data-slot="dialog-content"]'
CARD_DIALOG = '.fixed.inset-0 [data-slot="dialog-card"]'
cases = []


def btn(name):
    """Playwright role selector, exact accessible name."""
    return f'role=button[name="{name}"s]'


def add(key, title, *, kind, viewport, selector=None, android_key=None, props=None, interactions=(),
        android=(), hint=MDP, notes=None, family='computers', label='Computers',
        dart='ext_computers.dart'):
    for suffix, theme in THEMES.items():
        cid = f'components.{family}.{key}.{suffix}'
        sel = selector or f"[data-visual-case='{cid}']"
        p = {'extCase': key, 'extKind': kind, 'parityTheme': theme, 'platform': 'desktop', **(props or {})}
        c = {
            'id': cid,
            'title': f'{label} {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': family,
            'category': f'extension/{family}',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': p}],
            'capture': {'selector': sel, 'crop': 'element', 'contract': 'component-bounds',
                        'androidKey': android_key, 'interactions': list(interactions),
                        'androidInteractions': list(android)},
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/{dart} '{key}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if not android_key:
            del c['capture']['androidKey']
        if notes:
            c['notes'] = notes
        cases.append(c)


# Computers rail list: the real Sidebar column (240 x 800).
for key, lst, title, extra in [
    ('list.rows', 'default', 'list rows (online outdated + offline)', {}),
    ('list.states', 'states', 'list: every row state', {}),
    ('list.empty', 'empty', 'list: empty', {}),
    ('list.loading', 'default', 'list: loading', {'loading': True}),
]:
    add(key, title, kind='list', viewport=DESKTOP, hint=SIDEBAR, props={'list': lst, **extra})
add('list.row-selected', 'list: selected row', kind='list', viewport=DESKTOP, hint=SIDEBAR,
    props={'list': 'default', 'selected': 'computer-mbp'},
    selector='[data-testid="computer-list-item-computer-mbp"]',
    android_key='desktop-directory-computer-computer-mbp')
add('list.row-hover', 'list: hovered row', kind='list', viewport=DESKTOP, hint=SIDEBAR, props={'list': 'default'},
    selector='[data-testid="computer-list-item-computer-studio"]',
    android_key='desktop-directory-computer-computer-studio',
    interactions=[{'type': 'hover', 'target': '[data-testid="computer-list-item-computer-studio"]'}],
    android=[{'type': 'hover', 'key': 'desktop-directory-computer-computer-studio'}])

# Add Computer dialog.
add('add-dialog', 'Add Computer dialog: type step', kind='add', viewport=DESKTOP, hint=ADD,
    selector=CARD_DIALOG, android_key='computer-dialog')
add('add-dialog.connect', 'Add Computer dialog: connect step', kind='add', viewport=DESKTOP,
    hint=ADD + ' + ComputerCommandGuide.tsx', selector=CARD_DIALOG, android_key='computer-dialog',
    interactions=[{'type': 'click', 'target': btn('Next')},
                  {'type': 'wait', 'ms': 400}],
    android=[{'type': 'tap', 'key': 'add-computer-next'}])

# Computer detail (MachineDetailPanel in the 976-wide desktop detail column).
# Plain CSS (the provider also queries these through CDP for its font and
# text-run probes, so Playwright-only pseudo classes are not allowed).
SECTIONS = {
    'header': '[data-slot="panel-header"]',
    'identity': 'div.px-5.py-5',
    'name': ('div.px-5.py-4:has(> div > button[aria-label="Edit computer name"]), '
             'div.px-5.py-4:has(input[placeholder="Computer name"])'),
    'description': ('div.px-5.py-4:has(> div > button[aria-label="Edit computer description"]), '
                    'div.px-5.py-4:has(textarea)'),
    'info': 'div.px-5.py-4:has(> div.space-y-3)',
    'agents': 'div.space-y-6 > div:has(> div.flex-wrap.gap-y-2)',
    'workspaces': 'div.mt-2:has(svg.lucide-folder-open)',
    'service': '[data-testid="computer-service-actions"]',
    'recovery-guide': '[data-testid="computer-recovery-guide"]',
    'delete': 'div.mt-2 > [data-slot="card"]:last-child',
    'recovery-card': '[data-testid="computer-recovery-card"]',
}


def detail(key, title, machine_id, *, section=None, list_name='default', viewport=TALL, interactions=(),
           android=(), selector=None, android_key=None, notes=None, flags=None):
    props = {'machine': machine_id, 'list': list_name}
    if flags:
        props['flags'] = flags
    sel = selector or (SECTIONS[section] if section else None)
    akey = android_key or (f'computer-section-{section}' if section else 'computer-detail-panel')
    add(key, title, kind='detail', viewport=viewport, props=props, selector=sel, android_key=akey,
        interactions=interactions, android=android, notes=notes)


detail('detail.panel', 'detail: whole panel (online, outdated, 2 agents)', 'computer-mbp')
for name in ['header', 'identity', 'name', 'description', 'info', 'agents', 'workspaces', 'service',
             'recovery-guide', 'delete']:
    detail(f'detail.{name}', f'detail section: {name}', 'computer-mbp', section=name)
for key, mid, lst, note, flags in [
    ('offline', 'computer-studio', 'default', 'offline, no agents: recovery card + expanded guide', None),
    ('up-to-date', 'computer-build', 'states', 'online, current version, description, creator, 3 runtimes', None),
    ('upgrading', 'computer-qa', 'states', 'pending remote upgrade request', None),
    ('disk-low', 'computer-disk', 'states', 'online with < 10% disk free', None),
    ('legacy', 'computer-legacy', 'states', 'legacy daemon row (isComputer false)', None),
    ('one-click', 'computer-mbp-one-click', 'default', 'remote_computer_upgrade_v2 on + eligible policy',
     {'remote_computer_upgrade_v2': True}),
]:
    detail(f'detail.state.{key}', f'detail state: {key}', mid, list_name=lst, notes=note, flags=flags)
detail('detail.state.offline.recovery-card', 'detail state: offline recovery card', 'computer-studio',
       section='recovery-card')

SELECT = [{'type': 'click', 'target': btn('Select')}]
F_SELECT = [{'type': 'tap', 'key': 'computer-agents-select'}]
SELECT_ALL = SELECT + [{'type': 'click', 'target': btn('Select All')}]
F_SELECT_ALL = F_SELECT + [{'type': 'tap', 'key': 'computer-agents-select-all'}]
SCAN = [{'type': 'click', 'target': btn('Scan')}, {'type': 'wait', 'ms': 400}]
F_SCAN = [{'type': 'tap', 'key': 'computer-workspaces-scan'}]
detail('detail.edit-name', 'detail: editing name', 'computer-mbp', section='name',
       interactions=[{'type': 'click', 'target': btn('Edit computer name')}],
       android=[{'type': 'tap', 'key': 'computer-edit-name'}])
detail('detail.edit-description', 'detail: editing description', 'computer-mbp', section='description',
       interactions=[{'type': 'click', 'target': btn('Edit computer description')}],
       android=[{'type': 'tap', 'key': 'computer-edit-description'}])
detail('detail.select-mode', 'detail: agent selection mode', 'computer-mbp', section='agents',
       interactions=SELECT, android=F_SELECT)
detail('detail.select-all', 'detail: all agents selected (bulk bar)', 'computer-mbp', section='agents',
       interactions=SELECT_ALL, android=F_SELECT_ALL)
detail('detail.workspaces-scanned', 'detail: scanned workspaces', 'computer-mbp', section='workspaces',
       interactions=SCAN, android=F_SCAN)
detail('detail.recovery-guide-open', 'detail: recovery guide expanded', 'computer-mbp', section='recovery-guide',
       interactions=[{'type': 'click', 'target': btn('Show Recovery guide')}],
       android=[{'type': 'tap', 'key': 'computer-recovery-guide-toggle'}])
detail('detail.offline-setup-open', 'detail: offline install/setup commands expanded', 'computer-studio',
       section='recovery-card',
       interactions=[{'type': 'click', 'target': '[data-testid="computer-recovery-setup-toggle"]'}],
       android=[{'type': 'tap', 'key': 'computer-recovery-setup-toggle'}])
detail('detail.restart-progress', 'detail: restart in progress', 'computer-mbp', section='service',
       interactions=[{'type': 'click', 'target': btn('Restart')}, {'type': 'wait', 'ms': 300}],
       android=[{'type': 'tap', 'key': 'computer-restart'}])
# Dialogs (desktop viewport; crop the dialog card).
detail('dialog.bulk-restart', 'dialog: restart/reset selected agents', 'computer-mbp', viewport=DESKTOP,
       selector=CARD_DIALOG, android_key='computer-dialog',
       interactions=SELECT_ALL + [{'type': 'click', 'target': btn('Restart / Reset')}],
       android=F_SELECT_ALL + [{'type': 'tap', 'key': 'computer-bulk-restart-reset'}])
detail('dialog.stop-agents', 'dialog: stop selected agents', 'computer-mbp', viewport=DESKTOP,
       selector=DIALOG, android_key='computer-dialog',
       interactions=SELECT_ALL + [{'type': 'click', 'target': btn('Stop')}],
       android=F_SELECT_ALL + [{'type': 'tap', 'key': 'computer-bulk-stop'}])
detail('dialog.delete-workspace', 'dialog: delete workspace', 'computer-mbp', viewport=DESKTOP,
       selector=DIALOG, android_key='computer-dialog',
       interactions=SCAN + [{'type': 'click', 'target': f'{btn("Delete workspace")} >> nth=0'}],
       android=F_SCAN + [{'type': 'tap', 'key': 'computer-workspace-delete-agent-0f3c9a'}])
detail('dialog.delete-blocked', 'dialog: cannot delete computer with agents', 'computer-mbp', viewport=DESKTOP,
       selector=DIALOG, android_key='computer-dialog',
       interactions=[{'type': 'click', 'target': btn('Delete Computer')}],
       android=[{'type': 'tap', 'key': 'computer-delete'}])
detail('dialog.delete', 'dialog: delete computer', 'computer-studio', viewport=DESKTOP,
       selector=DIALOG, android_key='computer-dialog',
       interactions=[{'type': 'click', 'target': btn('Delete Computer')}],
       android=[{'type': 'tap', 'key': 'computer-delete'}])

# Runtime usage hover card (RuntimeAccountUsageChip). The Detected Runtimes
# row shows the health Status; hovering the Claude chip opens the usage card
# after its 200ms delay (portal Card role=dialog).
detail('detail.runtime-usage.info', 'detail: runtime usage health on Detected Runtimes', 'computer-usage',
       list_name='usage', section='info')
detail('detail.runtime-usage.card', 'detail: runtime usage hover card', 'computer-usage', list_name='usage',
       viewport=DESKTOP, selector='[role="dialog"][aria-label="Claude runtime account usage"]',
       android_key='runtime-usage-card',
       interactions=[{'type': 'hover', 'target': btn('Claude')}, {'type': 'wait', 'ms': 600}],
       android=[{'type': 'hover', 'key': 'runtime-usage-computer-usage-claude'},
                {'type': 'wait', 'ms': 300}])

# ============================================================ settings
# Settings > Workspace and Resources groups at raft-source 26f77ef:
#   Sidebar.tsx:2228-2280 settingsSidebarGroups (desktop Settings rail:
#   Personal / Workspace / Resources = About, Documentation, Feedback,
#   Release Notes), SettingsSidebarList.tsx;
#   SettingsPanel.tsx tabs (AboutSection, ServerTabContent, BillingTabContent,
#   AdministrationTabContent, IntegrationsSection, McpSettingsSection, LabsTabContent,
#   ProviderConnectionsSettings, IMBridgesSettingsSection);
#   LazyAboutFeedbackDialog.tsx + AboutFeedbackDialog.tsx (My Feedback workspace);
#   ReleaseNotesPanel.tsx (/release-notes, part of the Settings rail).
# Frame: the desktop shell minus the 64px LeftRail = 1216 wide: the 240px
# Sidebar settings rail + the 976px main column.
SETTINGS_HINT = 'packages/web/src/components/settings/SettingsPanel.tsx'
DAY = 86_400_000
FB_NOW = 1_791_000_000_000  # 2026-10-03T03:20:00Z, fixed (absolute dates only)
HASH = 'ab' * 32


def entry(eid, kind, text, ordinal, emphasis=False):
    return {'entryId': eid, 'type': kind, 'text': text, 'emphasis': emphasis, 'ordinal': ordinal}


releases = [
    {'releaseId': 'rel-1212', 'releaseKey': 'web-1.21.2', 'version': '1.21.2', 'tag': 'v1.21.2',
     'date': '2026-10-08', 'revision': 1, 'snapshotHash': HASH, 'publishedAt': '2026-10-08T10:00:00.000Z',
     'state': 'published', 'entries': [
         entry('e1', 'feature', 'Quick switcher: jump to any channel, DM or agent with Cmd/Ctrl+K', 0, True),
         entry('e2', 'feature', 'Settings now lists Release Notes under Resources', 1),
         entry('e3', 'improvement', 'Faster channel switching on large workspaces', 2),
         entry('e4', 'fix', 'Unread badges clear after reading a thread', 3),
         entry('e5', 'fix', 'Computer detail no longer flickers while a restart is in progress', 4)]},
    {'releaseId': 'rel-1211', 'releaseKey': 'web-1.21.1', 'version': '1.21.1', 'tag': 'v1.21.1',
     'date': '2026-10-02', 'revision': 2, 'snapshotHash': HASH, 'publishedAt': '2026-10-02T10:00:00.000Z',
     'state': 'retracted', 'entries': []},
    {'releaseId': 'rel-1210', 'releaseKey': 'web-1.21.0', 'version': '1.21.0', 'tag': 'v1.21.0',
     'date': '2026-09-30', 'revision': 1, 'snapshotHash': HASH, 'publishedAt': '2026-09-30T10:00:00.000Z',
     'state': 'published', 'entries': [
         entry('e6', 'breaking', 'Legacy daemon hosts must reinstall the Computer service', 0, True),
         entry('e7', 'deprecated', 'The old /machines route redirects to /computers', 1),
         entry('e8', 'improvement', 'Message translation keeps the original text one tap away', 2)]},
    {'releaseId': 'rel-0925', 'releaseKey': 'web-2026-09-25', 'version': None, 'tag': None,
     'date': '2026-09-25', 'revision': 1, 'snapshotHash': HASH, 'publishedAt': '2026-09-25T10:00:00.000Z',
     'state': 'published', 'entries': [entry('e9', 'improvement', 'Smaller attachment thumbnails on mobile', 0)]},
]


# Ticket ids are UUIDs, as the API returns them (the Flutter projection rejects
# anything else).
def ticket(tid, kind, status, message, created, updated, unread=0, attachments=0, comments=0, closure=None):
    return {'id': tid, 'kind': kind, 'status': status, 'closure_reason': closure, 'duplicate_of_ticket_id': None,
            'message': message, 'created_at': created, 'updated_at': updated, 'unread': unread > 0,
            'unread_count': unread, 'attachment_count': attachments, 'comment_count': comments}


tickets = [
    ticket('5b0e8c1a-7d3f-4c2e-9a61-0f2d3c4b5a61', 'feedback', 'in_progress', 'Let me keep the app open when I switch workspaces\nIt reloads every time.',
           FB_NOW - 3 * DAY, FB_NOW - 2 * 3_600_000, unread=2, attachments=1, comments=3),
    ticket('8c2f4e6a-1b3d-4f5e-8a7c-2d4e6f8a0b12', 'bug', 'open', 'Notification badge did not clear after opening Activity',
           FB_NOW - 5 * DAY, FB_NOW - 4 * DAY, comments=1),
    ticket('1a3c5e7f-9b2d-4c6e-8f1a-3b5d7f9a1c23', 'feedback', 'resolved', 'Export a channel as Markdown',
           FB_NOW - 9 * DAY, FB_NOW - 6 * DAY, comments=2),
    ticket('9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c34', 'bug', 'closed', 'Crash when pasting a very large image',
           FB_NOW - 12 * DAY, FB_NOW - 11 * DAY, comments=1, closure='duplicate'),
]


# Ticket detail reads (GET /product-feedback/tickets/:id, comment_limit=100):
# the in-progress ticket with a staff/reporter conversation, and the closed
# duplicate. Attachments stay empty: image previews would need blob reads.
def comment(cid, author, body, created):
    return {'id': cid, 'author_type': author, 'body': body, 'created_at': created}


def detail(t, comments, unread_total):
    return {'ticket': {**t, 'unread': False, 'unread_count': 0}, 'comments': comments, 'attachments': [],
            'next_comment_cursor': None, 'unread_total': unread_total}


FB_ACTIVE, FB_CLOSED = tickets[0], tickets[3]
FB_ACTIVE_DETAIL = detail(FB_ACTIVE, [
    comment('c-5b0e-1', 'staff', 'Thanks for the report! Which platform are you on?', FB_NOW - 2 * DAY),
    comment('c-5b0e-2', 'reporter', 'macOS desktop, switching between two workspaces.', FB_NOW - 2 * DAY + 3_600_000),
    comment('c-5b0e-3', 'staff', 'We reproduced it and a fix is in progress.', FB_NOW - 2 * 3_600_000),
], 0)
FB_CLOSED_DETAIL = detail(FB_CLOSED, [
    comment('c-9e8d-1', 'system', 'Closed as a duplicate of an existing ticket.', FB_NOW - 11 * DAY),
], 2)
mcp_linear = {
    'id': 'mcp-linear', 'name': 'Linear', 'description': 'Issues and projects', 'provider': 'linear',
    'authMode': 'oauth', 'oauthStatus': 'connected', 'transport': 'streamable_http',
    'endpointUrl': 'https://mcp.linear.app/mcp', 'enabled': True, 'configVersion': 1, 'catalogVersion': 1,
    'toolCatalog': [
        {'name': 'list_issues', 'title': 'List issues', 'description': 'List issues in a team',
         'inputSchema': {'type': 'object'}, 'annotations': {'readOnlyHint': True}},
        {'name': 'create_issue', 'title': 'Create issue', 'description': 'Create a new issue',
         'inputSchema': {'type': 'object'}},
    ],
    'lastCheckedAt': '2026-10-08T09:00:00.000Z', 'lastCheckError': None, 'credentialHeaderNames': [],
    'hasCredentials': True, 'assignment': None, 'usage': None,
    'createdAt': '2026-09-01T00:00:00.000Z', 'updatedAt': '2026-10-08T09:00:00.000Z',
}
mcp_notion = {'id': 'notion', 'name': 'Notion', 'description': 'Pages, databases and comments', 'provider': 'notion',
              'authMode': 'oauth', 'endpointUrl': 'https://mcp.notion.com/mcp', 'credentialHeaderNames': []}
T = OFFICIAL['times']
H = OFFICIAL['humans']
members = [{'userId': H[k]['memberId'] if k == 'owner' else H[k]['id'], 'serverId': SID, 'email': H[k]['email'], 'gravatarHash': '',
            'name': H[k]['name'], 'displayName': H[k]['displayName'], 'description': H[k].get('description'),
            'avatarUrl': None, 'role': H[k]['role'], 'joinedAt': T['memberJoinedAtIso'], 'membershipStatus': 'active'}
           for k in ('owner', 'designer', 'jiacheng')]
invites = [
    {'id': 'invite-visual-designer', 'invitedEmail': H['designer']['email'], 'invitedByUserId': H['owner']['id'],
     'status': 'pending', 'expiresAt': '2026-07-18T00:00:00.000Z', 'createdAt': T['entityCreatedAtIso']},
    {'id': 'invite-visual-qa', 'invitedEmail': 'qa@slock.ai', 'invitedByUserId': OFFICIAL['agents']['cindy']['id'],
     'status': 'pending', 'expiresAt': '2026-07-19T12:24:00.000Z', 'createdAt': T['recentActivityAtIso']},
]
join_links = [{'id': 'join-link-visual', 'token': 'design', 'createdAt': T['entityCreatedAtIso'],
               'expiresAt': T['recentActivityAtIso'], 'maxUses': 25, 'useCount': 8, 'revokedAt': None}]
billing_free = {
    'plan': 'free', 'displayName': 'Free', 'serverPlan': 'free', 'source': 'server',
    'capacity': {'maxHumans': 1, 'maxAgents': 2, 'maxUniversalSeats': -1},
    'usage': {'humans': 2, 'agents': 2, 'universalSeats': 0},
    'provisioned': {'humans': 1, 'agents': 2, 'proPackQuantity': 0, 'trialFreePackQuantity': 0,
                    'firstPackTrialEndsAt': None},
    'fileUploadQuota': {'month': '2026-06', 'plan': 'free', 'limited': True, 'enforced': False,
                        'limitBytes': 524_288_000, 'usedBytes': 188_743_680, 'reservedBytes': 0,
                        'remainingBytes': 335_544_320},
    'price': None, 'subscription': None, 'stripeConfigured': True,
    'permissions': {'canReadBillingSummary': True, 'canManageBilling': True},
}


def oauth_app(**fields):
    base = {'serverId': SID, 'publishRejectionReason': None, 'returnUrl': None, 'agentManifestUrl': None,
            'allowedScopes': [], 'logoUrl': None, 'createdByUserId': H['owner']['id'],
            'createdAt': T['entityCreatedAtIso'], 'updatedAt': T['entityCreatedAtIso']}
    base.update(fields)
    return base


marketplace = [
    oauth_app(id='market_slack', clientId='client_slack_bridge', appType='third_party_global',
              publishStatus='published', category='Productivity & Collaboration',
              dataAccessSummary='Messages and channel metadata', name='Slack Bridge',
              description='Mirror Slock activity into Slack channels.', homepageUrl='https://example.com/slack',
              returnUrl='https://example.com/slack/oauth/callback', allowedScopes=['openid', 'profile', 'identity'],
              humanMarketplaceVisible=True, installedAt=None, publisherName='Raft Labs', privateShared=False,
              official=True, marketplaceInstallBadge={'kind': 'bucket', 'bucket': '100_plus'}),
    oauth_app(id='market_github', clientId='client_github_issues', appType='third_party_global',
              publishStatus='published', category='Development', dataAccessSummary='Tasks and feedback',
              name='GitHub Issues', description='Create issues from tasks and feedback.',
              homepageUrl='https://example.com/github', returnUrl='https://example.com/github/callback',
              allowedScopes=['openid', 'profile', 'agent:read'], humanMarketplaceVisible=True,
              installedAt=T['entityCreatedAtIso'], publisherName='Raft Labs', privateShared=False,
              official=False, marketplaceInstallBadge={'kind': 'none'}),
    # Billing / Applications port: a third listing with the NEW badge, a
    # publisher server name and a long description (two-line clamp in list view).
    oauth_app(id='market_linear', clientId='client_linear_sync', appType='third_party_global',
              publishStatus='published', category='Developer Tools', dataAccessSummary='Tasks',
              name='Linear Sync',
              description=('Keep Linear issues and Raft tasks in step: status, assignee and comments flow both '
                           'ways, and agents can open issues from any thread when work needs tracking.'),
              homepageUrl=None, humanMarketplaceVisible=True, installedAt=None, publisherName='Linear',
              publisherServerName='Linear Workspace', privateShared=False, official=False,
              marketplaceInstallBadge={'kind': 'new'}),
]
clients = [oauth_app(id='client_1', clientId='client_slack_bridge', appType='server_local', publishStatus='private',
                     category='Productivity & Collaboration', dataAccessSummary='Messages and channel metadata',
                     name='Slack Bridge', description='Server-local OAuth client.', homepageUrl='https://example.com',
                     returnUrl='https://example.com/oauth/callback',
                     agentManifestUrl='https://example.com/manifest.json', humanMarketplaceVisible=False)]
# GET /servers/:id/labs (canonical readback): one open lab enrolled, one paused.
labs = {'serverId': SID, 'accessEnabled': True, 'version': 3, 'canManageAccess': True, 'canManageEnrollments': True,
        'labs': [
            {'labKey': 'workspace_grid_v0', 'name': 'Workspace grid',
             'description': 'Arrange channels, threads and agents side by side in draggable editor groups.',
             'state': 'open', 'enrolled': True, 'effective': True, 'updatedAt': '2026-10-01T00:00:00.000Z'},
            {'labKey': 'composer_resource_references_v0', 'name': 'Resource references',
             'description': 'Reference tasks, files and computers from the composer with #.',
             'state': 'paused', 'enrolled': False, 'effective': False, 'updatedAt': None},
        ]}
settings_fixture = {
    'name': 'raft-flutter parity extension: settings (Workspace + Resources groups)',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    # Keep the frozen legacy version; current Web About uses the pinned
    # v1.21.23 artifact version (confirmed by the actual rendered page).
    'appVersion': '1.17.5',
    'webAppVersion': '1.21.23',
    'routes': {
        # Controlled availability matching the Web's initial defaults, not a
        # claim about the live release. The API always supplies all three OSes.
        'GET /desktop-download/platforms': {
            'mac': {'status': 'unknown'}, 'linux': {'status': 'unknown'}, 'windows': {'status': 'none'},
        },
        'GET /release-notes': {'items': releases, 'nextCursor': None},
        'GET /product-feedback/tickets': {'tickets': tickets, 'next_cursor': None, 'unread_total': 2},
        f"GET /product-feedback/tickets/{FB_ACTIVE['id']}": FB_ACTIVE_DETAIL,
        f"GET /product-feedback/tickets/{FB_CLOSED['id']}": FB_CLOSED_DETAIL,
        'GET /mcp/servers': {'servers': [mcp_linear], 'recommendations': [mcp_notion]},
        # Workspace tabs: the official react-provider.spec.ts payloads for
        # these endpoints (served to every case id there), restated so both
        # providers render the same data.
        f'GET /servers/{SID}/usage': {'agents': 2, 'machines': 1, 'channels': 4},
        'GET /billing/subscription': billing_free,
        # This fixture has local agents and no hosted runtime. The mounted
        # billing route returns 404 in that state (billing.ts at v1.21.23),
        # rather than a 200 empty object that crashes HostedRuntimeSpendCard.
        'GET /billing/hosted-runtime-usage': {'$status': 404, '$body': {
            'error': 'This server has no cloud agents', 'code': 'hosted_runtime_spend_not_enabled'}},
        f'GET /servers/{SID}/members': members,
        f'GET /servers/{SID}/invites': invites,
        f'GET /servers/{SID}/join-links': join_links,
        f'GET /servers/{SID}/agreement': {'enabled': True, 'agreement': {
            'title': 'Raft Design workspace agreement',
            'bodyMarkdown': 'Please keep feedback actionable and avoid sharing credentials in public channels.'}},
        f'GET /servers/{SID}/translation-settings': {
            'translationEnabled': True, 'translationAvailable': True, 'canManageTranslation': True},
        'GET /integrations/marketplace': marketplace,
        'GET /integrations/clients': clients,
        'GET /integrations/overview': [],
        f'GET /servers/{SID}/labs': labs,
        # Administration: OnboardingAgentSection (serverStore.loadSettings +
        # setup projection) and the product-analytics switch.
        f'GET /servers/{SID}/settings': {'settings': {
            'onboardSettings': {'onboardingAgentId': OFFICIAL['agents']['productUx']['id'],
                                'agentAllChannelGreetingEnabled': True},
            'feedbackSettings': {'enabled': False}}},
        f'GET /servers/{SID}/setup-projection': {'surface': 'none', 'phase': 'complete'},
        f'GET /servers/{SID}/product-analytics-settings': {'productAnalyticsEnabled': True,
                                                          'canManageProductAnalytics': True},
    },
    # Anything else answers the official spec's catch-all body (200) on both
    # providers.
    'fallback': {'agents': [], 'humans': [], 'results': []},
    # props.routeSet -> overrides; {"$status": N} answers N, {"$pending": true}
    # never answers (loading state).
    'routeSets': {
        'release-notes-loading': {'GET /release-notes': {'$pending': True}},
        'release-notes-error': {'GET /release-notes': {'$status': 500}},
        'release-notes-empty': {'GET /release-notes': {'items': [], 'nextCursor': None}},
        'feedback-empty': {'GET /product-feedback/tickets': {'tickets': [], 'next_cursor': None, 'unread_total': 0}},
        'feedback-loading': {'GET /product-feedback/tickets': {'$pending': True}},
        'feedback-error': {'GET /product-feedback/tickets': {'$status': 500}},
        'admin-empty': {f'GET /servers/{SID}/invites': [], f'GET /servers/{SID}/join-links': []},
        'admin-agreement-off': {f'GET /servers/{SID}/agreement': {'enabled': False, 'agreement': None}},
        'admin-setup-open': {f'GET /servers/{SID}/setup-projection': {'surface': 'create_agent',
                                                                      'phase': 'in_progress'}},
        'admin-no-provider': {f'GET /servers/{SID}/translation-settings': {
            'translationEnabled': True, 'translationAvailable': False, 'canManageTranslation': True}},
        # Store-primed states (host + Flutter builder read the routeSet name).
        'admin-all-visible': {},
        'admin-hide-humans': {},
        # Writes never reach a server: a submit/reply/close either stays in
        # flight (busy state) or fails (error banner).
        'feedback-create-pending': {'POST /product-feedback': {'$pending': True}},
        'feedback-create-error': {'POST /product-feedback': {'$status': 503}},
        'feedback-reply-error': {f"POST /product-feedback/tickets/{FB_ACTIVE['id']}/comments": {'$status': 503}},
        'feedback-close-error': {f"POST /product-feedback/tickets/{FB_ACTIVE['id']}/close": {'$status': 503}},
    },
}

FRAME = {'width': 1280, 'height': 800, 'density': 1}
FRAME_TALL = {'width': 1280, 'height': 1600, 'density': 1}
NAV = "[data-parity-region='settings-navigation']"
PANEL = "[data-parity-region='settings-panel']"


def settings_case(key, title, *, tab, region=None, selector=None, android_key=None, viewport=FRAME, role='owner',
                  flags='', route_set='', interactions=(), android=(), hint=SETTINGS_HINT, notes=None,
                  platform='desktop'):
    props = {'tab': tab, 'role': role}
    # Feedback routes must not be shadowed by another family's empty inbox.
    if tab == 'feedback':
        props['extFixture'] = 'settings'
    if platform != 'desktop':
        props['platform'] = platform
    if flags:
        props['flags'] = flags
    if route_set:
        props['routeSet'] = route_set
    if region == 'nav':
        selector, android_key = NAV, 'settings-navigation'
    elif region == 'panel':
        selector, android_key = PANEL, 'settings-panel'
    # The Feedback workspace is a lazy chunk and every tab loads data after
    # mount; let the React page settle before the capture.
    add(key, title, kind='settings', viewport=viewport, props=props, selector=selector, android_key=android_key,
        interactions=[{'type': 'wait', 'ms': 800}, *interactions], android=android, hint=hint, notes=notes, family='ext-settings',
        label='Settings', dart='ext_settings.dart')


SIDEBAR_HINT = 'packages/web/src/components/layout/Sidebar.tsx (settingsSidebarGroups) + settings/SettingsSidebarList.tsx'
ALL_FLAGS = 'labs,providers,bridge'
# Navigation: the Settings rail column (240 x 800).
settings_case('nav.owner', 'rail: owner, About active', tab='about', region='nav', hint=SIDEBAR_HINT)
settings_case('nav.owner-all', 'rail: owner, every workspace flag on', tab='about', region='nav', flags=ALL_FLAGS,
              hint=SIDEBAR_HINT, notes='server_labs_ui_v0, provider_connections_v0 and slack_bridge_v0 on')
settings_case('nav.member', 'rail: member (no billing/administration)', tab='about', region='nav', role='member',
              hint=SIDEBAR_HINT)
settings_case('nav.guest', 'rail: guest (no applications/MCP)', tab='about', region='nav', role='guest',
              hint=SIDEBAR_HINT)
settings_case('nav.release-notes-active', 'rail: Release Notes active', tab='release-notes', region='nav',
              hint=SIDEBAR_HINT)
settings_case('nav.row-hover', 'rail: hovered Documentation row', tab='about', hint=SIDEBAR_HINT,
              selector="[data-parity-region='settings-navigation'] a[aria-label='Documentation']",
              android_key='workspace-settings-nav-documentation',
              interactions=[{'type': 'hover',
                             'target': "[data-parity-region='settings-navigation'] a[aria-label='Documentation']"}],
              android=[{'type': 'hover', 'key': 'workspace-settings-nav-documentation'}])

# Resources group pages.
ABOUT_HINT = SETTINGS_HINT + '#AboutSection + MobileDownloadQr.tsx'
settings_case('about.page', 'About: whole page', tab='about', hint=ABOUT_HINT, selector=None)
settings_case('about.panel', 'About: panel', tab='about', region='panel', hint=ABOUT_HINT)
for name, section in {
    'version': 'div.space-y-6 > section:first-of-type',
    'mobile-app': 'div.space-y-6 > section:has([data-testid="mobile-download-android"])',
    'workspace': '[data-testid="settings-about-workspace"]',
}.items():
    settings_case(f'about.{name}', f'About section: {name}', tab='about', hint=ABOUT_HINT,
                  selector=f"[data-parity-region='settings-panel'] {section}",
                  android_key=f'settings-about-{name}')
RN_HINT = 'packages/web/src/components/settings/ReleaseNotesPanel.tsx'
settings_case('release-notes.page', 'Release Notes: whole page', tab='release-notes', hint=RN_HINT)
settings_case('release-notes.panel', 'Release Notes: panel (all releases)', tab='release-notes', region='panel',
              viewport=FRAME_TALL, hint=RN_HINT)
settings_case('release-notes.current', 'Release Notes: current release card', tab='release-notes', hint=RN_HINT,
              selector="[data-parity-region='settings-panel'] div.space-y-4 > [data-testid='release-entry']:nth-child(1)", android_key='release-entry-rel-1212')
settings_case('release-notes.retracted', 'Release Notes: retracted release card', tab='release-notes', hint=RN_HINT,
              selector="[data-parity-region='settings-panel'] div.space-y-4 > [data-testid='release-entry']:nth-child(2)", android_key='release-entry-rel-1211')
settings_case('release-notes.older', 'Release Notes: breaking/deprecated release card', tab='release-notes',
              hint=RN_HINT, selector="[data-parity-region='settings-panel'] div.space-y-4 > [data-testid='release-entry']:nth-child(3)", android_key='release-entry-rel-1210')
for state in ['loading', 'error', 'empty']:
    settings_case(f'release-notes.{state}', f'Release Notes: {state}', tab='release-notes', region='panel',
                  route_set=f'release-notes-{state}', hint=RN_HINT)
FB_HINT = ('packages/web/src/components/settings/LazyAboutFeedbackDialog.tsx + AboutFeedbackDialog.tsx '
           '(@botiverse/hands-feedback-react FeedbackWorkspace)')
settings_case('feedback.page', 'Feedback: whole page (inbox)', tab='feedback', hint=FB_HINT)
settings_case('feedback.panel', 'Feedback: panel (inbox)', tab='feedback', region='panel', hint=FB_HINT)
for state in ['empty', 'loading', 'error']:
    settings_case(f'feedback.{state}', f'Feedback: {state}', tab='feedback', region='panel',
                  route_set=f'feedback-{state}', hint=FB_HINT)

# Feedback write surfaces (New feedback form, ticket detail with the reply
# composer, Close ticket split button / reason menu / confirm dialog).
FB_ROW = "[data-parity-region='settings-panel'] li:has(button[data-ticket-id='{}']) .hands-feedback-ticket-title"
FB_NEW = [{'type': 'click', 'target': btn('New feedback')}, {'type': 'wait', 'ms': 300}]
F_FB_NEW = [{'type': 'tap', 'key': 'feedback-new'}]
FB_MESSAGE = '#hands-feedback-message'
FB_TEXT = 'Let me pin channels to the top of the sidebar.'
FB_OPEN = [{'type': 'click', 'target': FB_ROW.format(FB_ACTIVE['id'])}, {'type': 'wait', 'ms': 500}]
F_FB_OPEN = [{'type': 'tap', 'key': f"feedback-ticket-{FB_ACTIVE['id']}"}]
FB_REPLY = f"#hands-feedback-reply-{FB_ACTIVE['id']}"
FB_REPLY_TEXT = 'Thanks, happy to test a build.'
FB_DETAIL = "[data-parity-region='settings-panel'] .hands-feedback-detail"
FB_CLOSE_MAIN = f'{FB_DETAIL} .hands-feedback-close-main'
ALERT = '[data-slot="alert-dialog-content"]'
settings_case('feedback.new', 'Feedback: New feedback form', tab='feedback', region='panel', hint=FB_HINT,
              interactions=FB_NEW, android=F_FB_NEW)
settings_case('feedback.new-filled', 'Feedback: New feedback form, Bug + message typed', tab='feedback',
              region='panel', hint=FB_HINT,
              interactions=FB_NEW + [{'type': 'click', 'target': '.hands-feedback-kind-item >> nth=1'},
                                     {'type': 'fill', 'target': FB_MESSAGE, 'value': FB_TEXT}],
              android=F_FB_NEW + [{'type': 'tap', 'key': 'feedback-kind-bug'},
                                  {'type': 'enter', 'key': 'feedback-new-message', 'value': FB_TEXT}])
settings_case('feedback.new-submitting', 'Feedback: New feedback submitting', tab='feedback', region='panel',
              hint=FB_HINT, route_set='feedback-create-pending',
              interactions=FB_NEW + [{'type': 'fill', 'target': FB_MESSAGE, 'value': FB_TEXT},
                                     {'type': 'click', 'target': btn('Submit')}, {'type': 'wait', 'ms': 300}],
              android=F_FB_NEW + [{'type': 'enter', 'key': 'feedback-new-message', 'value': FB_TEXT},
                                  {'type': 'tap', 'key': 'feedback-new-submit'}])
settings_case('feedback.new-error', 'Feedback: New feedback submit failed', tab='feedback', region='panel',
              hint=FB_HINT, route_set='feedback-create-error',
              interactions=FB_NEW + [{'type': 'fill', 'target': FB_MESSAGE, 'value': FB_TEXT},
                                     {'type': 'click', 'target': btn('Submit')}, {'type': 'wait', 'ms': 500}],
              android=F_FB_NEW + [{'type': 'enter', 'key': 'feedback-new-message', 'value': FB_TEXT},
                                  {'type': 'tap', 'key': 'feedback-new-submit'}])
settings_case('feedback.ticket', 'Feedback: ticket conversation + reply composer', tab='feedback', region='panel',
              hint=FB_HINT, interactions=FB_OPEN, android=F_FB_OPEN)
settings_case('feedback.ticket-reply', 'Feedback: reply typed', tab='feedback', region='panel', hint=FB_HINT,
              interactions=FB_OPEN + [{'type': 'fill', 'target': FB_REPLY, 'value': FB_REPLY_TEXT}],
              android=F_FB_OPEN + [{'type': 'enter', 'key': 'feedback-reply-input', 'value': FB_REPLY_TEXT}])
settings_case('feedback.ticket-reply-error', 'Feedback: reply failed', tab='feedback', region='panel',
              hint=FB_HINT, route_set='feedback-reply-error',
              interactions=FB_OPEN + [{'type': 'fill', 'target': FB_REPLY, 'value': FB_REPLY_TEXT},
                                      {'type': 'click', 'target': btn('Send reply')}, {'type': 'wait', 'ms': 500}],
              android=F_FB_OPEN + [{'type': 'enter', 'key': 'feedback-reply-input', 'value': FB_REPLY_TEXT},
                                   {'type': 'tap', 'key': 'feedback-reply-send'}])
settings_case('feedback.ticket-closed', 'Feedback: closed ticket (no composer)', tab='feedback', region='panel',
              hint=FB_HINT,
              interactions=[{'type': 'click', 'target': FB_ROW.format(FB_CLOSED['id'])}, {'type': 'wait', 'ms': 500}],
              android=[{'type': 'tap', 'key': f"feedback-ticket-{FB_CLOSED['id']}"}])
settings_case('feedback.close-menu', 'Feedback: close reason menu', tab='feedback', hint=FB_HINT,
              selector='[data-slot="dropdown-menu-content"]', android_key='feedback-close-menu',
              interactions=FB_OPEN + [{'type': 'click', 'target': f"{FB_DETAIL} >> {btn('Choose a close reason')}"},
                                      {'type': 'wait', 'ms': 300}],
              android=F_FB_OPEN + [{'type': 'tap', 'key': 'feedback-close-caret'}])
settings_case('feedback.close-confirm', 'Feedback: close ticket confirm (no longer needed)', tab='feedback',
              hint=FB_HINT, selector=ALERT, android_key='feedback-close-dialog',
              interactions=FB_OPEN + [{'type': 'click', 'target': FB_CLOSE_MAIN}, {'type': 'wait', 'ms': 300}],
              android=F_FB_OPEN + [{'type': 'tap', 'key': 'feedback-close-main'}])
settings_case('feedback.close-confirm-resolved', 'Feedback: inbox row close (resolved -> completed)',
              tab='feedback', hint=FB_HINT, selector=ALERT, android_key='feedback-close-dialog',
              interactions=[{'type': 'click', 'target': "[data-parity-region='settings-panel'] "
                             f"li:has(button[data-ticket-id='{tickets[2]['id']}']) .hands-feedback-close-main"},
                            {'type': 'wait', 'ms': 300}],
              android=[{'type': 'tap', 'key': f"feedback-close-main-{tickets[2]['id']}"}])
settings_case('feedback.close-error', 'Feedback: close failed (error in dialog)', tab='feedback', hint=FB_HINT,
              selector=ALERT, android_key='feedback-close-dialog', route_set='feedback-close-error',
              interactions=FB_OPEN + [{'type': 'click', 'target': FB_CLOSE_MAIN}, {'type': 'wait', 'ms': 300},
                                      {'type': 'click', 'target': f'{ALERT} >> {btn("Close ticket")}'},
                                      {'type': 'wait', 'ms': 500}],
              android=F_FB_OPEN + [{'type': 'tap', 'key': 'feedback-close-main'},
                                   {'type': 'tap', 'key': 'feedback-close-confirm'}])

# Workspace group pages (owner; flags on for the gated tabs).
for tab, title, flags in [
    ('server', 'Server Profile', ''), ('billing', 'Plan & Billing', ''), ('administration', 'Administration', ''),
    ('integrations', 'Applications', ''), ('mcp', 'MCP Servers', ''), ('labs', 'Labs', 'labs'),
    ('providers', 'AI Providers', 'providers'), ('im-bridges', 'IM Bridges', 'bridge'),
    # Personal group tabs (page inventory 9.02, 9.06, 9.07): no desktop page case before.
    ('account', 'Account', ''), ('appearance', 'Appearance', ''), ('notifications', 'Notifications', ''),
]:
    settings_case(f'{tab}.page', f'{title}: whole page', tab=tab, flags=flags)
    settings_case(f'{tab}.panel', f'{title}: panel', tab=tab, region='panel', flags=flags, viewport=FRAME_TALL)

# ---------------------------------------------- Plan & Billing + Applications
# SettingsPanel.tsx PlanSection (+ PlanBillingLoadingSection, ConfirmDialog
# checkout) and IntegrationsSection (marketplace / installed / my apps tabs,
# grid / list views, listing + installed-app detail modals), desktop and the
# 390px mobile page (SettingsPanel full width, PanelHeader mobile back).
PLAN_HINT = SETTINGS_HINT + '#PlanSection'
APPS_HINT = SETTINGS_HINT + '#IntegrationsSection'
MOBILE_FRAME = {'width': 390, 'height': 844, 'density': 3}
billing_pro = {
    'plan': 'pro', 'displayName': 'Pro', 'serverPlan': 'pro', 'source': 'subscription',
    'capacity': {'maxHumans': -1, 'maxAgents': -1, 'maxUniversalSeats': 3},
    'usage': {'humans': 2, 'agents': 5, 'universalSeats': 2.5},
    'provisioned': {'humans': 3, 'agents': 30, 'proPackQuantity': 3, 'trialFreePackQuantity': 0,
                    'firstPackTrialEndsAt': None},
    'fileUploadQuota': {'month': '2026-06', 'plan': 'pro', 'limited': False, 'enforced': False,
                        'limitBytes': -1, 'usedBytes': 188_743_680, 'reservedBytes': 0, 'remainingBytes': -1},
    'price': {'billingInterval': 'annual', 'monthlyUsd': 26.4, 'annualUsd': 316.8, 'discountPercent': 12,
              'baseMonthlyUsd': 26.4, 'overageMonthlyUsd': 0, 'seatQuantity': 3, 'packQuantity': 3,
              'humanSeatQuantity': 3, 'agentSeatQuantity': 30, 'agentSeatBlockQuantity': 3},
    'subscription': {'status': 'active', 'billingInterval': 'annual', 'currentPeriodStart': '2026-06-18T00:00:00.000Z',
                     'currentPeriodEnd': '2027-06-18T00:00:00.000Z', 'cancelAtPeriodEnd': False},
    'stripeConfigured': True,
    'permissions': {'canReadBillingSummary': True, 'canManageBilling': True},
}
settings_fixture['routeSets'].update({
    'billing-pro': {'GET /billing/subscription': billing_pro},
    'billing-admin': {'GET /billing/subscription': {
        **billing_free, 'permissions': {'canReadBillingSummary': True, 'canManageBilling': False}}},
    'billing-loading': {'GET /billing/subscription': {'$pending': True}},
    'apps-empty': {'GET /integrations/marketplace': [], 'GET /integrations/clients': []},
})
settings_fixture['routes']['GET /integrations/overview'] = [
    {'id': 'grant-github', 'type': 'active', 'clientId': 'market_github', 'clientKey': 'client_github_issues',
     'clientName': 'GitHub Issues', 'agentName': 'cindy', 'agentDisplayName': 'Cindy',
     'scopes': ['openid', 'profile'], 'revokedAt': None}]
settings_fixture['routes']['GET /integrations/marketplace/market_github/install/app-notifications'] = {
    'requested_groups': [], 'approved_groups': [], 'subscribed_events': [], 'effective_groups': [],
    'effective_events': [], 'app_review_pending': False, 'approval_required': False}
CURRENT_PLAN = "[data-testid='billing-current-plan-card']"
SUMMARY = "[data-testid='billing-summary-card']"
MODAL_CARD = "[data-slot='modal-backdrop'] [data-slot='card']"
MARKET = "[data-testid='connected-apps-marketplace-collection'] > button"


def apps_tab(name):
    return {'type': 'click', 'target': f"[data-testid='connected-apps-tab-{name}']"}


settings_case('billing.current-plan', 'Plan & Billing: current plan card (free, trial)', tab='billing',
              selector=CURRENT_PLAN, android_key='billing-current-plan-card', hint=PLAN_HINT)
settings_case('billing.summary', 'Plan & Billing: checkout summary card', tab='billing', viewport=FRAME_TALL,
              selector=SUMMARY, android_key='billing-summary-card', hint=PLAN_HINT)
settings_case('billing.pro', 'Plan & Billing: Pro subscription (seat usage, manage seats)', tab='billing',
              region='panel', viewport=FRAME_TALL, route_set='billing-pro', hint=PLAN_HINT)
settings_case('billing.pro-plan', 'Plan & Billing: Pro current plan card (seat bar, portal)', tab='billing',
              selector=CURRENT_PLAN, android_key='billing-current-plan-card', route_set='billing-pro', hint=PLAN_HINT)
settings_case('billing.pro-summary', 'Plan & Billing: manage seats summary card', tab='billing',
              selector=SUMMARY, android_key='billing-summary-card', route_set='billing-pro', hint=PLAN_HINT,
              interactions=[{'type': 'reveal', 'target': SUMMARY}],
              android=[{'type': 'reveal', 'key': 'billing-summary-card'}])
settings_case('billing.admin', 'Plan & Billing: admin (cannot change billing)', tab='billing', role='admin',
              region='panel', viewport=FRAME_TALL, route_set='billing-admin', hint=PLAN_HINT)
settings_case('billing.loading', 'Plan & Billing: loading skeleton', tab='billing', region='panel',
              route_set='billing-loading', hint=SETTINGS_HINT + '#PlanBillingLoadingSection')
settings_case('billing.confirm-checkout', 'Plan & Billing: confirm Pro checkout dialog', tab='billing',
              selector=DIALOG, android_key='billing-confirm-dialog', hint=PLAN_HINT + ' + ConfirmDialog.tsx',
              interactions=[{'type': 'click', 'target': btn('Upgrade to Pro')}],
              android=[{'type': 'tap', 'key': 'billing-upgrade'}])
settings_case('billing.mobile', 'Plan & Billing: mobile page', tab='billing', viewport=MOBILE_FRAME,
              platform='mobile', hint=PLAN_HINT)
settings_case('billing.mobile-pro', 'Plan & Billing: mobile page, Pro', tab='billing', viewport=MOBILE_FRAME,
              platform='mobile', route_set='billing-pro', hint=PLAN_HINT)
# Phone sub-pages of the Resources / Workspace tabs that only had desktop cases
# (page inventory 9.16-9.22): SettingsPanel fills the 390px viewport.
for tab, title, flags in [
    ('about', 'About', ''), ('mcp', 'MCP Servers', ''), ('labs', 'Labs', 'labs'),
    ('providers', 'AI Providers', 'providers'), ('im-bridges', 'IM Bridges', 'bridge'),
]:
    settings_case(f'{tab}.mobile', f'{title}: mobile page', tab=tab, viewport=MOBILE_FRAME, platform='mobile',
                  flags=flags)

settings_case('integrations.installed', 'Applications: Installed tab', tab='integrations', region='panel',
              hint=APPS_HINT, interactions=[apps_tab('installed')],
              android=[{'type': 'tap', 'key': 'connected-apps-tab-installed'}])
settings_case('integrations.my-apps', 'Applications: My apps tab', tab='integrations', region='panel',
              hint=APPS_HINT, interactions=[apps_tab('my-apps')],
              android=[{'type': 'tap', 'key': 'connected-apps-tab-my-apps'}])
settings_case('integrations.list', 'Applications: marketplace list view', tab='integrations', region='panel',
              hint=APPS_HINT, interactions=[{'type': 'click', 'target': "[data-testid='connected-apps-view-toggle'] [aria-label='List view']"}],
              android=[{'type': 'tap', 'key': 'connected-apps-view-list'}])
settings_case('integrations.member', 'Applications: member (read-only)', tab='integrations', role='member',
              region='panel', hint=APPS_HINT)
settings_case('integrations.empty', 'Applications: no marketplace apps', tab='integrations', region='panel',
              route_set='apps-empty', hint=APPS_HINT)
settings_case('integrations.detail', 'Applications: marketplace app detail', tab='integrations',
              selector=MODAL_CARD, android_key='connected-app-detail', hint=APPS_HINT, viewport=FRAME_TALL,
              interactions=[{'type': 'click', 'target': f'{MARKET} >> nth=0'}],
              android=[{'type': 'tap', 'key': 'connected-app-market_slack'}])
settings_case('integrations.detail-installed', 'Applications: installed marketplace app detail (danger zone)',
              tab='integrations', selector=MODAL_CARD, android_key='connected-app-detail', hint=APPS_HINT,
              viewport=FRAME_TALL, interactions=[{'type': 'click', 'target': f'{MARKET} >> nth=1'}],
              android=[{'type': 'tap', 'key': 'connected-app-market_github'}])
settings_case('integrations.installed-detail', 'Applications: installed app access detail', tab='integrations',
              selector=MODAL_CARD, android_key='connected-app-installed-detail', hint=APPS_HINT,
              interactions=[apps_tab('installed'), {'type': 'click', 'target': "role=button[name='GitHub Issues's]"}],
              android=[{'type': 'tap', 'key': 'connected-apps-tab-installed'},
                       {'type': 'tap', 'key': 'connected-app-installed-market_github'}])
settings_case('integrations.mobile', 'Applications: mobile page', tab='integrations', viewport=MOBILE_FRAME,
              platform='mobile', hint=APPS_HINT)
settings_case('integrations.mobile-detail', 'Applications: mobile marketplace app detail', tab='integrations',
              viewport=MOBILE_FRAME, platform='mobile', selector=MODAL_CARD, android_key='connected-app-detail',
              hint=APPS_HINT, interactions=[{'type': 'click', 'target': f'{MARKET} >> nth=0'}],
              android=[{'type': 'tap', 'key': 'connected-app-market_slack'}])
# Administration (SettingsPanel.tsx AdministrationTabContent) section by
# section. Owner with the product-analytics flag on renders all nine sections
# in ADMINISTRATION_VISUAL_SECTIONS order; each crop is one section's
# `div.mb-6` (the Flutter key wraps the same box, bottom margin excluded).
# The tall frame keeps every section inside the viewport.
ADMIN_HINT = SETTINGS_HINT + '#AdministrationTabContent'
ADMIN_SECTIONS = ['admins', 'system-channels', 'invites', 'join-links', 'pre-join-agreement', 'onboarding',
                  'translation', 'product-analytics', 'member-permissions']
FRAME_ADMIN = {'width': 1280, 'height': 2800, 'density': 1}
MOBILE_ADMIN = {'width': 390, 'height': 3400, 'density': 3}
ADMIN_CONTENT = f"{PANEL} div.overflow-y-auto"


def admin_case(key, title, section, *, role='owner', flags='analytics', route_set='', interactions=(), android=(),
               mobile=False, selector=None, android_key=None, viewport=None, notes=None):
    sections = [s for s in ADMIN_SECTIONS if s != 'product-analytics' or 'analytics' in flags]
    sel = selector or f'{ADMIN_CONTENT} > div:nth-child({sections.index(section) + 1})'
    settings_case(key, title, tab='administration', role=role, flags=flags, route_set=route_set,
                  selector=sel, android_key=android_key or f'admin-section-{section}',
                  viewport=viewport or (MOBILE_ADMIN if mobile else FRAME_ADMIN),
                  interactions=interactions, android=android, hint=ADMIN_HINT, notes=notes,
                  platform='mobile' if mobile else 'desktop')


settings_case('administration.all', 'Administration: panel, all nine sections', tab='administration',
              region='panel', flags='analytics', viewport=FRAME_ADMIN, hint=ADMIN_HINT)
for section in ADMIN_SECTIONS:
    admin_case(f'administration.{section}', f'Administration section: {section}', section)
# States.
admin_case('administration.admins.picker-open', 'Administration: owner/admin picker open', 'admins',
           selector=f"{ADMIN_CONTENT} > div:nth-child(1) div.relative:has(> [data-testid='admin-principal-picker'])",
           android_key='admin-principal-picker-region',
           notes='Trigger plus the open SelectionPopover (search + candidates).',
           interactions=[{'type': 'click', 'target': "[data-testid='admin-principal-picker']"},
                         {'type': 'wait', 'ms': 300}],
           android=[{'type': 'tap', 'key': 'admin-principal-picker'}, {'type': 'wait', 'ms': 300}])
admin_case('administration.admins.selected', 'Administration: candidate picked (role + Update Role enabled)',
           'admins',
           interactions=[{'type': 'click', 'target': "[data-testid='admin-principal-picker']"},
                         {'type': 'wait', 'ms': 300},
                         {'type': 'click', 'target': f'{ADMIN_CONTENT} button:has-text("Designer · designer@slock.ai")'},
                         {'type': 'wait', 'ms': 300}],
           android=[{'type': 'tap', 'key': 'admin-principal-picker'}, {'type': 'wait', 'ms': 300},
                    {'type': 'tap', 'key': 'admin-candidate-human:visual-human-designer'}, {'type': 'wait', 'ms': 300}])
admin_case('administration.admins.as-admin', 'Administration: Owners & Admins viewed by an admin', 'admins',
           role='admin')
admin_case('administration.invites.empty', 'Administration: no pending invites', 'invites',
           route_set='admin-empty')
admin_case('administration.join-links.empty', 'Administration: no invite links', 'join-links',
           route_set='admin-empty')
admin_case('administration.pre-join-agreement.disabled', 'Administration: agreement not required',
           'pre-join-agreement', route_set='admin-agreement-off')
admin_case('administration.onboarding.setup', 'Administration: onboarding with unfinished server setup',
           'onboarding', route_set='admin-setup-open')
admin_case('administration.translation.provider-warning', 'Administration: translation without a provider',
           'translation', route_set='admin-no-provider')
admin_case('administration.system-channels.visible', 'Administration: #all visible (unchecked)',
           'system-channels', route_set='admin-all-visible')
admin_case('administration.member-permissions.hidden', 'Administration: humans hidden from members',
           'member-permissions', route_set='admin-hide-humans')
# Confirmations (ConfirmDialog card).
admin_case('administration.invites.confirm', 'Administration: revoke invite confirmation', 'invites',
           selector=DIALOG, android_key='admin-confirm-dialog', viewport=FRAME,
           interactions=[{'type': 'click', 'target': f"{btn('Revoke invite')} >> nth=0"}, {'type': 'wait', 'ms': 300}],
           android=[{'type': 'tap', 'key': 'admin-invite-revoke-invite-visual-designer'}, {'type': 'wait', 'ms': 300}])
admin_case('administration.join-links.confirm', 'Administration: revoke invite link confirmation', 'join-links',
           selector=DIALOG, android_key='admin-confirm-dialog', viewport=FRAME,
           interactions=[{'type': 'click', 'target': btn('Revoke invite link')}, {'type': 'wait', 'ms': 300}],
           android=[{'type': 'tap', 'key': 'admin-join-link-revoke-join-link-visual'}, {'type': 'wait', 'ms': 300}])
# Mobile (390 @3x): the `sm:` / `md:` breakpoints stack the picker row, the
# onboarding rows and the invite-link form.
for section in ['admins', 'join-links', 'onboarding', 'pre-join-agreement']:
    admin_case(f'administration.mobile.{section}', f'Administration (mobile): {section}', section, mobile=True)

manifest = {
    'version': 1,
    'name': 'raft-flutter parity extension suite',
    'description': ('Generated by tool/parity-ext/build-cases.py. NOT part of the official visual-testing case set: '
                    'raft-flutter additions in the official sharedCases.json schema, captured by the official '
                    'React provider spec (generated copy) and the Flutter provider, diffed/sited by the official CLI.'),
    'cases': cases,
}
manifest_path().write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/computers.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/settings.json').write_text(json.dumps(settings_fixture, indent=1, ensure_ascii=False) + '\n')
print(f"{len(cases)} extension cases -> the run-time manifest ($PARITY_EXT_MANIFEST); fixtures -> tool/parity-ext/fixtures/{{computers,settings}}.json")
