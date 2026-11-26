#!/usr/bin/env python3
"""Generate fixtures/legacy-wave4a.json and append Wave 4A cases to the parity-ext manifest."""
import json
import sys
from pathlib import Path

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

PREFIX = 'components.legacy-wave4a.'
THEMES = [('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')]
VIEWPORTS = {
    'desktop': {'width': 1280, 'height': 900, 'density': 3},
    'phone': {'width': 390, 'height': 844, 'density': 3, 'touch': True},
}

fixture = {
    'declaredScopes': [
        'openid',
        'profile',
        'identity',
        'email',
        'agent:event:write',
    ],
    'oauthScopes': [
        'openid',
        'profile',
        'identity',
        'agent:event:write',
    ],
    'publicChannels': [
        {
            'id': 'ch-pub-1',
            'name': 'announcements',
            'description': 'Weekly product notes and changelogs.',
        },
        {
            'id': 'ch-pub-2',
            'name': 'showcase',
            'description': 'Community demos and shared prompts.',
        },
    ],
    'agreementBody': (
        'Welcome to Design Team.\n\n'
        '- Be respectful in shared channels.\n'
        '- Keep confidential workspace data internal.'
    ),
}

(here / 'fixtures/legacy-wave4a.json').write_text(
    json.dumps(fixture, indent=2) + '\n'
)

SPECS = [
    (
        'declared-scopes',
        'desktop',
        'Declared OAuth scopes picker',
        'packages/web/src/features/apps/connected-apps/DeclaredScopesPicker.tsx',
    ),
    (
        'declared-scopes',
        'phone',
        'Declared OAuth scopes picker',
        'packages/web/src/features/apps/connected-apps/DeclaredScopesPicker.tsx',
    ),
    (
        'oauth-scope-summary',
        'desktop',
        'OAuth scope summary panel',
        'packages/web/src/features/apps/connected-apps/OAuthScopeSummaryPanel.tsx',
    ),
    (
        'public-channel-list',
        'desktop',
        'Public channel list',
        'packages/web/src/features/settings/server/PublicChannelList.tsx',
    ),
    (
        'public-channel-list-empty',
        'desktop',
        'Public channel list (empty)',
        'packages/web/src/features/settings/server/PublicChannelList.tsx',
    ),
    (
        'agreement-body',
        'desktop',
        'Server agreement body preview',
        'packages/web/src/components/server/AgreementBody.tsx',
    ),
    (
        'agreement-body-empty',
        'desktop',
        'Server agreement body preview (empty)',
        'packages/web/src/components/server/AgreementBody.tsx',
    ),
]

cases = []
for surface, platform, title, hint in SPECS:
    viewport = dict(VIEWPORTS[platform])
    for suffix, theme in THEMES:
        cid = f'{PREFIX}{surface}.{platform}.{suffix}'
        cases.append({
            'id': cid,
            'title': f'{title} ({platform}, {theme})',
            'captureType': 'component-fixture',
            'surface': f'legacy-wave4a-{surface}',
            'category': 'extension/legacy-wave4a',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [
                {
                    'id': 'default',
                    'name': 'Default',
                    'props': {
                        'extCase': surface,
                        'extKind': 'legacy-wave4a',
                        'wave4aSurface': surface,
                        'platform': platform,
                        'parityTheme': theme,
                    },
                }
            ],
            'capture': {
                'selector': f'[data-visual-case="{cid}"]',
                'crop': 'element',
                'contract': 'component-bounds',
                'androidKey': 'wave4a-frame',
                'interactions': [{'type': 'wait', 'ms': 100}],
                'androidInteractions': [],
            },
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_legacy_wave4a.dart '{cid}'",
            'tolerance': {
                'pixelRatio': 0.02,
                'layoutDp': 1,
                'ignoreAntialiasing': True,
            },
        })

mp = manifest_path()
manifest = json.loads(mp.read_text())
manifest['cases'] = [
    c for c in manifest.get('cases', []) if not c['id'].startswith(PREFIX)
]
manifest['cases'].extend(cases)
mp.write_text(json.dumps(manifest, indent=2) + '\n')
print(f'{len(cases)} legacy-wave4a cases appended ({len(manifest["cases"])} total)')
