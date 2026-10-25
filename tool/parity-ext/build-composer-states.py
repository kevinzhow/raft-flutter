#!/usr/bin/env python3
"""Append the composer-state cases to the run-time manifest ($PARITY_EXT_MANIFEST) and write
tool/parity-ext/fixtures/composer-states.json.

Run after build-screen-cases.py (the channel / DM scenes and the shared shell workspace come
from fixtures/screens.json); idempotent: every `components.composer-states.*` case is replaced,
all other cases are kept in place.

Page-inventory rows (page inventory, tool/parity-ext/inventory.py, Area 3):
  3.21  Composer "As task" mode            surface `as-task`
  3.22  Pending-mention action strip       surface `pending-mention`
  3.24  Composer warnings                  surface `warning` (agent stopped delivery, unresolved
        mentions, channel conversion in progress) and `suggestions` (archived badge)

Derivation (raft-source, packages/web/src/components/message):
  MessageInput.tsx               the banners above the composer card (unresolvedMentionHandles /
                                 deliveryWarnings come from the POST /v2/messages receipt), the
                                 `As Task` checkbox, the disabled Send while a conversion blocks
                                 sending, the #channel popover with the `archived` Badge
  PendingMentionActionStrip.tsx  rows (Add / Notify / Ignore) and the Add-all footer
Ids: components.composer-states.<surface>.<platform>.<state>.<theme>. The composed channel / DM
screen of the screens-ext family (real LeftRail + Sidebar + ChatPanel on Web, real WorkspaceView in
Flutter) at 1280x800 / 390x844; the capture is a window over the bottom of the screen
(`composer-window` marker) so only the composer, its banner and the popover are compared. The send
states type the draft and press Enter; the receipt is answered by `POST /v2/messages` in the
fixture, identically for both providers.
"""
import copy
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)

THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.composer-states.'
SID = 'visual-server'

screens = json.loads((here / 'fixtures/screens.json').read_text())
CHANNEL_SCENE = screens['scenes']['channel']
DM_SCENE = screens['scenes']['dm-agent']
CHANNEL = CHANNEL_SCENE['selected']
DM = DM_SCENE['selected']
OWNER_ID = 'visual-user'
SENT_AT = '2026-06-19T12:31:00.000Z'


def receipt(channel, content, **extra):
    """A POST /v2/messages receipt (message + the wrapped warning fields)."""
    return {
        'message': {'id': f'cs-sent-{channel}', 'seq': 90, 'serverId': SID, 'channelId': channel,
                    'messageType': 'chat', 'senderType': 'user', 'senderId': OWNER_ID, 'senderName': 'artin',
                    'senderDisplayName': 'artin', 'content': content, 'createdAt': SENT_AT},
        'pendingMentionActions': [], 'unresolvedMentionHandles': [], **extra,
    }


def pending(message_id, handle, n):
    return {'resolutionId': f'cs-pending-{n}', 'messageId': message_id, 'targetType': 'agent',
            'targetHandle': handle, 'targetAvatarUrl': 'pixel:robot', 'reason': 'target_not_in_channel',
            'availableActions': ['add', 'notify'], 'expiresAt': None}


ARCHIVED = {'id': 'shell-archived-launch', 'serverId': SID, 'name': 'launch-2025', 'type': 'channel',
            'description': 'Retired launch planning', 'createdAt': '2026-05-01T00:00:00.000Z', 'joined': True,
            'archivedAt': '2026-06-01T00:00:00.000Z'}
CONVERSION = {'id': 'cs-conversion-job', 'status': 'running', 'phase': 'copying_messages', 'canCancel': True}

ASTASK_DRAFT = 'Review the sidebar spacing before Friday.'
SINGLE = '@Android-Developer-4 please review the visual diff'
MULTI = '@Android-Developer-4 @QA-Engineer-2 please review the visual diff'
STOPPED = 'Thanks, please re-run the three flagged cases.'
UNRESOLVED = '@ghostwriter @nobody can you take a look at this?'

# state -> scene, draft, send (type + Enter) / extra interaction, receipt, store patches
STATES = {
    'as-task': dict(scene='channel', draft=ASTASK_DRAFT, toggle=True),
    'single': dict(scene='channel', draft=SINGLE, send=True,
                   receipt=receipt(CHANNEL, SINGLE, pendingMentionActions=[
                       pending(f'cs-sent-{CHANNEL}', 'Android-Developer-4', 1)])),
    'multi': dict(scene='channel', draft=MULTI, send=True,
                  receipt=receipt(CHANNEL, MULTI, pendingMentionActions=[
                      pending(f'cs-sent-{CHANNEL}', 'Android-Developer-4', 1),
                      pending(f'cs-sent-{CHANNEL}', 'QA-Engineer-2', 2)])),
    'agent-stopped': dict(scene='dm-agent', draft=STOPPED, send=True,
                          receipt=receipt(DM, STOPPED, deliveryWarnings=[
                              {'targetType': 'agent', 'targetId': 'agent-cindy', 'reason': 'agent_stopped'}])),
    'unresolved': dict(scene='channel', draft=UNRESOLVED, send=True,
                       receipt=receipt(CHANNEL, UNRESOLVED, unresolvedMentionHandles=['ghostwriter', 'nobody'])),
    'conversion': dict(scene='channel', draft='Waiting for the conversion to finish.',
                       patch={'conversionJob': CONVERSION}),
    'archived': dict(scene='channel', draft='#launch', extraChannels=[ARCHIVED]),
}

