#!/usr/bin/env python3
"""Append Wave 1 legacy UI migration parity cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Covers all Wave 1 surfaces across Desktop (1280x900) + Phone (390x844), Light + Dark:
  - task-handoff & task-handoff-returned (TaskHandoffCard vs RaftTaskHandoffCard)
  - action-card & action-card-open (non-spec UnknownActionCard vs RaftActionCard)
  - quoted-skeleton (QuotedMessagePermalinkPreview loading vs RaftQuotedMessageSkeleton)
  - inline-audio & inline-audio-failed (InlineAudioAttachmentCard vs RaftInlineAudio)
  - forward-desktop (ForwardComposerDialog at 1280x900 vs ForwardComposerPage desktop)
"""
import base64
import json
import pathlib
import struct
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

PREFIX = 'components.legacy-wave1.'
THEMES = [('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')]
VIEWPORTS = {
    'desktop': {'width': 1280, 'height': 900, 'density': 2},
    'phone': {'width': 390, 'height': 844, 'density': 2, 'touch': True},
}


def make_silent_wav_data_url(sample_rate=8000, samples=800):
    """0.1s mono 8-bit silent WAV so Chromium decodes metadata and formats 0:00 / 0:00."""
    data = bytes([128] * samples)
    header = struct.pack(
        '<4sI4s4sIHHIIHH4sI',
        b'RIFF',
        36 + len(data),
        b'WAVE',
        b'fmt ',
        16,
        1,  # PCM
        1,  # mono
        sample_rate,
        sample_rate,
        1,
        8,
        b'data',
        len(data),
    )
    return 'data:audio/wav;base64,' + base64.b64encode(header + data).decode('ascii')


FIXTURE = {
    'user': {
        'id': 'user-ava-wave1',
        'name': 'ava',
        'displayName': 'Ava',
        'preferredTimezone': 'UTC',
        'preferredTimeFormat': '24h',
    },
    'server': {
        'id': 'server-wave1',
        'slug': 'acme',
        'name': 'Acme',
        'role': 'owner',
        'plan': 'pro',
    },
    'channels': [
        {
            'id': 'chan-wave1-general',
            'serverId': 'server-wave1',
            'name': 'general',
            'type': 'channel',
            'joined': True,
            'archivedAt': None,
        },
        {
            'id': 'chan-wave1-design',
            'serverId': 'server-wave1',
            'name': 'design',
            'type': 'channel',
            'joined': True,
            'archivedAt': None,
        },
    ],
    'agents': [
        {
            'id': 'agent-cindy-wave1',
            'name': 'Cindy',
            'displayName': 'Cindy',
            'avatarUrl': 'pixel:fox',
            'status': 'online',
        },
        {
            'id': 'agent-martin-wave1',
            'name': 'Martin',
            'displayName': 'Martin',
            'avatarUrl': 'pixel:owl',
            'status': 'online',
        },
    ],
    'members': [
        {
            'userId': 'user-ava-wave1',
            'name': 'ava',
            'displayName': 'Ava',
            'role': 'owner',
        },
    ],
    'handoff': {
        'messageId': 'msg-handoff-wave1',
        'time': '05:56',
        'notice': {
            'taskNumber': 19,
            'actor': {
                'type': 'agent',
                'id': 'agent-cindy-wave1',
                'name': 'Cindy',
                'displayName': 'Cindy',
            },
            'assignee': {
                'type': 'agent',
                'id': 'agent-martin-wave1',
                'name': 'Martin',
                'displayName': 'Martin',
            },
            'reason': 'PR #719 ready: please rerun the merge gate',
        },
        'returned': {
            'by': {
                'type': 'agent',
                'id': 'agent-cindy-wave1',
                'name': 'Cindy',
                'displayName': 'Cindy',
            },
            'at': '2026-06-22T06:12:00.000Z',
        },
    },
    'unknownActionCard': {
        'kind': 'action-card',
        'state': 'prepared',
        'sourceServerId': 'server-wave1',
        'confirmationVersion': 1,
        'action': {
            'type': 'legacy:sandbox_credentials',
        },
        'presentation': {
            'title': 'Provision sandbox credentials',
            'warning': 'Only a workspace owner can review these credentials.',
            'displayItems': [
                {'key': 'Service', 'value': 'GitHub Actions'},
                {'key': 'Environment', 'value': 'staging-us-east'},
            ],
        },
    },
    'quotedPermalink': {
        'serverId': 'server-wave1',
        'channelId': 'chan-wave1-design',
        'messageId': 'msg-quote-loading-wave1',
        'routeKind': 'channel',
    },
    'audio': {
        'filename': 'standup-recording.mp3',
        'mimeType': 'audio/mpeg',
        'sizeBytes': 2411520,
        'readyAttachmentId': 'att-audio-ready-wave1',
        'failedAttachmentId': 'att-audio-failed-wave1',
        'silentWavDataUrl': make_silent_wav_data_url(),
    },
    'forwardMessage': {
        'id': 'msg-forward-wave1',
        'seq': 1,
        'serverId': 'server-wave1',
        'channelId': 'chan-wave1-general',
        'messageType': 'chat',
        'senderType': 'agent',
        'senderId': 'agent-cindy-wave1',
        'senderName': 'Cindy',
        'content': 'Wave 1 parity checks are green across desktop and phone.',
        'createdAt': '2026-06-22T09:41:00.000Z',
    },
}

