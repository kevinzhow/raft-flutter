#!/usr/bin/env python3
"""Real IntegrationInvitePage / native invitation states, with shared API fixtures."""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from builders import manifest_path

PREFIX = 'components.private-app-invite.'
INVITE = {
    'client': {'id': 'private-app', 'clientId': 'private-client', 'name': 'Shared Calendar',
               'description': 'A calendar shared by its publisher.',
               'homepageUrl': 'https://calendar.example.invalid',
               'returnUrl': 'https://calendar.example.invalid/callback',
               'allowedScopes': ['openid', 'profile'],
               'publisherName': 'Publisher', 'sourceServerName': 'Design'},
    'link': {'id': 'share', 'expiresAt': None},
    'manageableServers': [{'id': 'design', 'name': 'Design', 'slug': 'design',
                           'role': 'owner', 'installedAt': None}],
}
installed = json.loads(json.dumps(INVITE))
installed['manageableServers'][0]['installedAt'] = '2026-11-04T00:00:00Z'
no_admin = {**INVITE, 'manageableServers': []}
fixture = {
    'description': 'Named isolated private-App invitation. No production credentials or installation.',
    'user': {'id': 'alice', 'name': 'alice', 'email': 'alice@example.invalid', 'emailVerified': True},
    'routes': {},
    'routeSets': {
        state: {'GET /integration-invites/parity-private': answer}
        for state, answer in {
            'review': INVITE, 'installed': installed, 'no-admin': no_admin,
            'loading': {'$pending': True},
            'error': {'$status': 404, '$body': {'error': 'Private app invite not found'}},
        }.items()
    },
}
(HERE / 'fixtures/private-app-invite.json').write_text(json.dumps(fixture, indent=1) + '\n')
cases = []
for platform, viewport in {'desktop': {'width': 1280, 'height': 900, 'density': 1},
                           'mobile': {'width': 390, 'height': 844, 'density': 1}}.items():
    for state in fixture['routeSets']:
        for suffix, theme in {'brutal': 'brutal-light', 'elegant-dark': 'elegant-dark'}.items():
            cid = f'{PREFIX}{platform}.{state}.{suffix}'
            cases.append({
                'id': cid, 'title': f'Private App invite {state} {platform} ({theme})',
                'captureType': 'real-screen', 'surface': 'private-app-invite',
                'category': 'extension/private-app-invite', 'suite': 'raft-flutter-extension',
                'viewport': viewport, 'theme': theme, 'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': {
                    'extKind': 'private-app-invite', 'extFixture': 'private-app-invite',
                    'routeSet': state, 'platform': platform, 'parityTheme': theme,
                    'w': viewport['width'], 'h': viewport['height'],
                }}],
                'capture': {'selector': f'[data-visual-case="{cid}"]', 'crop': 'element',
                            'contract': 'screen-route', 'interactions': [{'type': 'wait', 'ms': 300}]},
                'reactPathHint': 'packages/web/src/pages/IntegrationInvitePage.tsx',
                'androidCaseHint': 'apps/raft_flutter/test/parity/cases/ext_private_app_invite.dart',
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1) + '\n')
print(f'{len(cases)} private App invitation cases appended')
