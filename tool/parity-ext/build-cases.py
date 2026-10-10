#!/usr/bin/env python3
"""Generate the raft-flutter EXTENSION suite for the official visual-testing
framework: tool/parity-ext/cases.json (same schema as raft-source
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

here = pathlib.Path(__file__).resolve().parent
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
CARD_DIALOG = '.fixed.inset-0 [data-slot="card"]'
cases = []


def btn(name):
    """Playwright role selector, exact accessible name."""
    return f'role=button[name="{name}"s]'


def add(key, title, *, kind, viewport, selector=None, android_key=None, props=None, interactions=(),
        android=(), hint=MDP, notes=None):
    for suffix, theme in THEMES.items():
        cid = f'components.computers.{key}.{suffix}'
        sel = selector or f"[data-visual-case='{cid}']"
        p = {'extCase': key, 'extKind': kind, 'parityTheme': theme, 'platform': 'desktop', **(props or {})}
        c = {
            'id': cid,
            'title': f'Computers {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'computers',
            'category': 'extension/computers',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': p}],
            'capture': {'selector': sel, 'crop': 'element', 'contract': 'component-bounds',
                        'androidKey': android_key, 'interactions': list(interactions),
                        'androidInteractions': list(android)},
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_computers.dart '{key}'",
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
    'info': 'div.px-5.py-4.border-b:has(.gap-x-8)',
    'agents': 'div.space-y-6 > div:has(> div.flex-wrap.gap-y-2)',
    'workspaces': 'div.mt-2.border-t:has(svg.lucide-folder-open)',
    'service': '[data-testid="computer-service-actions"]',
    'recovery-guide': '[data-testid="computer-recovery-guide"]',
    'delete': 'div.mt-2.border-t > div.p-4:last-child',
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

manifest = {
    'version': 1,
    'name': 'raft-flutter parity extension suite',
    'description': ('Generated by tool/parity-ext/build-cases.py. NOT part of the official visual-testing case set: '
                    'raft-flutter additions in the official sharedCases.json schema, captured by the official '
                    'React provider spec (generated copy) and the Flutter provider, diffed/sited by the official CLI.'),
    'cases': cases,
}
(here / 'cases.json').write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/computers.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} extension cases -> tool/parity-ext/cases.json; fixture -> tool/parity-ext/fixtures/computers.json')
