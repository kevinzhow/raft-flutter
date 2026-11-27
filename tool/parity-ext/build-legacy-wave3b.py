#!/usr/bin/env python3
"""Append Wave 3B legacy UI cleanup parity cases to $PARITY_EXT_MANIFEST.

Covers Wave 3B surfaces against pinned Web v1.24 across Light (brutal-light) and
Dark (elegant-dark), plus Desktop + Phone where responsive:
  - D1: agent-chat, agent-chat-empty
  - D2: agent-env-vars, agent-reminders, agent-reminders-empty
  - D3: computer-workspaces, computer-agent-rows, computer-service
  - D6: channel-files, channel-files-empty
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

PREFIX = 'components.legacy-wave3b.'
THEMES = [('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')]
VIEWPORTS = {
    'desktop': {'width': 1280, 'height': 900, 'density': 3},
    'phone': {'width': 390, 'height': 844, 'density': 3, 'touch': True},
}

FIXTURE = {
    'description': 'Shared fixture data for Wave 3B legacy UI cleanup parity cases.',
    'user': {
        'id': 'user-wave3b',
        'email': 'alex@raft.build',
        'name': 'alexchen',
        'displayName': 'Alex Chen',
        'role': 'owner',
        'avatarUrl': None,
        'emailVerified': True,
        'preferredLanguage': 'en',
        'preferredTimezone': 'UTC',
        'preferredTimeFormat': '24h',
    },
    'server': {
        'id': 'srv-wave3b',
        'name': 'Launch Studio',
        'slug': 'launch',
        'ownerId': 'user-wave3b',
        'role': 'owner',
        'iconUrl': None,
        'createdAt': '2026-06-01T00:00:00.000Z',
    },
    'agent': {
        'id': 'agent-wave3b',
        'serverId': 'srv-wave3b',
        'name': 'martin',
        'displayName': 'Martin',
        'description': 'UI cleanup worker agent.',
        'status': 'active',
        'runtime': 'claude',
        'model': 'claude-sonnet-4-5',
        'avatarUrl': 'pixel:robot',
        'machineId': 'mach-wave3b',
        'envVars': {
            'RAFT_ENV': 'staging',
            'API_TOKEN': 'secret-token-value',
        },
        'createdAt': '2026-06-01T00:00:00.000Z',
    },
    'channels': [
        {
            'id': 'ch-general',
            'name': 'general',
            'description': 'Team coordination and daily standups',
            'type': 'channel',
            'createdAt': '2026-06-01T00:00:00.000Z',
            'archivedAt': None,
            'activityMuted': False,
            'muteFromSeq': None,
        },
        {
            'id': 'ch-private',
            'name': 'release-ops',
            'description': 'Private deployment checklists',
            'type': 'private',
            'createdAt': '2026-06-02T00:00:00.000Z',
            'archivedAt': None,
            'activityMuted': True,
            'muteFromSeq': 42,
        },
        {
            'id': 'ch-joint',
            'name': 'partner-sync',
            'description': None,
            'type': 'joint',
            'createdAt': '2026-06-03T00:00:00.000Z',
            'archivedAt': None,
            'activityMuted': False,
            'muteFromSeq': None,
        },
    ],
    'agentDms': [
        {
            'id': 'dm-1',
            'createdAt': '2026-11-24T10:00:00.000Z',
            'peerId': 'agent-scout',
            'peerName': 'scout',
            'peerDisplayName': 'Scout',
            'peerAvatarUrl': 'pixel:owl',
            'lastMessageAt': '2026-11-24T10:00:00.000Z',
            'lastMessagePreview': 'Verified the layout diff captures on desktop.',
        },
    ],
    'reminders': [
        {
            'reminderId': 'rem-1',
            'title': 'Follow up on parity score audit',
            'fireAt': '2026-12-01T14:00:00.000Z',
            'recurrence': {
                'cron': '0 14 * * 1',
                'description': 'Every Monday',
            },
            'msgRef': '#general:ab12cd',
            'msgPermalink': '/s/launch/channels/ch-general?msg=ab12cd',
        },
        {
            'reminderId': 'rem-2',
            'title': 'Check staging computer daemon logs',
            'fireAt': '2026-12-03T09:30:00.000Z',
            'recurrence': None,
            'msgRef': '#release-ops:ef34gh',
            'msgPermalink': None,
        },
    ],
    'machine': {
        'id': 'mach-wave3b',
        'serverId': 'srv-wave3b',
        'name': 'Studio-Mac.local',
        'hostname': 'Studio-Mac.local',
        'status': 'online',
        'platform': 'darwin',
        'arch': 'arm64',
        'ownerId': 'user-wave3b',
        'isComputer': True,
        'daemonVersion': '1.0.58',
        'runtimes': ['claude', 'codex'],
        'lastSeenAt': '2026-11-26T00:00:00.000Z',
    },
    'computerAgents': [
        {
            'id': 'ca-1',
            'serverId': 'srv-wave3b',
            'machineId': 'mach-wave3b',
            'name': 'martin',
            'displayName': 'Martin',
            'runtime': 'claude',
            'model': 'claude-sonnet-4-5',
            'avatarUrl': 'pixel:robot',
            'activity': 'working',
            'activityDetail': 'Running parity checks',
        },
        {
            'id': 'ca-2',
            'serverId': 'srv-wave3b',
            'machineId': 'mach-wave3b',
            'name': 'scout',
            'displayName': 'Scout',
            'runtime': 'codex',
            'model': 'gpt-5-codex',
            'avatarUrl': 'pixel:owl',
            'activity': 'offline',
            'activityDetail': None,
        },
    ],
    'workspaces': [
        {
            'directoryName': 'martin-ws',
            'agentId': 'ca-1',
            'agentName': 'Martin',
            'status': 'active',
            'totalSizeBytes': 12582912,
            'fileCount': 42,
            'lastModified': '2026-10-10T12:00:00.000Z',
            'displayPath': '/srv/workspaces/martin-ws',
        },
        {
            'directoryName': 'archived-bot',
            'agentId': None,
            'agentName': 'Old Helper',
            'status': 'deleted',
            'totalSizeBytes': 4194304,
            'fileCount': 9,
            'lastModified': '2026-09-18T12:00:00.000Z',
            'displayPath': '/srv/workspaces/archived-bot',
        },
        {
            'directoryName': 'build-runner-ws',
            'agentId': 'ca-2',
            'agentName': 'Scout',
            'status': 'stopped',
            'totalSizeBytes': 2097152,
            'fileCount': 6,
            'lastModified': '2026-08-05T12:00:00.000Z',
            'displayPath': '/srv/workspaces/build-runner-ws',
        },
    ],
    'channel': {
        'id': 'ch-files',
        'serverId': 'srv-wave3b',
        'name': 'design-assets',
        'type': 'channel',
        'createdAt': '2026-06-01T00:00:00.000Z',
        'joined': True,
    },
    'channelFiles': [
        {
            'id': 'cf-1',
            'messageId': 'msg-1',
            'channelId': 'ch-files',
            'filename': 'architecture-spec.pdf',
            'mimeType': 'application/pdf',
            'sizeBytes': 245760,
            'createdAt': '2026-10-12T10:30:00.000Z',
            'uploader': {
                'type': 'user',
                'id': 'user-wave3b',
                'name': 'alexchen',
                'displayName': 'Alex Chen',
            },
            'source': {
                'type': 'channel',
                'channelId': 'ch-files',
                'parentMessageId': None,
                'parentMessageShortId': None,
            },
        },
        {
            'id': 'cf-2',
            'messageId': 'msg-2',
            'channelId': 'ch-files',
            'filename': 'release-assets.zip',
            'mimeType': 'application/zip',
            'sizeBytes': 1572864,
            'createdAt': '2026-10-14T16:45:00.000Z',
            'uploader': {
                'type': 'agent',
                'id': 'agent-wave3b',
                'name': 'martin',
                'displayName': 'Martin',
            },
            'source': {
                'type': 'channel',
                'channelId': 'ch-files',
                'parentMessageId': None,
                'parentMessageShortId': None,
            },
        },
    ],
}

FIXTURE['rasterFiles'] = [
    {
        **FIXTURE['channelFiles'][0],
        'filename': 'design.heic',
        'mimeType': 'image/heic',
        'thumbnailUrl': 'https://storage.example.invalid/api/gaps1-raster.png',
    },
    {
        **FIXTURE['channelFiles'][1],
        'filename': 'wordmark.svg',
        'mimeType': 'image/svg+xml',
    },
]
FIXTURE['routes'] = {
    'GET /gaps1-raster.png': {'$file': 'announcement-picture.png', '$contentType': 'image/png'},
}

(here / 'fixtures/legacy-wave3b.json').write_text(
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
    android_key='wave3b-frame',
    interactions=None,
):
    viewport = dict(VIEWPORTS[platform])
    for suffix, theme in THEMES:
        cid = f'{PREFIX}{surface}.{platform}.{suffix}'
        props = {
            'extCase': surface,
            'extKind': 'legacy-wave3b',
            'wave3bSurface': surface,
            'platform': platform,
            'parityTheme': theme,
        }
        cases.append({
            'id': cid,
            'title': f'{title} ({platform}, {theme})',
            'captureType': 'component-fixture',
            'surface': f'legacy-wave3b-{surface}',
            'category': 'extension/legacy-wave3b',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': {
                'selector': selector.format(cid=cid),
                'crop': 'element',
                'contract': 'component-bounds',
                'androidKey': android_key,
                'interactions': interactions or [],
                'androidInteractions': [],
            },
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_legacy_wave3b.dart '{cid}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })


for platform in ('desktop', 'phone'):
    add_case(
        'agent-chat',
        platform,
        'Agent detail Chat tab (channels and DMs)',
        'packages/web/src/features/agent/AgentChatTab.tsx',
        interactions=[{'type': 'wait', 'ms': 300}],
    )
    add_case(
        'agent-chat-empty',
        platform,
        'Agent detail Chat tab (combined empty)',
        'packages/web/src/features/agent/AgentChatTab.tsx',
        interactions=[{'type': 'wait', 'ms': 300}],
    )
    add_case(
        'computer-agent-rows',
        platform,
        'Computer detail Agent rows',
        'packages/web/src/components/machine/MachineAgentRow.tsx',
        interactions=[{'type': 'wait', 'ms': 200}],
    )
    add_case(
        'computer-agent-located',
        platform,
        'Computer detail agent after a bulk change',
        'packages/web/src/components/machine/MachineAgentRow.tsx',
        selector='[data-visual-case="{cid}"] [data-located]',
        android_key='computer-agent-ca-1',
        interactions=[{'type': 'wait', 'ms': 200}],
    )
    add_case(
        'channel-files',
        platform,
        'Channel Files panel (rows + actions)',
        'packages/web/src/components/message/ChannelFilesPanel.tsx',
        interactions=[{'type': 'wait', 'ms': 300}],
    )
    add_case(
        'channel-files-raster',
        platform,
        'Compact channel Files rows with HEIC thumbnail and SVG file glyph',
        'packages/web/src/components/message/ChannelFilesPanelFileRow.tsx',
        interactions=[{'type': 'wait', 'ms': 300}],
    )

add_case(
    'agent-env-vars',
    'desktop',
    'Agent profile Environment Variables chips',
    'packages/web/src/features/agent/EnvVarsSection.tsx',
    interactions=[{'type': 'wait', 'ms': 200}],
)
for platform in ('desktop', 'phone'):
    for state in ('populated', 'empty', 'error'):
        add_case(
            'agent-reminders' if state == 'populated' else f'agent-reminders-{state}',
            platform,
            f'Agent detail Reminders tab ({state})',
            'packages/web/src/components/agent/AgentRemindersSection.tsx',
            interactions=[{'type': 'wait', 'ms': 200}],
        )
add_case(
    'computer-workspaces',
    'desktop',
    'Computer detail Workspaces section (scanned)',
    'packages/web/src/features/computer/WorkspacesSection.tsx',
    android_key='computer-section-workspaces',
    interactions=[
        {'type': 'click', 'target': '[data-visual-case] button:has-text("Scan")'},
        {'type': 'wait', 'ms': 200},
    ],
)
add_case(
    'computer-service',
    'desktop',
    'Computer detail Service card (up to date)',
    'packages/web/src/features/computer/ComputerServiceActionsCard.tsx',
    selector='[data-visual-case] [data-testid="computer-service-actions"]',
    android_key='computer-section-service',
    interactions=[{'type': 'wait', 'ms': 200}],
)
add_case(
    'channel-files-empty',
    'desktop',
    'Channel Files panel (empty state)',
    'packages/web/src/components/message/ChannelFilesPanel.tsx',
    interactions=[{'type': 'wait', 'ms': 300}],
)

mp = manifest_path()
manifest = json.loads(mp.read_text())
manifest['cases'] = [
    c for c in manifest.get('cases', []) if not c['id'].startswith(PREFIX)
]
manifest['cases'].extend(cases)
mp.write_text(json.dumps(manifest, indent=2) + '\n')
print(f'{len(cases)} legacy-wave3b cases appended ({len(manifest["cases"])} total)')
