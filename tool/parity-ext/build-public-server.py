#!/usr/bin/env python3
"""Append the Public server page cases (page inventory rows 1.19 / 1.20) to the run-time manifest
($PARITY_EXT_MANIFEST) and write tool/parity-ext/fixtures/public-server.json.

Idempotent: every `components.public-server.*` case is replaced, all other cases are kept.

Derivation (raft-source packages/web/src): pages/PublicServerPage.tsx (anonymous `/s/<slug>` preview and the
signed-in nonmember variant with the Join as Guest confirm), components/layout/LeftRail.tsx publicProjection,
components/server/CommunityAgreementDialog.tsx, components/ConfirmDialog.tsx.

Ids (append-only, never rename): components.public-server.<platform>.<surface>.<theme> with platform desktop
(1280x800 @1) or mobile (390x844 @3) and three themes (the runner samples the elegant ones). The FIRST
surface of a platform is the default variant of the sampled themes.

React (host/PublicServerCases.tsx) mounts the real page; API answers come from fixtures/public-server.json
(`routeSets[props.routeSet]`, props.extFixture pins this fixture), which the Flutter builders
(cases/ext_public_server.dart) read too.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)

THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
PLATFORMS = {'desktop': {'width': 1280, 'height': 800, 'density': 1},
             'mobile': {'width': 390, 'height': 844, 'density': 3}}
PREFIX = 'components.public-server.'
SLUG = 'raft-design'

AUTH_EXT = json.loads((here / 'fixtures' / 'auth-ext.json').read_text())


def sender(name, description=None):
    return {'displayName': name, 'avatarUrl': None, 'description': description}


def message(mid, who, content, at, kind='user', thread=None, replies=0, desc=None):
    return {'id': mid, 'senderType': kind, 'sender': sender(who, desc), 'messageType': 'chat',
            'content': content, 'createdAt': at, 'threadId': thread, 'replyCount': replies}


GENERAL = [
    message('m1', 'Wenyi', 'Welcome to the Raft design community. Read the pinned guide before posting.',
            '2026-06-18T09:12:00.000Z'),
    message('m2', 'Artin', 'We ship a new **design token** release every Friday. Notes live in #release-notes.',
            '2026-06-18T09:20:00.000Z'),
    message('m3', 'Layout Bot', 'Reminder: crit session starts at 15:00 UTC in #design-crit.',
            '2026-06-18T09:41:00.000Z', kind='agent', desc='Schedules and summaries'),
    message('m4', 'Wenyi', 'Does anyone have feedback on the new settings rail?', '2026-06-18T10:02:00.000Z',
            thread='thread-1', replies=3),
    message('m5', 'Jun', 'Love the denser spacing. The `Applications` editor is much easier to scan now.',
            '2026-06-18T10:15:00.000Z'),
]
THREAD = [
    message('t1', 'Artin', 'Thanks! Which part felt too tight?', '2026-06-18T10:05:00.000Z'),
    message('t2', 'Jun', 'Only the rail on phones, everything else is great.', '2026-06-18T10:08:00.000Z'),
    message('t3', 'Wenyi', 'Noted, we will adjust it in the next pass.', '2026-06-18T10:11:00.000Z'),
]
CHANNELS = [
    {'id': 'pub-general', 'name': 'general', 'description': 'Announcements and community news'},
    {'id': 'pub-crit', 'name': 'design-crit', 'description': 'Share work in progress for feedback'},
    {'id': 'pub-help', 'name': 'help', 'description': None},
]
SERVER = {'id': 'srv-public', 'name': 'Raft Design', 'slug': SLUG, 'avatarUrl': None}
AGREEMENT = {
    'id': 'agreement-1', 'title': 'Community agreement', 'version': 3,
    'bodyMarkdown': ('Welcome to the Raft community. Please read these rules before you join.\n\n'
                     '1. Be kind and assume good intent.\n2. No spam or unsolicited advertising.\n'
                     '3. Keep conversations in the right channel.'),
}
BASE_PATH = f'/public/servers/{SLUG}'


def readback(joinable=True, channels=CHANNELS):
    return {'server': SERVER, 'channels': channels, 'canJoinAsGuest': joinable}


def base_routes(joinable=True, channels=CHANNELS):
    routes = {
        f'GET {BASE_PATH}': readback(joinable, channels),
        f'POST {BASE_PATH}/join-as-guest': {'ok': True},
        f'GET {BASE_PATH}/threads/thread-1/messages': {'messages': THREAD},
    }
    for channel in CHANNELS:
        routes[f'GET {BASE_PATH}/channels/{channel["id"]}/messages'] = {
            'messages': GENERAL if channel['id'] == 'pub-general' else []}
    return routes


ROUTE_SETS = {
    'ps-joinable': base_routes(),
    'ps-viewonly': base_routes(joinable=False),
    'ps-empty-channels': base_routes(channels=[]),
    'ps-empty-messages': {**base_routes(), f'GET {BASE_PATH}/channels/pub-general/messages': {'messages': []}},
    'ps-loading': {**base_routes(), f'GET {BASE_PATH}': {'$pending': True}},
    'ps-messages-error': {**base_routes(), f'GET {BASE_PATH}/channels/pub-general/messages': {
        '$status': 500, '$body': {'error': 'Failed to load public messages'}}},
    'ps-join-error': {**base_routes(), f'POST {BASE_PATH}/join-as-guest': {
        '$status': 500, '$body': {'error': 'Failed to join this public server'}}},
    'ps-join-agreement': {**base_routes(), f'POST {BASE_PATH}/join-as-guest': {
        '$status': 409, '$body': {'error': 'agreement_required', 'agreement': AGREEMENT}}},
}

FIXTURE = {
    'description': 'Public server page (signed-out preview and signed-in nonmember): API answers per case route '
                   'set, shared by host/PublicServerCases.tsx and cases/ext_public_server.dart.',
    'slug': SLUG,
    'user': AUTH_EXT['user'],
    'servers': AUTH_EXT['servers'],
    'server': SERVER,
    'agreement': AGREEMENT,
    'routes': {},
    'routeSets': ROUTE_SETS,
}


def click(sel):
    return {'type': 'click', 'target': sel}


def wait(ms=300):
    return {'type': 'wait', 'ms': ms}


def tap(key):
    return {'type': 'tap', 'key': key}


THREAD_BADGE = '[data-testid="message-thread-replies-badge"]'
JOIN = '[data-testid="public-server-join-guest"]'
JOIN_CONFIRM = '[data-slot="dialog-content"] button:has-text("Join as Guest")'

# name -> dict(title, routeSet, authenticated, platforms, web, android, error)
SURFACES = [
    dict(name='page.default', title='Public server, signed out (joinable)', routeSet='ps-joinable',
         web=[wait(700)], android=[]),
    dict(name='page.view-only', title='Public server, signed out (view only)', routeSet='ps-viewonly',
         web=[wait(700)], android=[]),
    dict(name='page.empty-channels', title='Public server without public channels',
         routeSet='ps-empty-channels', web=[wait(700)], android=[]),
    dict(name='page.empty-messages', title='Public channel without messages', routeSet='ps-empty-messages',
         web=[wait(700)], android=[]),
    dict(name='page.loading', title='Public server loading', routeSet='ps-loading', web=[wait(500)], android=[]),
    dict(name='page.messages-error', title='Public channel messages failed', routeSet='ps-messages-error',
         web=[wait(700)], android=[]),
    dict(name='page.thread', title='Public thread open (read only)', routeSet='ps-joinable',
         web=[wait(700), click(THREAD_BADGE), wait(500)], android=[tap('public-thread-open-m4')]),
    dict(name='page.settings-about', title='Public server settings: About', routeSet='ps-joinable',
         platforms=['desktop'], web=[wait(700), click('[data-testid="left-rail-settings"]'), wait(500)],
         android=[tap('public-rail-settings')]),
    dict(name='page.settings-account', title='Public server settings: Account (signed in nonmember)',
         routeSet='ps-joinable', authenticated=True, platforms=['desktop'],
         web=[wait(700), click('[data-testid="left-rail-settings"]'), wait(800)],
         android=[tap('public-rail-settings')]),
    dict(name='page.join-ready', title='Public server, signed in nonmember', routeSet='ps-joinable',
         authenticated=True, web=[wait(700)], android=[]),
    dict(name='page.join-confirm', title='Join as Guest confirm', routeSet='ps-joinable', authenticated=True,
         web=[wait(700), click(JOIN), wait(500)], android=[tap('public-join-guest')]),
    dict(name='page.join-error', title='Join as Guest failed', routeSet='ps-join-error', authenticated=True,
         web=[wait(700), click(JOIN), wait(300), click(JOIN_CONFIRM), wait(600)],
         android=[tap('public-join-guest'), tap('public-join-confirm')]),
    dict(name='page.join-agreement', title='Join as Guest: community agreement', routeSet='ps-join-agreement',
         authenticated=True, web=[wait(700), click(JOIN), wait(300), click(JOIN_CONFIRM), wait(600)],
         android=[tap('public-join-guest'), tap('public-join-confirm')]),
]


def make_cases():
    cases = []
    for s in SURFACES:
        for platform, viewport in PLATFORMS.items():
            if platform not in s.get('platforms', PLATFORMS):
                continue
            for suffix, theme in THEMES.items():
                cid = f'{PREFIX}{platform}.{s["name"]}.{suffix}'
                props = {'extCase': f'{platform}.{s["name"]}', 'extKind': 'public-server', 'extFixture': 'public-server',
                         'parityTheme': theme, 'platform': platform, 'name': s['name'], 'routeSet': s['routeSet'],
                         'w': viewport['width'], 'h': viewport['height']}
                if s.get('authenticated'):
                    props['authenticated'] = 'true'
                cases.append({
                    'id': cid,
                    'title': f'{s["title"]} {platform} ({theme})',
                    'captureType': 'real-screen',
                    'surface': 'public-server',
                    'category': 'extension/public-server',
                    'suite': 'raft-flutter-extension',
                    'viewport': viewport,
                    'theme': theme,
                    'locale': 'en',
                    'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                    'capture': {
                        'selector': f"[data-visual-case='{cid}']",
                        'crop': 'element',
                        'contract': 'screen-route',
                        'interactions': s.get('web', []),
                        'androidInteractions': s.get('android', []),
                    },
                    'reactPathHint': 'packages/web/src/pages/PublicServerPage.tsx, components/layout/LeftRail.tsx',
                    'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_public_server.dart '{platform}.{s['name']}'",
                    'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
                })
    return cases


cases = make_cases()
path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures' / 'public-server.json').write_text(json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} public-server cases appended ({len(manifest["cases"])} total)')