(here / 'fixtures/legacy-wave1.json').write_text(
    json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n'
)

cases = []


def add_case(
    surface,
    name,
    platform,
    title,
    hint,
    *,
    selector=None,
    android_key='wave1-frame',
    interactions=None,
    box_width=None,
    density=None,
    clock_iso=None,
):
    viewport = dict(VIEWPORTS[platform])
    if density is not None:
        viewport['density'] = density
    width = box_width if box_width is not None else (640 if platform == 'desktop' else 390)
    for suffix, theme in THEMES:
        cid = f'{PREFIX}{surface}.{name}.{suffix}'
        sel = selector or f'[data-visual-case="{cid}"]'
        props = {
            'extCase': f'{surface}.{name}',
            'extKind': 'legacy-wave1',
            'wave1Surface': surface,
            'platform': platform,
            'boxWidth': width,
            'parityTheme': theme,
        }
        if clock_iso is not None:
            props['clockIso'] = clock_iso
        cases.append({
            'id': cid,
            'title': f'{title} ({platform}, {theme})',
            'captureType': 'component-fixture',
            'surface': f'legacy-wave1-{surface}',
            'category': 'extension/legacy-wave1',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': {
                'selector': sel,
                'crop': 'element',
                'contract': 'component-bounds',
                'androidKey': android_key,
                'interactions': interactions or [],
                'androidInteractions': [],
            },
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_legacy_wave1.dart '{cid}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })


for platform in ('desktop', 'phone'):
    add_case(
        'task-handoff',
        platform,
        platform,
        'Task handoff card (waiting)',
        'packages/web/src/components/task/TaskHandoffCard.tsx',
    )
    add_case(
        'task-handoff-returned',
        platform,
        platform,
        'Task handoff card (returned)',
        'packages/web/src/components/task/TaskHandoffCard.tsx',
        clock_iso='2026-06-22T06:30:00.000Z',
    )
    add_case(
        'action-card',
        platform,
        platform,
        'Non-spec action card (collapsed)',
        'packages/web/src/components/actions/ActionCard.tsx',
    )
    add_case(
        'action-card-open',
        platform,
        platform,
        'Non-spec action card (expanded)',
        'packages/web/src/components/actions/ActionCard.tsx',
        interactions=[
            {'type': 'click', 'target': 'button[aria-label="Show or hide details"]'},
            {'type': 'wait', 'ms': 300},
        ],
    )
    add_case(
        'quoted-skeleton',
        platform,
        platform,
        'Quoted message loading skeleton',
        'packages/web/src/components/message/QuotedMessagePermalinkPreview.tsx',
    )
    add_case(
        'inline-audio',
        platform,
        platform,
        'Inline audio player (ready)',
        'packages/web/src/components/message/MessageItem.tsx',
        selector='[data-message-affordance="inline-audio-preview"] > [data-slot="card"]',
        android_key='inline-audio',
        interactions=[{'type': 'wait', 'ms': 300}],
    )
    add_case(
        'inline-audio-failed',
        platform,
        platform,
        'Inline audio attachment (failed)',
        'packages/web/src/components/message/MessageItem.tsx',
        selector='[data-message-affordance="inline-audio-preview"] > [data-slot="card"]',
        android_key='inline-audio',
        interactions=[{'type': 'wait', 'ms': 300}],
    )

add_case(
    'forward-desktop',
    'dialog',
    'desktop',
    'Forward desktop dialog (1280x900)',
    'packages/web/src/components/message/ForwardComposerDesktop.tsx',
    selector='[data-testid="forward-composer-dialog"]',
    android_key='forward-dialog',
    box_width=1280,
    density=1,
    interactions=[{'type': 'wait', 'ms': 300}],
)

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} legacy-wave1 cases appended ({len(manifest["cases"])} total)')
