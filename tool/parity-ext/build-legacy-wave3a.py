#!/usr/bin/env python3
"""Append Wave 3A legacy UI cleanup parity cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Covers Wave 3A surfaces against pinned Web v1.24 across Desktop (1280x900) +
Phone (390x844), Light (brutal-light) + Dark (elegant-dark):
  - C1: server-create-preview, server-create-custom, identity-impact-preview
  - C2: cindy-setup, setup-survey, setup-handoff, setup-computer
  - C3: provider-accounts, human-login-servers
  - D4: feedback-empty
  - D5: search-skeleton, search-error
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

PREFIX = 'components.legacy-wave3a.'
THEMES = [('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')]
VIEWPORTS = {
    'desktop': {'width': 1280, 'height': 900, 'density': 3},
    'phone': {'width': 390, 'height': 844, 'density': 3, 'touch': True},
}

FIXTURE = {
    'description': 'Shared fixture data for Wave 3A legacy UI cleanup parity cases.',
    'user': {
        'id': 'user-wave3a',
        'email': 'alex@raft.build',
        'name': 'alexchen',
        'displayName': 'Alex Chen',
        'role': 'owner',
        'avatarUrl': None,
        'emailVerified': True,
    },
    'server': {
        'id': 'srv-wave3a',
        'name': 'Launch Studio',
        'slug': 'launch',
        'ownerId': 'user-wave3a',
        'role': 'owner',
        'iconUrl': None,
        'createdAt': '2026-06-01T00:00:00.000Z',
    },
    'machine': {
        'id': 'mach-wave3a',
        'serverId': 'srv-wave3a',
        'name': 'MacBook-Pro.local',
        'hostname': 'MacBook-Pro.local',
        'status': 'online',
        'platform': 'darwin',
        'arch': 'arm64',
        'ownerId': 'user-wave3a',
        'isComputer': True,
        'runtimes': ['claude', 'codex'],
        'lastSeenAt': '2026-06-15T12:00:00.000Z',
    },
    'runtimeOptions': [
        {
            'runtimeId': 'claude',
            'capabilityStatus': 'available',
            'canSelectInThisContext': True,
            'reason': None,
            'runtimeFormV2': {'protocolVersion': 2},
        },
        {
            'runtimeId': 'codex',
            'capabilityStatus': 'available',
            'canSelectInThisContext': True,
            'reason': None,
            'runtimeFormV2': {'protocolVersion': 2},
        },
        {
            'runtimeId': 'opencode',
            'capabilityStatus': 'unavailable',
            'canSelectInThisContext': False,
            'reason': 'not_installed',
        },
    ],
    'providers': [
        {'id': 'google', 'label': 'Google', 'enabled': True},
        {'id': 'github', 'label': 'GitHub', 'enabled': True},
    ],
    'identities': [
        {
            'provider': 'google',
            'providerUserId': 'g-1',
            'providerEmail': 'alex@raft.build',
        },
    ],
    'loginServers': [
        {
            'id': 'srv-1',
            'name': 'Acme Studio',
            'slug': 'acme',
            'state': 'ready',
        },
        {
            'id': 'srv-2',
            'name': 'Beta Labs',
            'slug': 'beta',
            'state': 'install',
        },
        {
            'id': 'srv-3',
            'name': 'Team C',
            'slug': 'team-c',
            'state': 'adminNeeded',
        },
        {
            'id': 'srv-4',
            'name': 'Offline Org',
            'slug': 'offline-org',
            'state': 'unavailable',
        },
    ],
}

(here / 'fixtures/legacy-wave3a.json').write_text(
    json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n'
)

cases = []


def add_case(
    surface,
    platform,
    title,
    hint,
    *,
    selector='[data-visual-case="{cid}"]',
    android_key=None,
    crop='element',
    interactions=None,
):
    viewport = dict(VIEWPORTS[platform])
    for suffix, theme in THEMES:
        cid = f'{PREFIX}{surface}.{platform}.{suffix}'
        props = {
            'extCase': surface,
            'extKind': 'legacy-wave3a',
            'wave3aSurface': surface,
            'platform': platform,
            'parityTheme': theme,
        }
        cases.append({
            'id': cid,
            'title': f'{title} ({platform}, {theme})',
            'captureType': 'component-fixture',
            'surface': f'legacy-wave3a-{surface}',
            'category': 'extension/legacy-wave3a',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': {
                'selector': selector.format(cid=cid),
                'crop': crop,
                'contract': 'component-bounds',
                **({'androidKey': android_key} if android_key else {}),
                'interactions': interactions or [],
                'androidInteractions': [],
            },
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_legacy_wave3a.dart '{cid}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })


for platform in ('desktop', 'phone'):
    add_case(
        'server-create-preview',
        platform,
        'Server create live preview (default)',
        'packages/web/src/components/auth/ServerCreatePreview.tsx',
        android_key='wave3a-frame',
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'cindy-setup',
        platform,
        'Meet Cindy onboarding dialog',
        'packages/web/src/features/agent/CreateAgentDialog.tsx',
        selector='[data-testid="create-cindy-screen-c"]',
        android_key='wave3a-cindy-setup',
        interactions=[{'type': 'wait', 'ms': 300}],
    )
    add_case(
        'setup-survey',
        platform,
        'Server setup survey step',
        'packages/web/src/components/onboarding/ServerSetupSurveyStep.tsx',
        selector='[data-testid="server-setup-survey"]',
        android_key='wave3a-setup-survey',
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'setup-handoff',
        platform,
        'Server setup handoff step',
        'packages/web/src/components/onboarding/ServerSetupHandoffStep.tsx',
        selector='[data-testid="server-setup-handoff"]',
        android_key='wave3a-setup-handoff',
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'setup-computer',
        platform,
        'Server setup computer runtime step',
        'packages/web/src/components/onboarding/ServerSetupComputerRuntimeStep.tsx',
        selector='[data-visual-case="{cid}"] section',
        android_key='wave3a-setup-computer',
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'provider-accounts',
        platform,
        'Connected provider accounts list group',
        'packages/web/src/components/settings/ProviderAccountRow.tsx',
        android_key='wave3a-frame',
        interactions=[{'type': 'wait', 'ms': 200}],
    )
    add_case(
        'human-login-servers',
        platform,
        'Human login marketplace servers field',
        'packages/web/src/pages/MarketplaceServerRow.tsx',
        android_key='wave3a-frame',
        interactions=[{'type': 'wait', 'ms': 200}],
    )
    add_case(
        'feedback-empty',
        platform,
        'Feedback inbox empty state',
        'packages/web/node_modules/@botiverse/hands-feedback-react/src/components.tsx',
        selector='[data-feedback-empty-kind="all"]',
        android_key='feedback-empty',
        interactions=[{'type': 'wait', 'ms': 300}],
    )
    add_case(
        'search-skeleton',
        platform,
        'Quick switcher search skeleton',
        'packages/web/src/features/search/SearchSkeleton.tsx',
        android_key='quick-switcher-skeleton',
        interactions=[{'type': 'wait', 'ms': 200}],
    )
    add_case(
        'search-error',
        platform,
        'Quick switcher search error banner',
        'packages/web/src/features/search/SearchMessageResultsSection.tsx',
        android_key='wave3a-frame',
        interactions=[{'type': 'wait', 'ms': 200}],
    )

add_case(
    'server-create-custom',
    'desktop',
    'Server create live preview (custom name)',
    'packages/web/src/components/auth/ServerCreatePreview.tsx',
    android_key='wave3a-frame',
    interactions=[{'type': 'wait', 'ms': 250}],
)
add_case(
    'identity-impact-preview',
    'desktop',
    'Account identity impact preview',
    'packages/web/src/components/auth/AccountIdentitySetupPage.tsx',
    selector='[data-testid="identity-impact-preview"]',
    android_key='wave3a-identity-preview',
    interactions=[{'type': 'wait', 'ms': 350}],
)

mp = manifest_path()
manifest = json.loads(mp.read_text())
manifest['cases'] = [
    c for c in manifest.get('cases', []) if not c['id'].startswith(PREFIX)
]
manifest['cases'].extend(cases)
mp.write_text(json.dumps(manifest, indent=2) + '\n')
print(f'{len(cases)} legacy-wave3a cases appended ({len(manifest["cases"])} total)')
