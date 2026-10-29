#!/usr/bin/env python3
"""Append the MISSING auth / onboarding / entry page cases to the run-time manifest
($PARITY_EXT_MANIFEST) and write tool/parity-ext/fixtures/auth-pages.json.

Page inventory rows (page inventory, tool/parity-ext/inventory.py): 1.01 1.05 1.06 1.10 1.12 1.14 1.16 1.17 1.18 1.33 ... and
the Settings rows 9.03 9.09 9.10 9.12 9.15 9.23 (added by the second half of this file).
Idempotent: every `components.auth-pages.*` case is replaced, all other cases are kept.

Derivation (raft-source packages/web/src):
  components/auth/RegisterPage.tsx, LegalAcceptanceCheckbox.tsx, InviteAcceptPage.tsx, authErrors.ts
  App.tsx AuthBootstrapStatus / ServerSelectionPage / ServerAccessDeniedPage
  components/errors/RootErrorFallback.tsx, components/server/CommunityAgreementDialog.tsx

Ids (append-only, never rename): components.auth-pages.<platform>.<surface>.<theme>
with platform desktop (1280x800 @1) or mobile (390x844 @3) and three themes (the runner samples the
elegant ones). The FIRST surface of a platform is the default variant of the sampled themes.

React (host/AuthPagesCases.tsx) mounts the real page over primed auth/server stores; API answers come from
fixtures/auth-pages.json (`routes`, per-case `routeSets`; props.extFixture pins this fixture), which the Flutter
builders (cases/ext_auth_pages.dart) read too.
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
PLATFORMS = {'desktop': DESKTOP, 'mobile': MOBILE}
PREFIX = 'components.auth-pages.'
EMAIL = 'artin@raft.build'

# The signed-in / signed-out user and the server lists are the auth-ext fixture's (identical data on both sides).
AUTH_EXT = json.loads((here / 'fixtures' / 'auth-ext.json').read_text())

AGREEMENT = {
    'id': 'agreement-1', 'title': 'Community agreement', 'version': 3,
    'bodyMarkdown': ('Welcome to the Raft community. Please read these rules before you join.\n\n'
                     '1. Be kind and assume good intent.\n2. No spam or unsolicited advertising.\n'
                     '3. Keep conversations in the right channel.\n4. Do not share private information.\n\n'
                     'Moderators may remove content or members that break these rules.'),
}


def invite(kind='email', **extra):
    return {'kind': kind, 'serverName': 'Raft Design', 'inviterName': 'Wenyi' if kind == 'email' else None,
            'memberCount': 12, 'agentCount': 5, 'insideCountsHidden': False, 'humanSeatLimitReached': False,
            'humanSeatLimitMessage': None, 'agreement': None, **extra}


GATE = {'phase': 'in_progress', 'surface': 'computer_runtime', 'currentStep': 'computer_runtime',
        'blocksChat': True, 'allowedExits': [], 'gateReason': None,
        'sideEffectState': {'transitions': 'enabled', 'completion': 'enabled'}}

BASE = {
    'GET /auth/providers': {'providers': []},
    'GET /servers/srv-1/machines': {'machines': []},
    'POST /auth/register': {'user': AUTH_EXT['user'], 'accessToken': 'x', 'refreshToken': 'y'},
    'GET /auth/invite-info': invite(),
}

FIXTURE = {
    'description': 'Missing auth / onboarding / entry pages: stores, API answers and per-case route sets shared by '
                   'host/AuthPagesCases.tsx and cases/ext_auth_pages.dart.',
    'user': AUTH_EXT['user'],
    'providers': AUTH_EXT['providers'],
    'servers': AUTH_EXT['servers'],
    'agreement': AGREEMENT,
    'rootError': {
        'message': "Cannot read properties of undefined (reading 'name')",
        'stack': "TypeError: Cannot read properties of undefined (reading 'name')\n    at ChannelHeader (app.js:1:1)",
        'componentStack': '\n    at ChannelHeader (app.js:1:1)\n    at MainLayout (app.js:1:1)\n    at App (app.js:1:1)',
    },
    # props.patch -> server record fields (settings cases; host and Flutter read the same).
    'serverPatches': {
        'downgrade-active': {'planDowngradedAt': '2026-06-17T12:30:00.000Z'},
        'downgrade-expired': {'planDowngradedAt': '2026-05-30T12:30:00.000Z'},
    },
    # props.patch 'archived': channels added to the channel list (Web host only; Flutter has no such section).
    'archivedChannels': [
        {'id': 'arch-1', 'name': 'launch-retro', 'type': 'channel', 'archivedAt': '2026-06-10T09:00:00.000Z'},
        {'id': 'arch-2', 'name': 'design-private', 'type': 'private', 'archivedAt': '2026-06-02T15:30:00.000Z'},
        {'id': 'arch-3', 'name': 'partner-sync', 'type': 'joint', 'archivedAt': '2026-05-21T11:15:00.000Z'},
    ],
    # No global `routes`: every extension fixture's `routes` answer ALL unpinned cases, so each case names a
    # route set (default 'base') that carries the full answer table.
    'routes': {},
    'routeSets': {
        'ap-social': {'GET /auth/providers': AUTH_EXT['providers']},
        'ap-register-error': {'POST /auth/register': {'$status': 409, '$body': {
            'error': 'An account with this email already exists'}}},
        'ap-invite-join-link': {'GET /auth/invite-info': invite('join_link')},
        'ap-invite-agreement': {'GET /auth/invite-info': invite(agreement=AGREEMENT)},
        'ap-invite-seat-limit': {'GET /auth/invite-info': invite(humanSeatLimitReached=True)},
        'ap-invite-hidden-counts': {'GET /auth/invite-info': invite(insideCountsHidden=True)},
        'ap-invite-expired': {'GET /auth/invite-info': {'$status': 404, '$body': {'error': 'Not found'}}},
        'ap-invite-throttled': {'GET /auth/invite-info': {'$status': 429, '$body': {'error': 'Too many requests'}}},
        'ap-invite-loading': {'GET /auth/invite-info': {'$pending': True}},
        'ap-gate-loading': {'GET /servers/srv-1/setup-projection': {'$pending': True}},
        'ap-gate-failed': {'GET /servers/srv-1/setup-projection': {'$status': 500, '$body': {'error': 'Internal Server Error'}}},
        'ap-gate-unavailable': {'GET /servers/srv-1/setup-projection': {**GATE, 'phase': None, 'surface': 'none',
                                                                     'currentStep': None, 'blocksChat': False,
                                                                     'gateReason': 'insufficient_permission'}},
        'ap-gate-complete': {'GET /servers/srv-1/setup-projection': {**GATE, 'phase': 'complete', 'surface': 'complete',
                                                                  'currentStep': None, 'blocksChat': False,
                                                                  'postSetup': {'surveyPending': False,
                                                                                'handoffPending': False}}},
        'ap-gate-resume': {'GET /servers/srv-1/setup-projection': {**GATE, 'phase': 'deferred', 'blocksChat': False}},
        'ap-invite-accept-error': {'POST /auth/accept-invite': {'$status': 400, '$body': {
            'error': 'This invite has already been used.'}}},
    },
}


FIXTURE['routeSets'] = {name: {**BASE, **rules} for name, rules in FIXTURE['routeSets'].items()}
FIXTURE['routeSets']['ap-base'] = dict(BASE)
# Settings cases: only the endpoints the page itself asks for beyond the settings fixture (set per case).
FIXTURE['routeSets']['ap-password'] = {'GET /auth/identities': {'identities': [], 'passwordConfigured': True}}


def fill(sel, value):
    return {'type': 'fill', 'target': sel, 'value': value}


def click(sel):
    return {'type': 'click', 'target': sel}


def wait(ms=150):
    return {'type': 'wait', 'ms': ms}


def tap(key):
    return {'type': 'tap', 'key': key}


def enter(key, value):
    return {'type': 'enter', 'key': key, 'value': value}


SUBMIT = 'form button[type="submit"]'
LEGAL = 'form [role="checkbox"]'
REG_FILL = [fill('#register-email', EMAIL), fill('#register-password', 'correct horse battery')]
REG_FILL_ANDROID = [enter('login-email', EMAIL), enter('login-password', 'correct horse battery')]

# name -> dict(view, title, platforms, routeSet, servers, user, kind, web, android, selector, key)
SURFACES = [
    # ---- 1.05 / 1.06 register ------------------------------------------
    dict(name='register.default', view='register', title='Register'),
    dict(name='register.filled', view='register', title='Register filled, terms accepted',
         web=[*REG_FILL, click(LEGAL), wait()], android=[*REG_FILL_ANDROID, tap('register-legal')]),
    dict(name='register.unchecked', view='register', title='Register filled, terms unchecked (submit disabled)',
         web=[*REG_FILL, wait()], android=REG_FILL_ANDROID),
    dict(name='register.invalid-email', view='register', title='Register invalid email',
         web=[fill('#register-email', 'not-an-email'), fill('#register-password', 'correct horse battery'),
              click(LEGAL), click(SUBMIT), wait()],
         android=[enter('login-email', 'not-an-email'), enter('login-password', 'correct horse battery'),
                  tap('register-legal'), tap('login-submit')]),
    dict(name='register.short-password', view='register', title='Register password too short',
         web=[fill('#register-email', EMAIL), fill('#register-password', 'short'), click(LEGAL), click(SUBMIT), wait()],
         android=[enter('login-email', EMAIL), enter('login-password', 'short'), tap('register-legal'),
                  tap('login-submit')]),
    dict(name='register.error', view='register', title='Register submit error', routeSet='ap-register-error',
         web=[*REG_FILL, click(LEGAL), click(SUBMIT), wait(250)],
         android=[*REG_FILL_ANDROID, tap('register-legal'), tap('login-submit')]),
    dict(name='register.social', view='register', title='Register with social providers', routeSet='ap-social',
         web=[wait(200)], android=[]),
    # ---- 1.01 / 1.17 undecided / loading splashes ------------------------
    dict(name='bootstrap.restoring', view='bootstrap', kind='restoring', title='Restoring session'),
    dict(name='bootstrap.loading', view='bootstrap', kind='loading', title='Auth bootstrap loading'),
    dict(name='servers.loading', view='servers-loading', user='verified', title='Loading servers'),
    dict(name='servers.joining-community', view='joining-community', user='verified',
         title='Joining community splash'),
    # ---- 1.16 server access denied ----------------------------------------
    dict(name='server-denied.with-server', view='access-denied', user='verified', servers='two',
         title='Server not found, fallback server'),
    dict(name='server-denied.no-server', view='access-denied', user='verified', servers='none',
         title='Server not found, no server'),
    # ---- 1.12 invite accept -------------------------------------------------
    dict(name='invite.signed-out', view='invite', title='Invite accept, signed out',
         web=[wait(250)], android=[]),
    dict(name='invite.signed-in', view='invite', user='verified', title='Invite accept, signed in',
         web=[wait(250)], android=[]),
    dict(name='invite.join-link', view='invite', user='verified', routeSet='ap-invite-join-link',
         title='Invite accept, join link', web=[wait(250)], android=[]),
    dict(name='invite.agreement', view='invite', user='verified', routeSet='ap-invite-agreement',
         title='Invite accept with agreement', web=[wait(250)], android=[]),
    dict(name='invite.hidden-counts', view='invite', user='verified', routeSet='ap-invite-hidden-counts',
         title='Invite accept, counts hidden', web=[wait(250)], android=[]),
    dict(name='invite.seat-limit', view='invite', user='verified', routeSet='ap-invite-seat-limit',
         title='Invite accept, no human seat', web=[wait(250)], android=[]),
    dict(name='invite.expired', view='invite', user='verified', routeSet='ap-invite-expired',
         title='Invite expired or invalid', web=[wait(250)], android=[]),
    dict(name='invite.throttled', view='invite', user='verified', routeSet='ap-invite-throttled',
         title='Invite lookup throttled', web=[wait(250)], android=[]),
    dict(name='invite.loading', view='invite', routeSet='ap-invite-loading', title='Invite loading',
         web=[wait(250)], android=[]),
    dict(name='invite.accept-error', view='invite', user='verified', routeSet='ap-invite-accept-error',
         title='Invite accept failed',
         web=[wait(250), click('button:has-text("Join Server")'), wait(250)], android=[]),
    # ---- 1.18 community agreement dialog ------------------------------------
    dict(name='community-agreement.default', view='community-agreement', user='verified',
         title='Community agreement dialog', selector='body', crop='viewport'),
    dict(name='community-agreement.error', view='community-agreement', user='verified', kind='error',
         title='Community agreement changed', selector='body', crop='viewport',
         web=[click('button:has-text("Agree & Continue")'), wait(250)], android=[]),
    dict(name='community-agreement.joining', view='community-agreement', user='verified', kind='pending',
         title='Community agreement joining', selector='body', crop='viewport',
         web=[click('button:has-text("Agree & Continue")'), wait(250)], android=[]),
    # ---- 1.10 account identity (profile) setup ---------------------------------
    dict(name='identity.default', view='identity', title='Account identity setup', web=[wait(600)], android=[]),
    dict(name='identity.filled', view='identity', title='Account identity setup, filled',
         web=[fill("input[name='username']", 'new_designer'), fill("input[name='name']", 'New Designer'), wait(600)],
         android=[enter('onboarding-username', 'new_designer'), enter('onboarding-display-name', 'New Designer')]),
    # ---- 1.14 create first server (desktop; the phone cases are components.auth-ext.mobile.server.create-first*)
    dict(name='server.create-first', view='server-selector', user='verified', servers='none',
         title='Create first server', platforms=['desktop'], web=[wait(600)], android=[]),
    dict(name='server.create-first-filled', view='server-selector', user='verified', servers='none',
         title='Create first server filled', platforms=['desktop'],
         web=[fill('#server-create-name', "Cindy's pricing team"), wait(600)],
         android=[enter('global-server-name', "Cindy's pricing team")]),
    # ---- 1.24 server setup projection gate (Flutter renders the steps in-app, none of these pages) -----------
    dict(name='setup-gate.resume-bar', view='setup-gate', kind='resume', user='verified', servers='two',
         routeSet='ap-gate-resume', title='Setup deferred, resume bar', crop='viewport', selector='body',
         web=[wait(400)], android=[]),
    dict(name='setup-gate.loading', view='setup-gate', kind='dedicated', user='verified', servers='two',
         routeSet='ap-gate-loading', title='Setup gate loading (dedicated surface)', web=[wait(300)], android=[]),
    dict(name='setup-gate.unavailable', view='setup-gate', kind='dedicated', user='verified', servers='two',
         routeSet='ap-gate-unavailable', title='Setup gate unavailable (dedicated surface)', web=[wait(400)],
         android=[]),
    dict(name='setup-gate.load-failed', view='setup-gate', kind='dedicated', user='verified', servers='two',
         routeSet='ap-gate-failed', title='Setup gate load failed (dedicated surface)', web=[wait(400)], android=[]),
    dict(name='setup-gate.complete', view='setup-gate', kind='complete', user='verified', servers='two',
         routeSet='ap-gate-complete', title='Setup gate complete (dedicated surface)', web=[wait(400)], android=[]),
    # ---- Settings rows 9.03 / 9.09 / 9.10 / 9.12 / 9.15 / 9.23 (same host + Flutter page as ext-settings) --------
    dict(name='settings.account-password', view='settings', tab='account', pin=False, routeSet='ap-password', region='panel',
         title='Account: change password expanded', tall=True,
         web=[wait(800), click('role=button[name="Change Password"s]'), wait(300)],
         android=[tap('account-change-password')]),
    dict(name='settings.account-password-error', view='settings', tab='account', pin=False, routeSet='ap-password', region='panel',
         title='Account: change password, passwords differ', tall=True,
         web=[wait(800), click('role=button[name="Change Password"s]'),
              fill('input[name="current-password"]', 'old-password'),
              fill('input[name="new-password"]', 'correct horse battery'),
              fill('input[name="confirm-password"]', 'different horse battery'),
              click('form:has(input[name="current-password"]) button[type="submit"]'), wait(300)],
         android=[tap('account-change-password'), enter('account-current-password', 'old-password'),
                  enter('account-new-password', 'correct horse battery'),
                  enter('account-confirm-password', 'different horse battery'), tap('account-password-submit')]),
    dict(name='settings.account-logout-confirm', view='settings', tab='account', pin=False,
         title='Account: log out confirm', selector='[data-slot="dialog-content"]', key='account-logout-dialog',
         web=[wait(800), click('[data-testid="account-logout"]'), wait(300)], android=[tap('account-logout')]),
    dict(name='settings.server-danger-delete', view='settings', tab='server', pin=False, platforms=['desktop'],
         title='Server: delete confirm', selector='[data-slot="dialog-content"]', key='server-danger-dialog',
         web=[wait(800), click('[data-testid="server-danger-delete-button"]'), wait(300)],
         android=[tap('server-danger-delete-button')]),
    dict(name='settings.server-danger-delete-typed', view='settings', tab='server', pin=False, platforms=['desktop'],
         title='Server: delete confirm, slug typed', selector='[data-slot="dialog-content"]',
         key='server-danger-dialog',
         web=[wait(800), click('[data-testid="server-danger-delete-button"]'),
              fill('[data-slot="dialog-content"] input', 'visual'), wait(300)],
         android=[tap('server-danger-delete-button'), enter('server-delete-slug-input', 'visual')]),
    dict(name='settings.server-danger-member', view='settings', tab='server', role='member', pin=False,
         platforms=['desktop'], region='panel', title='Server: leave card (member)', web=[wait(800)], android=[]),
    dict(name='settings.server-danger-leave', view='settings', tab='server', role='member', pin=False,
         platforms=['desktop'], title='Server: leave confirm', selector='[data-slot="dialog-content"]',
         key='server-danger-dialog',
         web=[wait(800), click('[data-testid="server-danger-leave-button"]'), wait(300)],
         android=[tap('server-danger-leave-button')]),
    dict(name='settings.archived-channels', view='settings', tab='server', patch='archived', pin=False,
         region='panel', title='Server: archived channels list', web=[wait(900)], android=[]),
    dict(name='settings.downgrade-active', view='settings', tab='billing', patch='downgrade-active', pin=False,
         region='panel', title='Billing: downgrade warning, grace period', tall=True, web=[wait(900)], android=[]),
    dict(name='settings.downgrade-expired', view='settings', tab='billing', patch='downgrade-expired', pin=False,
         region='panel', title='Billing: downgrade warning, grace expired', tall=True, web=[wait(900)], android=[]),
    dict(name='settings.app-editor', view='settings', tab='integrations', pin=False, crop='viewport', selector='body',
         dialog_viewport=True, title='Applications: register app editor',
         web=[wait(900), click('role=button[name="Register app"s]'), wait(400)],
         android=[tap('connected-apps-register')]),
    dict(name='settings.release-notes', view='settings', tab='release-notes', pin=False, platforms=['mobile'],
         title='Release notes (phone)', web=[wait(900)], android=[]),
    dict(name='settings.release-notes-loading', view='settings', tab='release-notes', pin=False,
         platforms=['mobile'], routeSet='release-notes-loading', title='Release notes loading (phone)',
         web=[wait(900)], android=[]),
    dict(name='settings.release-notes-error', view='settings', tab='release-notes', pin=False,
         platforms=['mobile'], routeSet='release-notes-error', title='Release notes error (phone)',
         web=[wait(900)], android=[]),
    dict(name='settings.release-notes-empty', view='settings', tab='release-notes', pin=False,
         platforms=['mobile'], routeSet='release-notes-empty', title='Release notes empty (phone)',
         web=[wait(900)], android=[]),
    # ---- 1.33 root error fallback ---------------------------------------------
    dict(name='root-error.default', view='root-error', title='Root error fallback'),
]


PANEL = "[data-parity-region='settings-panel']"
SETTINGS_FRAME = {'desktop': {'width': 1280, 'height': 800, 'density': 1},
                  'mobile': {'width': 390, 'height': 844, 'density': 3}}
SETTINGS_TALL = {'desktop': {'width': 1280, 'height': 1600, 'density': 1},
                 'mobile': {'width': 390, 'height': 1700, 'density': 3}}
SETTINGS_DIALOG = {'desktop': {'width': 1216, 'height': 800, 'density': 1},
                   'mobile': {'width': 390, 'height': 844, 'density': 3}}


def make_cases():
    cases = []
    for s in SURFACES:
        for platform, viewport in PLATFORMS.items():
            if platform not in s.get('platforms', PLATFORMS):
                continue
            if s['view'] == 'settings':
                viewport = (SETTINGS_DIALOG if s.get('dialog_viewport')
                            else SETTINGS_TALL if s.get('tall') else SETTINGS_FRAME)[platform]
            for suffix, theme in THEMES.items():
                cid = f'{PREFIX}{platform}.{s["name"]}.{suffix}'
                props = {'extCase': f'{platform}.{s["name"]}', 'extKind': 'auth-pages',
                         'parityTheme': theme, 'platform': platform, 'view': s['view'], 'name': s['name'],
                         'w': viewport['width'], 'h': viewport['height']}
                if s.get('pin', True):
                    props['extFixture'] = 'auth-pages'
                for key in ('routeSet', 'servers', 'user', 'kind', 'tab', 'role', 'flags', 'patch'):
                    if s.get(key):
                        props[key] = s[key]
                if 'routeSet' not in props and s['view'] != 'settings':
                    props['routeSet'] = 'ap-base'
                selector, key = s.get('selector'), s.get('key')
                if s.get('region') == 'panel' and platform == 'desktop':
                    selector, key = PANEL, 'settings-panel'
                viewport_crop = s.get('crop') == 'viewport'
                crop = bool(selector) and not viewport_crop
                capture = {
                    'selector': selector or f"[data-visual-case='{cid}']",
                    'crop': 'viewport' if viewport_crop else 'element',
                    'contract': ('viewport-with-portal' if viewport_crop
                                 else 'component-bounds' if crop else 'screen-route'),
                    'interactions': s.get('web', []),
                    'androidInteractions': s.get('android', []),
                }
                if crop and key:
                    capture['androidKey'] = key
                cases.append({
                    'id': cid,
                    'title': f'{s["title"]} {platform} ({theme})',
                    'captureType': 'component-fixture' if (crop or viewport_crop) else 'real-screen',
                    'surface': 'auth-pages',
                    'category': 'extension/auth-pages',
                    'suite': 'raft-flutter-extension',
                    'viewport': viewport,
                    'theme': theme,
                    'locale': 'en',
                    'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                    'capture': capture,
                    'reactPathHint': ('packages/web/src/components/settings/ (SettingsPanel.tsx, ReleaseNotesPanel.tsx)'
                                      if s['view'] == 'settings' else
                                      'packages/web/src/components/auth/, App.tsx, components/errors/, '
                                      'components/server/, components/onboarding/'),
                    'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_auth_pages.dart '{platform}.{s['name']}'",
                    'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
                })
    return cases


cases = make_cases()
path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures' / 'auth-pages.json').write_text(json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} auth-pages cases appended ({len(manifest["cases"])} total)')