scenes = {'channel': CHANNEL_SCENE, 'dm-agent': DM_SCENE}
states = {}
route_sets = {}
for key, s in STATES.items():
    scene = scenes[s['scene']]
    routes = copy.deepcopy(scene['routes'])
    if s.get('receipt'):
        routes['POST /v2/messages'] = s['receipt']
    states[key] = {'selected': scene['selected'], 'draft': s['draft'], 'routes': routes,
                   'patch': s.get('patch') or {}, 'extraChannels': s.get('extraChannels') or []}
    route_sets[f'cs-{key}'] = routes

fixture = {
    'name': 'raft-flutter parity extension: composer states',
    'scope': 'Public deterministic test data; no credentials. Sidebar/rail data = fixtures/shell.json preset default; '
             'messages = fixtures/screens.json scenes.',
    'sourceCommit': screens['sourceCommit'],
    'states': states,
    'routes': screens['routes'],
    'routeSets': route_sets,
}

cases = []


def add(surface, platform, state, title, *, interactions, android, height, first_note=None):
    viewport = DESKTOP if platform == 'desktop' else MOBILE
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{surface}.{platform}.{state}.{suffix}'
        c = {
            'id': cid,
            'title': f'{title} {platform} ({theme})',
            'captureType': 'component-fixture',
            'surface': f'composer-states-{surface}',
            'category': 'extension/composer-states',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': {
                'extCase': f'{surface}.{platform}.{state}', 'extKind': 'composer-states',
                'extFixture': 'composer-states', 'parityTheme': theme, 'platform': platform,
                'state': state, 'routeSet': f'cs-{state}', 'windowHeight': height}}],
            'capture': {'selector': '[data-testid="composer-window"]', 'crop': 'element',
                        'contract': 'component-bounds', 'interactions': interactions,
                        'androidInteractions': android, 'androidKey': 'composer-window'},
            'reactPathHint': 'packages/web/src/components/message/MessageInput.tsx',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_composer_states.dart '{surface}.{platform}.{state}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        cases.append(c)


EDITOR = 'composer-editor-slot'
WAIT = {'type': 'wait', 'ms': 400}


def type_and_send(draft, platform):
    web = [{'type': 'click', 'target': 'textarea'}, {'type': 'fill', 'target': 'textarea', 'value': draft},
           {'type': 'press', 'target': 'textarea', 'key': 'Enter'}, WAIT]
    # A phone keyboard's Enter is a newline in Flutter (Web's `(pointer: coarse)` branch), so the phone
    # cases tap Send there; the Web side of both platforms presses Enter.
    submit = ({'type': 'tap', 'key': 'composer-submit', 'scroll': False} if platform == 'mobile'
              else {'type': 'key', 'key': 'enter'})
    flutter = [{'type': 'tap', 'key': EDITOR, 'scroll': False}, {'type': 'enterText', 'key': EDITOR, 'text': draft},
               submit, WAIT]
    return web, flutter


def type_only(draft):
    return ([{'type': 'click', 'target': 'textarea'}, {'type': 'fill', 'target': 'textarea', 'value': draft}, WAIT],
            [{'type': 'tap', 'key': EDITOR, 'scroll': False}, {'type': 'enterText', 'key': EDITOR, 'text': draft}, WAIT])


def send_case(surface, platform, state, title, height):
    web, flutter = type_and_send(STATES[state]['draft'], platform)
    add(surface, platform, state, title, interactions=web, android=flutter, height=height)


for platform in ('desktop', 'mobile'):
    # 3.21 "As task": a draft with the checkbox on.
    web, flutter = type_only(ASTASK_DRAFT)
    add('as-task', platform, 'as-task', 'Composer As task checked', height=200,
        interactions=web + [{'type': 'click', 'target': '[data-testid="composer-as-task-toggle"]'}],
        android=flutter + [{'type': 'tap', 'key': 'composer-as-task-toggle', 'scroll': False}])
    # 3.22 pending-mention strip: one agent, then two (Add all footer).
    send_case('pending-mention', platform, 'single', 'Pending-mention strip, one agent', 270)
    send_case('pending-mention', platform, 'multi', 'Pending-mention strip, two agents (Add all)', 340)
    # 3.24 composer warnings.
    send_case('warning', platform, 'agent-stopped', 'Agent stopped delivery warning (DM)', 240)
    send_case('warning', platform, 'unresolved', 'Unresolved mentions warning', 250)
    web, flutter = type_only(STATES['conversion']['draft'])
    add('warning', platform, 'conversion', 'Channel conversion in progress (Send disabled)', height=200,
        interactions=web, android=flutter)
# 3.24 archived badge in the #channel popover (desktop; the phone popover is the same list).
web, flutter = type_only(STATES['archived']['draft'])
add('suggestions', 'desktop', 'archived', '#channel suggestions with an archived channel', height=340,
    interactions=web, android=flutter)
add('suggestions', 'mobile', 'archived', '#channel suggestions with an archived channel', height=340,
    interactions=web, android=flutter)

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/composer-states.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} composer-state cases appended -> the run-time manifest ($PARITY_EXT_MANIFEST); '
      'fixture -> tool/parity-ext/fixtures/composer-states.json')
