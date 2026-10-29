#!/usr/bin/env python3
"""Append the work package 6 (task and settings leftovers) cases to
the run-time manifest ($PARITY_EXT_MANIFEST) and write tool/parity-ext/fixtures/wp6.json.

Run after every other build-*.py (append-only for the other families;
idempotent: every `components.wp6.*` case is replaced).

Ids (append-only, never rename): components.wp6.<surface>.<state>.<theme>

Derivation (raft-source 26f77ef, packages/web/src/components):
  task/CreateTaskDialog.tsx            create task dialog (DialogCard)
  task/TaskFilterSegmentedControl.tsx  status filter tabs with counts
  task/TasksPanel.tsx                  TaskSectionEmpty / TaskBoardColumnEmpty
                                       (dashed "No {status} tasks.")

React (host/Wp6Cases.tsx) mounts the real Web component per surface; Flutter
(cases/ext_wp6.dart) mounts the product widget on the same fixture
(fixtures/wp6.json; every route lives in a `routeSets` entry so no other case
family sees it).
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.wp6.'
CARD_DIALOG = '.fixed.inset-0 [data-slot="dialog-card"]'
DART = 'ext_wp6.dart'

taskdetail = json.loads((here / 'fixtures/taskdetail.json').read_text())
board_all = taskdetail['board']
by_number = {t['taskNumber']: t for t in board_all}

fixture = {
    'name': 'raft-flutter parity extension: work package 6 (task and settings leftovers)',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'routes': {},
    'routeSets': {},
}
# Tasks board with empty lanes: in review / done / closed have no task.
fixture['boards'] = {
    'empty-lanes': [by_number[23], by_number[22], by_number[20]],
}
fixture['filterCounts'] = {'all': 13, 'todo': 3, 'in_progress': 3, 'in_review': 2, 'done': 3, 'closed': 0}
fixture['routeSets']['wp6-board-empty-lanes'] = {'GET /tasks/server': {'tasks': fixture['boards']['empty-lanes']}}

cases = []


def add(key, title, *, surface, platform='desktop', selector, android_key=None, state=None, route_set=None,
        interactions=(), android=(), hint, notes=None, viewport=None, crop='element', contract='component-bounds',
        props=None):
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{key}.{suffix}'
        p = {'extCase': key, 'extKind': 'wp6', 'parityTheme': theme, 'platform': platform, 'surface': surface,
             'state': state or key.split('.')[-1], **(props or {})}
        if route_set:
            p['routeSet'] = route_set
        capture = {'selector': selector or f"[data-visual-case='{cid}']", 'crop': crop, 'contract': contract,
                   'interactions': list(interactions), 'androidInteractions': list(android)}
        if android_key:
            capture['androidKey'] = android_key
        c = {
            'id': cid,
            'title': f'WP6 {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'wp6',
            'category': 'extension/wp6',
            'suite': 'raft-flutter-extension',
            'viewport': viewport or (DESKTOP if platform == 'desktop' else MOBILE),
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': p}],
            'capture': capture,
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/{DART} '{key}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if notes:
            c['notes'] = notes
        cases.append(c)


def btn(name):
    return f'role=button[name="{name}"s]'


# ---------------------------------------------------------------- tasks
CT_HINT = 'packages/web/src/components/task/CreateTaskDialog.tsx (+ ui/DialogCard.tsx)'
for plat in ('desktop', 'mobile'):
    sfx = '' if plat == 'desktop' else '-mobile'
    ph = lambda i: f'input[placeholder="Task {i}"]'
    add(f'tasks.create-dialog{sfx}', f'Create task dialog ({plat})', surface='tasks-create', platform=plat,
        selector=CARD_DIALOG, android_key='create-task-dialog', hint=CT_HINT)
    add(f'tasks.create-dialog-filled{sfx}', f'Create task dialog, one title typed ({plat})', surface='tasks-create',
        platform=plat, selector=CARD_DIALOG, android_key='create-task-dialog', hint=CT_HINT,
        interactions=[{'type': 'fill', 'target': ph(1), 'value': 'Wire the Tasks board to the new status lanes'}],
        android=[{'type': 'enter', 'key': 'create-task-title-0', 'value': 'Wire the Tasks board to the new status lanes'}])
    add(f'tasks.create-dialog-batch{sfx}', f'Create task dialog, two rows ({plat})', surface='tasks-create',
        platform=plat, selector=CARD_DIALOG, android_key='create-task-dialog', hint=CT_HINT,
        interactions=[{'type': 'fill', 'target': ph(1), 'value': 'Wire the Tasks board'},
                      {'type': 'click', 'target': btn('Add Another')},
                      {'type': 'fill', 'target': ph(2), 'value': 'Audit elegant-dark tokens'}],
        android=[{'type': 'enter', 'key': 'create-task-title-0', 'value': 'Wire the Tasks board'},
                 {'type': 'tap', 'key': 'create-task-add-row'},
                 {'type': 'enter', 'key': 'create-task-title-1', 'value': 'Audit elegant-dark tokens'}])
    add(f'tasks.create-dialog-error{sfx}', f'Create task dialog, title required ({plat})', surface='tasks-create',
        platform=plat, selector=CARD_DIALOG, android_key='create-task-dialog', hint=CT_HINT,
        interactions=[{'type': 'click', 'target': btn('Create Task')}, {'type': 'wait', 'ms': 300}],
        android=[{'type': 'tap', 'key': 'create-task-submit'}])

FILTER_HINT = 'packages/web/src/components/task/TaskFilterSegmentedControl.tsx'
for plat in ('desktop', 'mobile'):
    sfx = '' if plat == 'desktop' else '-mobile'
    add(f'tasks.filter{sfx}', f'Task filter segmented control ({plat})', surface='tasks-filter', platform=plat,
        selector='[aria-label="Filter tasks"]', android_key='task-filter', hint=FILTER_HINT, state='default')
    add(f'tasks.filter-selected{sfx}', f'Task filter segmented control, In Progress selected ({plat})',
        surface='tasks-filter', platform=plat, selector='[aria-label="Filter tasks"]', android_key='task-filter',
        hint=FILTER_HINT, state='selected')

BOARD_HINT = 'packages/web/src/components/task/TasksPanel.tsx (TaskBoardColumnEmpty / TaskSectionEmpty)'
EXPAND = [{'type': 'click', 'target': f'[aria-label="Show {label}"]'} for label in ('Done', 'Closed')]
EXPAND_ANDROID = [{'type': 'tap', 'key': f'task-group-{s}'} for s in ('done', 'closed')]
add('tasks.empty-lanes', 'Tasks board with empty lanes (desktop board)', surface='tasks-board',
    selector='[data-testid="thread-main-column"]', state='empty-lanes', route_set='wp6-board-empty-lanes',
    hint=BOARD_HINT, notes='In review is empty; Done and Closed start collapsed.')
add('tasks.empty-lanes-expanded', 'Tasks board with empty lanes, Done and Closed expanded (desktop board)',
    surface='tasks-board', selector='[data-testid="thread-main-column"]', state='empty-lanes',
    route_set='wp6-board-empty-lanes', hint=BOARD_HINT, interactions=EXPAND, android=EXPAND_ANDROID)
add('tasks.empty-lanes-mobile', 'Tasks page with empty lanes (mobile list)', surface='tasks-board',
    platform='mobile', selector='body', crop='viewport', contract='viewport-with-portal', state='empty-lanes',
    route_set='wp6-board-empty-lanes', hint=BOARD_HINT)

# ------------------------------------------------------------- settings
SETTINGS_HINT = 'packages/web/src/components/settings/SettingsPanel.tsx'
PANEL = "[data-parity-region='settings-panel']"
WAIT = {'type': 'wait', 'ms': 800}


def settings_add(key, title, *, tab, platform='desktop', selector=None, android_key=None, flags='', role='owner',
                 route_set=None, prefs=None, interactions=(), android=(), hint=SETTINGS_HINT, notes=None,
                 viewport=None):
    mobile = platform == 'mobile'
    props = {'tab': tab, 'role': role}
    if flags:
        props['flags'] = flags
    if prefs:
        props['prefs'] = prefs
    if selector is None and not mobile:
        # Desktop crops the 976px panel column; mobile the whole 390px frame.
        selector, android_key = PANEL, 'settings-panel'
    add(key, title, surface='settings', platform=platform, selector=selector, android_key=android_key,
        route_set=route_set, interactions=[WAIT, *interactions], android=android, hint=hint, notes=notes,
        viewport=viewport, props=props, state=key.split('.')[-1])


# Language & Region (SettingsPanel.tsx LanguageRegionSection): display
# language, translation mode (+ target and default view unless Off) and the
# Date & time card.
LANG = SETTINGS_HINT + '#LanguageRegionSection'
fixture['routeSets']['wp6-translation-provider-missing'] = {
    f'GET /servers/{taskdetail["serverId"]}/translation-settings': {
        'translationEnabled': True, 'translationAvailable': False, 'canManageTranslation': True}}
fixture['routeSets']['wp6-translation-server-off'] = {
    f'GET /servers/{taskdetail["serverId"]}/translation-settings': {
        'translationEnabled': False, 'translationAvailable': True, 'canManageTranslation': True}}
for plat in ('desktop', 'mobile'):
    sfx = '' if plat == 'desktop' else '-mobile'
    settings_add(f'settings.language{sfx}', f'Language & Region ({plat})', tab='language-region', platform=plat,
                 hint=LANG)
    settings_add(f'settings.language-off{sfx}', f'Language & Region, translation off ({plat})',
                 tab='language-region', platform=plat, prefs='translation-off', hint=LANG)
settings_add('settings.language-manual', 'Language & Region, manual translation, bilingual', tab='language-region',
             prefs='translation-manual', hint=LANG)
settings_add('settings.language-provider-missing', 'Language & Region, no translation provider',
             tab='language-region', route_set='wp6-translation-provider-missing', hint=LANG)
settings_add('settings.language-server-off', 'Language & Region, translation off for the server (admin)',
             tab='language-region', route_set='wp6-translation-server-off', hint=LANG)

# Account tab card: UsageDataSettingsCard. The workspace-mode card left with
# the desktop grid (Web v1.21.x).
CONTENT = "[data-parity-region='settings-panel'] > section > div.overflow-y-auto"
UD_SEL = f'{CONTENT} > div.mt-6 > [data-slot="card"]'
for plat in ('desktop', 'mobile'):
    sfx = '' if plat == 'desktop' else '-mobile'
    settings_add(f'settings.usage-data{sfx}', f'Account: usage data card ({plat})', tab='account', platform=plat,
                 flags='analytics', selector=UD_SEL, android_key='usage-data-card',
                 android=[{'type': 'reveal', 'key': 'usage-data-card'}],
                 hint='packages/web/src/components/settings/UsageDataSettings.tsx')

# AI provider connections: EditProviderConnectionModal.
PROV_HINT = 'packages/web/src/components/settings/EditProviderConnectionModal.tsx'
GATEWAY = {
    'id': 'conn-gateway', 'name': 'Team gateway', 'providerId': 'openai-compatible', 'authMethod': 'api_key',
    'endpointUrl': 'https://llm.example.com/v1', 'supportsImageInput': True, 'enabled': True, 'status': 'ready',
    'configVersion': 3, 'credentialVersion': 2, 'hasCredential': True, 'assignedAgentCount': 0,
    'latestVerified': None, 'lastCheckedAt': '2026-06-20T08:00:00.000Z', 'lastErrorCategory': None,
    'createdAt': '2026-06-01T08:00:00.000Z', 'updatedAt': '2026-06-20T08:00:00.000Z'}
PRESET = {**GATEWAY, 'id': 'conn-anthropic', 'name': 'Anthropic production', 'providerId': 'anthropic',
          'endpointUrl': None, 'supportsImageInput': False, 'configVersion': 1, 'credentialVersion': 1}
CATALOG = {
    'connections': [GATEWAY, PRESET],
    'providerOptions': [
        {'id': 'anthropic', 'label': 'Anthropic', 'providerKind': 'preset'},
        {'id': 'openai-compatible', 'label': 'OpenAI-compatible', 'providerKind': 'gateway'},
        {'id': 'anthropic-compatible', 'label': 'Anthropic-compatible', 'providerKind': 'gateway'}]}
fixture['routeSets']['wp6-providers'] = {'GET /provider-connections': CATALOG}
fixture['routeSets']['wp6-providers-save-error'] = {
    'GET /provider-connections': CATALOG, 'PATCH /provider-connections/conn-gateway': {'$status': 500}}
EDIT_BTN = f'role=button[name="Edit connection"s]'
EDIT_DIALOG = '[data-testid="provider-connection-edit-dialog"]'
for plat in ('desktop', 'mobile'):
    sfx = '' if plat == 'desktop' else '-mobile'
    settings_add(f'settings.provider-edit{sfx}', f'AI provider edit modal, gateway ({plat})', tab='providers',
                 platform=plat, flags='providers', route_set='wp6-providers', selector=EDIT_DIALOG,
                 android_key='provider-connection-edit-dialog', hint=PROV_HINT,
                 interactions=[{'type': 'click', 'target': f'{EDIT_BTN} >> nth=0'}, {'type': 'wait', 'ms': 300}],
                 android=[{'type': 'tap', 'key': 'provider-edit-conn-gateway'}])
    settings_add(f'settings.provider-edit-preset{sfx}', f'AI provider edit modal, preset provider ({plat})',
                 tab='providers', platform=plat, flags='providers', route_set='wp6-providers',
                 selector=EDIT_DIALOG, android_key='provider-connection-edit-dialog', hint=PROV_HINT,
                 interactions=[{'type': 'click', 'target': f'{EDIT_BTN} >> nth=1'}, {'type': 'wait', 'ms': 300}],
                 android=[{'type': 'tap', 'key': 'provider-edit-conn-anthropic'}])
settings_add('settings.provider-edit-error', 'AI provider edit modal, save failed', tab='providers',
             flags='providers', route_set='wp6-providers-save-error', selector=EDIT_DIALOG,
             android_key='provider-connection-edit-dialog', hint=PROV_HINT,
             interactions=[{'type': 'click', 'target': f'{EDIT_BTN} >> nth=0'}, {'type': 'wait', 'ms': 300},
                           {'type': 'click', 'target': f'{EDIT_DIALOG} >> role=button[name="Save changes"s]'},
                           {'type': 'wait', 'ms': 500}],
             android=[{'type': 'tap', 'key': 'provider-edit-conn-gateway'},
                      {'type': 'tap', 'key': 'provider-edit-save'}])

# Slack bridge setup wizard (IMBridgesSettingsSection + SlackBridgeSetupWizard).
BRIDGE_HINT = 'packages/web/src/components/settings/SlackBridgeSetupWizard.tsx'
UUID1 = '5b0e8c1a-7d3f-4c2e-9a61-0f2d3c4b5a61'
UUID2 = '9e8d7c6b-5a4f-4e3d-9c2b-1a0f9e8d7c34'
RAFT_CH = [{'id': 'channel-design', 'name': 'design'}, {'id': 'channel-android', 'name': 'android-artifacts'},
           {'id': 'channel-general', 'name': 'general'}]
SLACK_CH = [{'id': 'C01ENG', 'name': 'eng', 'privacyClass': 'public', 'isMember': True},
            {'id': 'C02REVIEWS', 'name': 'design-reviews', 'privacyClass': 'private', 'isMember': True},
            {'id': 'C03RANDOM', 'name': 'random', 'privacyClass': 'public', 'isMember': False}]
EPOCHS = {'grant': 'g1', 'connection': '4', 'scope': 's1', 'credential': 'c1'}
ACTIVE_INSTALL = {'state': 'active', 'epochs': EPOCHS}


def raw_health(**kw):
    base = {'install': ACTIVE_INSTALL, 'credential': {'state': 'active'}, 'bindings': [], 'audiences': [],
            'lastVerifiedAt': None, 'failingSurface': None}
    base.update(kw)
    return base


def bridge(stage, *, workspace='Acme Workspace', pairs=(), slack=SLACK_CH, preflight=None, health=None, oauth=False):
    return {'protocolVersion': 1, 'snapshot': {
        'stage': stage, 'workspaceName': workspace, 'raftChannels': RAFT_CH, 'slackChannels': list(slack),
        'channelPairs': list(pairs), 'preflight': preflight, 'rawHealth': health or raw_health()},
        'oauthAuthority': ({'registrationId': UUID1, 'serverGrantId': UUID2, 'grantEpoch': 1} if oauth else None)}


PAIRS = [{'raftChannelId': 'channel-design', 'slackChannelId': 'C02REVIEWS', 'bindingEpoch': 2},
         {'raftChannelId': 'channel-android', 'slackChannelId': 'C01ENG', 'bindingEpoch': 3}]
BINDINGS = [{'id': 'binding-1', 'state': 'active', 'bindingEpoch': 2, 'stateReason': None, 'recoveryAction': 'none'},
            {'id': 'binding-2', 'state': 'active', 'bindingEpoch': 3, 'stateReason': None, 'recoveryAction': 'none'}]
VERIFIED = '2026-06-20T08:30:00.000Z'
PF_FAILED = {'state': 'failed', 'checks': [{'id': 'oauth', 'state': 'passed'}, {'id': 'endpoint', 'state': 'passed'},
                                           {'id': 'scope', 'state': 'failed'}, {'id': 'audience', 'state': 'unverified'}]}
PF_PASSED = {'state': 'passed', 'checks': [{'id': c, 'state': 'passed'} for c in ('oauth', 'endpoint', 'scope', 'audience')]}
BRIDGE_STATES = {
    'connect': bridge('connect', workspace=None, health=raw_health(install=None, credential=None)),
    'oauth': bridge('oauth', workspace=None, oauth=True,
                    health=raw_health(install={'state': 'pending', 'epochs': EPOCHS}, credential=None)),
    'channels': bridge('channels'),
    'channels-pairs': bridge('channels', pairs=[{'raftChannelId': 'channel-design', 'slackChannelId': 'C02REVIEWS'}]),
    'preflight': bridge('preflight', pairs=PAIRS, preflight=PF_FAILED),
    'enable': bridge('enable', pairs=PAIRS, preflight=PF_PASSED),
    'health': bridge('health', pairs=PAIRS, health=raw_health(
        bindings=BINDINGS, lastVerifiedAt=VERIFIED,
        audiences=[{'bindingId': 'binding-1', 'status': 'matched'}, {'bindingId': 'binding-2', 'status': 'matched'}])),
    'health-recovery': bridge(
        'health', pairs=PAIRS,
        slack=[SLACK_CH[0], {**SLACK_CH[1], 'isMember': False}, SLACK_CH[2]],
        health=raw_health(bindings=BINDINGS, lastVerifiedAt=VERIFIED, failingSurface='audience', audiences=[
            {'bindingId': 'binding-1', 'status': 'mismatch'}, {'bindingId': 'binding-2', 'status': 'matched'}])),
    'health-unverified': bridge('health', pairs=PAIRS, health=raw_health(bindings=BINDINGS)),
}
for name, body in BRIDGE_STATES.items():
    fixture['routeSets'][f'wp6-bridge-{name}'] = {'GET /slack-bridge/provisioning': body}


def bridge_add(key, title, state, *, platform='desktop', role='owner', interactions=(), android=(),
               selector=None, android_key=None, extra_routes=None):
    route = f'wp6-bridge-{state}'
    if extra_routes:
        fixture['routeSets'][route] = {**fixture['routeSets'][route], **extra_routes}
    settings_add(key, title, tab='im-bridges', platform=platform, flags='bridge', role=role,
                 route_set=route, interactions=interactions, android=android, selector=selector,
                 android_key=android_key, hint=BRIDGE_HINT)


WIZ = "[data-testid='slack-bridge-setup-wizard']"
for state, label in [('connect', 'connect stage'), ('oauth', 'OAuth stage'), ('channels', 'channel pairs, none chosen'),
                     ('channels-pairs', 'channel pairs, one chosen'), ('preflight', 'preflight failed'),
                     ('enable', 'enable stage'), ('health', 'health, connected'),
                     ('health-recovery', 'health, Slack channel access removed'),
                     ('health-unverified', 'health, not verified yet')]:
    bridge_add(f'settings.bridge-{state}', f'Slack bridge wizard: {label}', state, selector=WIZ,
               android_key='slack-bridge-wizard')
for state in ('connect', 'channels-pairs', 'preflight', 'health-recovery'):
    bridge_add(f'settings.bridge-{state}-mobile', f'Slack bridge wizard: {state} (mobile)', state,
               platform='mobile', selector=WIZ, android_key='slack-bridge-wizard')
bridge_add('settings.bridge-health-readonly', 'Slack bridge wizard: health, view only (member)', 'health',
           role='member', selector=WIZ, android_key='slack-bridge-wizard')
bridge_add('settings.bridge-manage', 'Slack bridge wizard: managing channel mappings', 'health',
           selector=WIZ, android_key='slack-bridge-wizard',
           interactions=[{'type': 'click', 'target': 'role=button[name="Manage channel mappings"s]'},
                         {'type': 'wait', 'ms': 300}],
           android=[{'type': 'tap', 'key': 'slack-bridge-manage'}])
bridge_add('settings.bridge-disconnect', 'Slack bridge wizard: disconnect confirmation', 'health',
           selector=WIZ, android_key='slack-bridge-wizard',
           interactions=[{'type': 'click', 'target': 'role=button[name="Disconnect Slack workspace"s]'},
                         {'type': 'wait', 'ms': 300}],
           android=[{'type': 'tap', 'key': 'slack-bridge-disconnect'}])
fixture['routeSets']['wp6-bridge-error'] = {'GET /slack-bridge/provisioning': {'$status': 500}}
bridge_add('settings.bridge-error', 'Slack bridge: load failed', 'error')

# About / Feedback panel (AboutFeedbackDialog.tsx AboutFeedbackPanel) at phone
# width: inbox, New feedback form and the ticket conversation. The data is the
# ext-settings feedback fixture (fixtures/settings.json).
FB_HINT = 'packages/web/src/components/settings/AboutFeedbackDialog.tsx (+ @botiverse/hands-feedback-react)'
FB_ID = '5b0e8c1a-7d3f-4c2e-9a61-0f2d3c4b5a61'
MROW = f"[data-parity-region='settings-panel'] li:has(button[data-ticket-id='{FB_ID}']) .hands-feedback-ticket-title"
# Later fixture files (shell.json) also answer GET /product-feedback/tickets and,
# registered after settings.json, win: restate the feedback reads in a route set.
_settings = json.loads((here / 'fixtures/settings.json').read_text())
fixture['routeSets']['wp6-feedback'] = {k: v for k, v in _settings['routes'].items() if 'product-feedback' in k}
settings_add('settings.feedback-mobile', 'Feedback: inbox (mobile)', tab='feedback', platform='mobile', hint=FB_HINT,
             route_set='wp6-feedback')
settings_add('settings.feedback-new-mobile', 'Feedback: New feedback form (mobile)', tab='feedback',
             platform='mobile', hint=FB_HINT, route_set='wp6-feedback',
             interactions=[{'type': 'click', 'target': btn('New feedback')}, {'type': 'wait', 'ms': 500}],
             android=[{'type': 'tap', 'key': 'feedback-new'}])
settings_add('settings.feedback-ticket-mobile', 'Feedback: ticket conversation (mobile)', tab='feedback',
             platform='mobile', hint=FB_HINT, route_set='wp6-feedback',
             interactions=[{'type': 'click', 'target': MROW}, {'type': 'wait', 'ms': 700}],
             android=[{'type': 'tap', 'key': f'feedback-ticket-{FB_ID}'}])

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/wp6.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} wp6 cases appended -> the run-time manifest; fixture -> tool/parity-ext/fixtures/wp6.json')
