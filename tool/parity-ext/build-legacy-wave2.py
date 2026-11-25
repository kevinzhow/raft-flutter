#!/usr/bin/env python3
"""Append Wave 2 legacy UI migration parity cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Covers Wave 2 surfaces across Desktop (1280x900) + Phone (390x844), Light + Dark:
  - report-issue & report-issue-submitted (ReportIssueDialog vs RaftReportIssueDialog)
  - community-agreement (CommunityAgreementDialog vs RaftCommunityAgreementDialog)
  - add-computer-confirm (AddMachineDialog confirm step vs RaftAddComputerDialog)
  - add-members & add-members-empty (AddMembersDialog vs RaftAddMembersDialogView)
  - channel-members-page (ChannelMembers presentation="page" vs RaftChannelMembersModal)
  - runtime-provider-connect (RuntimeProviderConnectDialog vs ComputerRuntimeProviderConnectDialog)
  - attachment-comments & attachment-comments-empty (AttachmentCommentsPanel vs RaftAttachmentCommentsPanel)
  - message-image-export (SelectShareLightbox vs RaftImageReview)
"""
import base64
import json
import pathlib
import struct
import sys
import zlib

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

PREFIX = 'components.legacy-wave2.'
THEMES = [('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')]
VIEWPORTS = {
    'desktop': {'width': 1280, 'height': 900, 'density': 3},
    'phone': {'width': 390, 'height': 844, 'density': 3, 'touch': True},
}


