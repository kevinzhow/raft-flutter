#!/usr/bin/env python3
"""Append the auth & onboarding extension cases to the run-time manifest
($PARITY_EXT_MANIFEST) and write tool/parity-ext/fixtures/auth-ext.json.

Replaces only its own cases, so it needs no particular slot (build-cases.py creates
the manifest from scratch each run). Idempotent: every `components.auth-ext.*` case is
replaced, all other cases are kept in place (append-only for the others).

Derivation (raft-source packages/web/src):
  components/auth/LoginPage.tsx, SocialProviderButton.tsx, ForgotPasswordPage.tsx,
    ResetPasswordPage.tsx, EmailVerificationPage.tsx, ServerSelector.tsx,
    OnboardingCreateShell.tsx, authErrors.ts
  components/brand/AuthBrandShell.tsx (frame: brand bar + centred max-w-md card)
  components/onboarding/ServerSetup*Step.tsx
  i18n/messages/en.ts pages.login.* pages.forgotPassword.* pages.resetPassword.*
    pages.emailVerification.* pages.serverSelector.* layout.onboarding.*

Ids (append-only, never rename):
  components.auth-ext.<platform>.<surface>.<theme>
with platform desktop (1280x800 @1) or mobile (390x844 @3) and three themes.

React (host/AuthCases.tsx) mounts the real page over primed auth/server
stores; the API answers come from fixtures/auth-ext.json (`routes`, per-case
`routeSets`), which the Flutter builders (cases/ext_auth.dart) read too.
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
PREFIX = 'components.auth-ext.'
EMAIL = 'artin@raft.build'

USER = {
    'id': 'visual-user', 'email': EMAIL, 'gravatarHash': '', 'name': 'artin', 'displayName': 'artin',
    'description': None, 'avatarUrl': None, 'emailVerified': False, 'preferredLanguage': None,
    'displayLanguage': None, 'preferredTimezone': 'UTC', 'autoTranslationEnabled': False,
    'preferredTranslationMode': 'manual', 'preferredTranslationDisplay': 'translated',
    'preferredTimeFormat': '24h', 'preferredMessageBodyFontSize': None, 'referralSource': None,
    'referralSourceOther': None, 'referralSourceSkippedAt': None,
}
PROVIDERS = {'providers': [
    {'id': 'google', 'label': 'Google', 'enabled': True},
    {'id': 'github', 'label': 'GitHub', 'enabled': True},
    {'id': 'apple', 'label': 'Apple', 'enabled': True},
]}


def server(sid, name, slug, role='owner'):
    return {'id': sid, 'name': name, 'avatarUrl': None, 'slug': slug, 'ownerId': 'visual-user',
            'onboardingAgentId': None, 'hideHumansFromMembers': False, 'plan': 'free',
            'planDowngradedAt': None, 'role': role, 'createdAt': '2026-06-20T08:00:00.000Z'}


FIXTURE = {
    'description': 'Auth & onboarding extension cases: stores, API answers and per-case route sets '
                   'shared by host/AuthCases.tsx and cases/ext_auth.dart.',
    'user': USER,
    'providers': PROVIDERS,
    'servers': {
        'none': [],
        'two': [server('srv-1', 'Raft Design', 'raft-design'), server('srv-2', 'Launch Team', 'launch', 'member')],
    },
    'errors': {
        'login': 'Incorrect email or password.',
        'forgot': 'Failed to send reset email',
        'reset': 'Password reset failed. The link may be expired.',
        'verify': 'Verification failed. The link may be expired.',
    },
    'routes': {
        'GET /auth/providers': {'providers': []},
        'POST /auth/login': {'user': USER, 'accessToken': 'x', 'refreshToken': 'y'},
        'POST /auth/forgot-password': {'message': 'ok'},
        'POST /auth/reset-password': {'message': 'ok'},
        'POST /auth/resend-verification': {'message': 'ok'},
        'POST /auth/verify-email': {'message': 'ok'},
        'PATCH /auth/me': {**USER, 'emailVerified': True, 'signupRole': 'design'},
        'POST /servers/visual-server/setup-handoff': {'phase': 'complete', 'surface': 'complete', 'blocksChat': False},
        'GET /auth/me': {**USER, 'emailVerified': True},
    },
    'routeSets': {
        'social': {'GET /auth/providers': PROVIDERS},
        'login-error': {'POST /auth/login': {'$status': 401, '$body': {
            'code': 'AUTH_INVALID_CREDENTIALS', 'error': 'Invalid email or password'}}},
        'forgot-error': {'POST /auth/forgot-password': {'$status': 500, '$body': {
            'error': 'Failed to send reset email'}}},
        'reset-error': {'POST /auth/reset-password': {'$status': 400, '$body': {
            'error': 'Password reset failed. The link may be expired.'}}},
        'verify-error': {'POST /auth/verify-email': {'$status': 400, '$body': {
            'error': 'Verification failed. The link may be expired.'}}},
        'survey-error': {'PATCH /auth/me': {'$status': 500, '$body': {'error': 'Internal Server Error'}}},
        'handoff-pending': {'POST /servers/visual-server/setup-handoff': {'$pending': True}},
        'resend-error': {'POST /auth/resend-verification': {'$status': 429, '$body': {
            'error': 'Too many requests. Try again later.'}}},
    },
}


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

# name -> dict(view, title, routeSet, servers, web, android, selector, key, platforms)
SURFACES = [
    # ---- login --------------------------------------------------------
    dict(name='login.default', view='login', title='Login default'),
    dict(name='login.social', view='login', title='Login with social providers', routeSet='social',
         web=[wait(200)], android=[]),
    dict(name='login.invalid-email', view='login', title='Login invalid email',
         web=[fill('#login-email', 'not-an-email'), fill('#login-password', 'secret-password'),
              click(SUBMIT), wait()],
         android=[enter('login-email', 'not-an-email'), enter('login-password', 'secret-password'),
                  tap('login-submit')]),
    dict(name='login.missing-password', view='login', title='Login missing password',
         web=[fill('#login-email', EMAIL), click(SUBMIT), wait()],
         android=[enter('login-email', EMAIL), tap('login-submit')]),
    dict(name='login.error', view='login', title='Login credentials error', routeSet='login-error',
         web=[fill('#login-email', EMAIL), fill('#login-password', 'wrong-password'), click(SUBMIT), wait(250)],
         android=[enter('login-email', EMAIL), enter('login-password', 'wrong-password'),
                  tap('login-submit')]),
    dict(name='login.filled', view='login', title='Login filled inputs',
         web=[fill('#login-email', EMAIL), fill('#login-password', 'visual-sign-in-secret'), wait()],
         android=[enter('login-email', EMAIL), enter('login-password', 'visual-sign-in-secret')]),
    # social buttons group (space-y-2 list under the "or" divider)
    dict(name='social.buttons', view='login', title='Social sign-in buttons', routeSet='social',
         selector='div.space-y-2:has(> button)', key='auth-social-buttons', web=[wait(200)], android=[]),
    dict(name='social.hover', view='login', title='Social sign-in button hovered', routeSet='social',
         selector='div.space-y-2:has(> button)', key='auth-social-buttons',
         web=[wait(200), {'type': 'hover', 'target': 'div.space-y-2 > button:nth-child(2)'}],
         android=[{'type': 'hover', 'key': 'auth-social-github'}]),
    # ---- forgot password ----------------------------------------------
    dict(name='forgot.default', view='forgot', title='Forgot password'),
    dict(name='forgot.filled', view='forgot', title='Forgot password filled',
         web=[fill('input[type="email"]', EMAIL), wait()], android=[enter('login-email', EMAIL)]),
    dict(name='forgot.sent', view='forgot', title='Forgot password sent',
         web=[fill('input[type="email"]', EMAIL), click(SUBMIT), wait(250)],
         android=[enter('login-email', EMAIL), tap('login-submit')]),
    dict(name='forgot.error', view='forgot', title='Forgot password send failed', routeSet='forgot-error',
         web=[fill('input[type="email"]', EMAIL), click(SUBMIT), wait(250)],
         android=[enter('login-email', EMAIL), tap('login-submit')]),
    # ---- reset password -----------------------------------------------
    dict(name='reset.default', view='reset', title='Reset password'),
    dict(name='reset.filled', view='reset', title='Reset password filled',
         web=[fill('input[placeholder="Min 8 characters"]', 'correct horse battery'),
              fill('form input[type="password"]:not([placeholder])', 'correct horse battery'), wait()],
         android=[enter('reset-password', 'correct horse battery'),
                  enter('reset-confirm', 'correct horse battery')]),
    dict(name='reset.too-short', view='reset', title='Reset password too short',
         web=[fill('input[placeholder="Min 8 characters"]', 'short'),
              fill('form input[type="password"]:not([placeholder])', 'short'), click(SUBMIT), wait()],
         android=[enter('reset-password', 'short'), enter('reset-confirm', 'short'), tap('login-submit')]),
    dict(name='reset.mismatch', view='reset', title='Reset password mismatch',
         web=[fill('input[placeholder="Min 8 characters"]', 'correct horse battery'),
              fill('form input[type="password"]:not([placeholder])', 'different horse battery'),
              click(SUBMIT), wait()],
         android=[enter('reset-password', 'correct horse battery'),
                  enter('reset-confirm', 'different horse battery'), tap('login-submit')]),
    dict(name='reset.error', view='reset', title='Reset password failed', routeSet='reset-error',
         web=[fill('input[placeholder="Min 8 characters"]', 'correct horse battery'),
              fill('form input[type="password"]:not([placeholder])', 'correct horse battery'),
              click(SUBMIT), wait(250)],
         android=[enter('reset-password', 'correct horse battery'),
                  enter('reset-confirm', 'correct horse battery'), tap('login-submit')]),
    dict(name='reset.success', view='reset', title='Reset password done',
         web=[fill('input[placeholder="Min 8 characters"]', 'correct horse battery'),
              fill('form input[type="password"]:not([placeholder])', 'correct horse battery'),
              click(SUBMIT), wait(250)],
         android=[enter('reset-password', 'correct horse battery'),
                  enter('reset-confirm', 'correct horse battery'), tap('login-submit')]),
    # ---- email verification -------------------------------------------
    dict(name='verify.default', view='verify', title='Email verification'),
    dict(name='verify.manual', view='verify', title='Email verification manual entry',
         web=[click('button:has-text("Enter code manually")'), wait()], android=[tap('verify-manual-toggle')]),
    dict(name='verify.manual-filled', view='verify', title='Email verification code typed',
         web=[click('button:has-text("Enter code manually")'),
              fill('input[placeholder="Paste verification token"]', 'a1b2c3d4e5f6'), wait()],
         android=[tap('verify-manual-toggle'), enter('verification-token', 'a1b2c3d4e5f6')]),
    dict(name='verify.resent', view='verify', title='Email verification resent',
         web=[click('button:has-text("Resend Verification Email")'), wait(250)], android=[tap('verify-resend')]),
    dict(name='verify.resend-error', view='verify', title='Email verification resend failed',
         routeSet='resend-error',
         web=[click('button:has-text("Resend Verification Email")'), wait(250)], android=[tap('verify-resend')]),
    dict(name='verify.error', view='verify', title='Email verification code rejected', routeSet='verify-error',
         web=[click('button:has-text("Enter code manually")'),
              fill('input[placeholder="Paste verification token"]', 'a1b2c3d4e5f6'),
              click(SUBMIT), wait(250)],
         android=[tap('verify-manual-toggle'), enter('verification-token', 'a1b2c3d4e5f6'), tap('verify-submit')]),
    # ---- server selector ----------------------------------------------
    dict(name='server.choose', view='server-selector', servers='two', title='Choose server'),
    dict(name='server.create-more', view='server-selector', servers='two', title='Create another server',
         web=[click('button:has-text("Create New Server")'), wait()], android=[tap('global-server-create-new')]),
    dict(name='server.create-more-filled', view='server-selector', servers='two',
         title='Create another server filled',
         web=[click('button:has-text("Create New Server")'), fill('form input >> nth=0', "Cindy's pricing team"),
              wait()],
         android=[tap('global-server-create-new'), enter('global-server-name', "Cindy's pricing team")]),
    dict(name='server.create-first', view='server-selector', servers='none', title='Create first server',
         platforms=['mobile']),
    dict(name='server.create-first-filled', view='server-selector', servers='none',
         title='Create first server filled', platforms=['mobile'],
         web=[fill('#server-create-name', "Cindy's pricing team"), wait()],
         android=[enter('global-server-name', "Cindy's pricing team")]),
    # ---- server setup steps -------------------------------------------
    dict(name='setup.survey', view='survey', title='Setup survey', selector='[data-testid="server-setup-survey"]',
         key='setup-survey'),
    dict(name='setup.survey-selected', view='survey', title='Setup survey answered',
         selector='[data-testid="server-setup-survey"]', key='setup-survey',
         web=[click('[data-testid="signup-role-design"]'), click('[data-testid="signup-source-search"]'), wait()],
         android=[tap('signup-role-design'), tap('signup-source-search')]),
    dict(name='setup.survey-other', view='survey', title='Setup survey other source',
         selector='[data-testid="server-setup-survey"]', key='setup-survey',
         web=[click('[data-testid="signup-role-founder"]'), click('[data-testid="signup-source-other"]'),
              fill('[data-testid="signup-source-other-input"]', 'A newsletter'), wait()],
         android=[tap('signup-role-founder'), tap('signup-source-other'),
                  enter('signup-source-other-input', 'A newsletter')]),
    dict(name='setup.survey-error', view='survey', title='Setup survey save failed', routeSet='survey-error',
         selector='[data-testid="server-setup-survey"]', key='setup-survey',
         web=[click('[data-testid="signup-role-design"]'), click('[data-testid="signup-source-search"]'),
              click('[data-testid="server-setup-survey-continue"]'), wait(250)],
         android=[tap('signup-role-design'), tap('signup-source-search'), tap('server-setup-survey-continue')]),
    dict(name='setup.handoff', view='handoff', title='Setup handoff', selector='[data-testid="server-setup-handoff"]',
         key='setup-handoff'),
    dict(name='setup.handoff-starting', view='handoff', title='Setup handoff starting',
         routeSet='handoff-pending', selector='[data-testid="server-setup-handoff"]', key='setup-handoff',
         web=[click('[data-testid="server-setup-handoff-done"]'), wait(250)],
         android=[tap('server-setup-handoff-done')]),
    # computer runtime step (dev/serverSetupPreviewFixtures.ts views)
    *[dict(name=f'setup.computer-{n}', view='computer-step', title=f'Setup computer step {n}', step=n,
           reset=(n == 'offline-recovery-many'), selector='section:has(> header)', key='setup-computer')
      for n in ('not-connected', 'connecting', 'ready', 'not-ready', 'offline-recovery',
                'offline-recovery-many')],
]


def make_cases():
    cases = []
    for s in SURFACES:
        for platform, viewport in PLATFORMS.items():
            if platform not in s.get('platforms', PLATFORMS):
                continue
            for suffix, theme in THEMES.items():
                cid = f'{PREFIX}{platform}.{s["name"]}.{suffix}'
                props = {'extCase': f'{platform}.{s["name"]}', 'extKind': 'auth', 'parityTheme': theme,
                         'platform': platform, 'view': s['view'], 'name': s['name'],
                         'w': viewport['width'], 'h': viewport['height']}
                if s.get('routeSet'):
                    props['routeSet'] = s['routeSet']
                if s.get('servers'):
                    props['servers'] = s['servers']
                if s.get('step'):
                    props['step'] = s['step']
                if s.get('reset'):
                    props['reset'] = True
                crop = bool(s.get('selector'))
                capture = {
                    'selector': s.get('selector') or f"[data-visual-case='{cid}']",
                    'crop': 'element', 'contract': 'component-bounds' if crop else 'screen-route',
                    'interactions': s.get('web', []),
                    'androidInteractions': s.get('android', []),
                }
                if crop:
                    capture['androidKey'] = s['key']
                cases.append({
                    'id': cid,
                    'title': f'{s["title"]} {platform} ({theme})',
                    'captureType': 'component-fixture' if crop else 'real-screen',
                    'surface': 'auth-ext',
                    'category': 'extension/auth',
                    'suite': 'raft-flutter-extension',
                    'viewport': viewport,
                    'theme': theme,
                    'locale': 'en',
                    'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                    'capture': capture,
                    'reactPathHint': 'packages/web/src/components/auth/ (+ components/onboarding/)',
                    'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_auth.dart '{platform}.{s['name']}'",
                    'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
                })
    return cases


cases = make_cases()
path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures' / 'auth-ext.json').write_text(json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} auth-ext cases appended ({len(manifest["cases"])} total)')