def make_preview_png_b64(width=360, height=180):
    """Deterministic crisp PNG showing a neutral card graphic for SelectShareLightbox."""
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            border = x < 2 or y < 2 or x >= width - 2 or y >= height - 2
            header = 24 <= y < 44 and 24 <= x < 180
            bar1 = 68 <= y < 86 and 24 <= x < 300
            bar2 = 102 <= y < 120 and 24 <= x < 240
            badge = 136 <= y < 156 and 24 <= x < 120
            if border:
                r, g, b = 212, 212, 208
            elif header:
                r, g, b = 24, 24, 27
            elif bar1 or bar2:
                r, g, b = 113, 113, 122
            elif badge:
                r, g, b = 244, 114, 182
            else:
                r, g, b = 250, 250, 249
            row.extend((r, g, b, 255))
        rows.append(bytes(row))
    raw = b''.join(rows)

    def chunk(tag, data):
        return (
            struct.pack('>I', len(data))
            + tag
            + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    return base64.b64encode(png).decode('ascii')


FIXTURE = {
    'user': {
        'id': 'user-ava-wave2',
        'name': 'ava',
        'displayName': 'Ava',
        'preferredTimezone': 'UTC',
        'preferredTimeFormat': '24h',
    },
    'server': {
        'id': 'server-wave2',
        'slug': 'acme',
        'name': 'Acme',
        'role': 'owner',
        'plan': 'pro',
    },
    'channels': [
        {
            'id': 'chan-wave2-design',
            'serverId': 'server-wave2',
            'name': 'design',
            'type': 'channel',
            'joined': True,
            'archivedAt': None,
            'channelCapabilities': {
                'addChannelMembers': True,
                'removeChannelMembers': True,
            },
        },
    ],
    'agents': [
        {
            'id': 'agent-cindy-wave2',
            'name': 'cindy',
            'displayName': 'Cindy',
            'description': 'Coordinates release gates and reviews diffs.',
            'avatarUrl': 'pixel:fox',
            'status': 'online',
            'activity': 'idle',
            'machineId': 'mach-wave2-1',
            'runtime': 'claude',
            'model': 'sonnet',
            'role': 'member',
        },
        {
            'id': 'agent-lux-wave2',
            'name': 'lux',
            'displayName': 'Lux',
            'description': 'Visual parity auditor.',
            'avatarUrl': 'pixel:owl',
            'status': 'online',
            'activity': 'idle',
            'machineId': None,
            'runtime': 'codex',
            'model': 'gpt-5',
            'role': 'member',
        },
    ],
    'members': [
        {
            'userId': 'user-ava-wave2',
            'name': 'ava',
            'displayName': 'Ava',
            'description': 'Workspace owner',
            'role': 'owner',
            'avatarUrl': None,
        },
        {
            'userId': 'user-ben-wave2',
            'name': 'ben',
            'displayName': 'Ben',
            'description': 'Product designer',
            'role': 'member',
            'avatarUrl': None,
        },
    ],
    'machine': {
        'id': 'mach-wave2-1',
        'name': 'studio-mac',
        'hostname': 'studio-mac.local',
        'os': 'darwin',
        'status': 'online',
        'isComputer': True,
        'computerAttachedByCurrentUser': False,
        'runtimes': [],
        'runtimeVersions': {},
    },
    'agreement': {
        'title': 'Community Guidelines',
        'version': 3,
        'bodyMarkdown': (
            'Keep feedback constructive and respect privacy across channels.\n\n'
            'Shared workspaces require mutual consent before running tasks.'
        ),
    },
    'runtimeProviders': [
        {
            'id': 'openrouter',
            'label': 'OpenRouter',
            'description': 'Route requests across frontier models with one key.',
            'configured': True,
            'needsModelIds': True,
            'endpoint': {'kind': 'preset'},
            'group': {'id': 'third-party', 'label': 'Third-party'},
        },
        {
            'id': 'deepseek',
            'label': 'DeepSeek',
            'description': 'Direct DeepSeek API key for reasoning and code.',
            'configured': False,
            'needsModelIds': False,
            'endpoint': {'kind': 'preset'},
            'group': {'id': 'third-party', 'label': 'Third-party'},
        },
    ],
    'attachment': {
        'id': 'att-wave2-notes',
        'filename': 'release-notes.md',
        'parentMessage': {
            'id': 'msg-wave2-parent',
            'channelId': 'chan-wave2-design',
        },
        'comments': [
            {
                'id': 'cmt-wave2-1',
                'channelId': 'chan-wave2-thread',
                'senderType': 'agent',
                'senderId': 'agent-cindy-wave2',
                'senderName': 'Cindy',
                'content': 'Tighten border contrast on light panels before merge.',
                'createdAt': '2026-06-25T10:32:00.000Z',
                'reactions': [],
                'anchor': {
                    'type': 'lines',
                    'data': {
                        'start': 12,
                        'end': 14,
                        'quote': 'All modal footers use 1px line-hairline rules.',
                    },
                },
                'senderAvatarUrl': 'pixel:fox',
            },
        ],
        'pendingAnchor': {
            'type': 'lines',
            'data': {
                'start': 24,
                'end': 24,
            },
        },
    },
    'exportPngBase64': make_preview_png_b64(),
}

(here / 'fixtures/legacy-wave2.json').write_text(
    json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n'
)

cases = []


def add_case(
    surface,
    platform,
    title,
    hint,
    *,
    selector,
    android_key=None,
    crop='element',
    interactions=None,
):
    viewport = dict(VIEWPORTS[platform])
    for suffix, theme in THEMES:
        cid = f'{PREFIX}{surface}.{platform}.{suffix}'
        props = {
            'extCase': surface,
            'extKind': 'legacy-wave2',
            'wave2Surface': surface,
            'platform': platform,
            'parityTheme': theme,
        }
        cases.append({
            'id': cid,
            'title': f'{title} ({platform}, {theme})',
            'captureType': 'component-fixture',
            'surface': f'legacy-wave2-{surface}',
            'category': 'extension/legacy-wave2',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': {
                'selector': selector.format(cid=cid),
                'crop': crop,
                'contract': 'viewport-with-portal' if crop == 'viewport' else 'component-bounds',
                **({'androidKey': android_key} if android_key else {}),
                'interactions': interactions or [],
                'androidInteractions': [],
            },
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_legacy_wave2.dart '{cid}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })


for platform in ('desktop', 'phone'):
    dlg_sheet_sel = '[role="dialog"]' if platform == 'desktop' else 'body'
    dlg_sheet_crop = 'element' if platform == 'desktop' else 'viewport'
    modal_sel = '[role="dialog"]' if platform == 'desktop' else 'body'

    add_case(
        'report-issue',
        platform,
        'Report issue dialog',
        'packages/web/src/components/agent/ReportIssueDialog.tsx',
        selector='[role="dialog"]',
        android_key='report-issue-dialog',
        crop='element',
    )
    add_case(
        'report-issue-submitted',
        platform,
        'Report issue submitted dialog',
        'packages/web/src/components/agent/ReportIssueDialog.tsx',
        selector='[role="dialog"]',
        android_key='report-issue-submitted',
        crop='element',
        interactions=[
            {'type': 'click', 'target': 'label:has-text("I agree to send this report")'},
            {'type': 'wait', 'ms': 100},
            {'type': 'click', 'target': '[role="dialog"] button:has-text("Report")'},
            {'type': 'wait', 'ms': 400},
        ],
    )
    add_case(
        'community-agreement',
        platform,
        'Community agreement dialog',
        'packages/web/src/components/server/CommunityAgreementDialog.tsx',
        selector=modal_sel,
        android_key='community-agreement-card' if platform == 'desktop' else None,
        crop=dlg_sheet_crop,
    )
    add_case(
        'add-computer-confirm',
        platform,
        'Add computer confirmation dialog',
        'packages/web/src/components/machine/AddMachineDialog.tsx',
        selector='[role="dialog"]',
        android_key='computer-dialog',
        crop='element',
        interactions=[{'type': 'wait', 'ms': 300}],
    )
    add_case(
        'add-members',
        platform,
        'Add members dialog',
        'packages/web/src/components/channel/AddMembersDialog.tsx',
        selector=dlg_sheet_sel,
        android_key='add-members-dialog' if platform == 'desktop' else None,
        crop=dlg_sheet_crop,
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'add-members-empty',
        platform,
        'Add members dialog (empty)',
        'packages/web/src/components/channel/AddMembersDialog.tsx',
        selector=dlg_sheet_sel,
        android_key='add-members-dialog' if platform == 'desktop' else None,
        crop=dlg_sheet_crop,
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'channel-members-page',
        platform,
        'Channel members page',
        'packages/web/src/features/channel/ChannelMembers.tsx',
        selector='[data-testid="member-page"]',
        android_key='member-page',
        crop='element',
        interactions=[{'type': 'wait', 'ms': 200}],
    )
    add_case(
        'runtime-provider-connect',
        platform,
        'Runtime provider connect dialog',
        'packages/web/src/features/computer/RuntimeProviderConnectDialog.tsx',
        selector='[data-testid="runtime-provider-dialog-qwen"]',
        android_key='runtime-provider-dialog-qwen',
        crop='element',
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'attachment-comments',
        platform,
        'Attachment comments panel',
        'packages/web/src/components/message/AttachmentCommentsPanel.tsx',
        selector='[data-visual-case="{cid}"]',
        android_key='wave2-frame',
        crop='element',
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'attachment-comments-empty',
        platform,
        'Attachment comments panel (empty)',
        'packages/web/src/components/message/AttachmentCommentsPanel.tsx',
        selector='[data-visual-case="{cid}"]',
        android_key='wave2-frame',
        crop='element',
        interactions=[{'type': 'wait', 'ms': 250}],
    )
    add_case(
        'message-image-export',
        platform,
        'Message image export lightbox',
        'packages/web/src/components/message/SelectShareLightbox.tsx',
        selector='[data-testid="select-share-lightbox"]',
        android_key='wave2-lightbox',
        crop='element',
        interactions=[{'type': 'wait', 'ms': 250}],
    )

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} legacy-wave2 cases appended ({len(manifest["cases"])} total)')
