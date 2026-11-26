#!/usr/bin/env python3
"""Generate fixtures/legacy-wave4b.json and append Wave 4B cases to the parity-ext manifest."""
import copy
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

PREFIX = 'components.legacy-wave4b.'
VIEWPORTS = {
    'desktop': {'width': 1280, 'height': 900, 'density': 3},
    'phone': {'width': 390, 'height': 844, 'density': 3, 'touch': True},
}
FIXTURE = {
    'description': (
        'Wave 4B migrated E5/E6 component fixtures shared between '
        'host/LegacyWave4bCases.tsx and cases/ext_legacy_wave4b.dart.'
    ),
    'selectField': {
        'label': 'Visibility',
        'hint': 'Who can view this channel.',
        'value': 'workspace',
        'options': [
            {'value': 'workspace', 'label': 'Workspace'},
            {'value': 'private', 'label': 'Private'},
        ],
    },
    'mermaidMenu': {
        'triggerLabel': 'Download Mermaid Diagram',
        'items': [
            {'id': 'mmd', 'label': 'Download Source', 'icon': 'code2'},
            {'id': 'png', 'label': 'Download PNG', 'icon': 'download'},
            {'id': 'svg', 'label': 'Download SVG', 'icon': 'download'},
        ],
    },
    'memberMenu': {
        'triggerLabel': 'Member Actions',
        'items': [
            'Make Owner',
            'Make Admin',
            'Make Member',
            'Make Guest',
            'Remove member',
        ],
    },
    'filterTrigger': {
        'title': 'Filter by channel',
        'label': 'All Channels',
    },
}
(here / 'fixtures/legacy-wave4b.json').write_text(
    json.dumps(FIXTURE, indent=2) + '\n',
)

SURFACES = [
    (
        'quoted-message-skeleton',
        'Quoted message loading card skeleton',
        ('desktop', 'phone'),
        None,
        'packages/web/src/components/message/QuotedMessagePermalinkPreview.tsx',
        'apps/raft_flutter/lib/features/quoted_message_preview.dart',
    ),
    (
        'form-dialog-select',
        'Form dialog choice field on RaftField + RaftSelectField',
        ('desktop', 'phone'),
        None,
        'packages/web/src/components/ui/FormField.tsx + Select',
        'packages/raft_ui/lib/src/form_dialog.dart',
    ),
    (
        'mermaid-download-menu',
        'Mermaid download dropdown menu (open)',
        ('desktop',),
        {
            'selector': '[data-testid="wave4b-mermaid-menu"]',
            'metadataSelector': '[data-testid="wave4b-mermaid-menu"]',
            'androidKey': 'wave4b-mermaid-menu',
            'interactions': [
                {'type': 'wait', 'ms': 300},
                {'type': 'click', 'target': '[data-testid="wave4b-mermaid-trigger"]'},
                {'type': 'wait', 'ms': 300},
            ],
            'androidInteractions': [
                {'type': 'wait', 'ms': 300},
                {'type': 'tap', 'key': 'wave4b-mermaid-trigger', 'mouse': True},
                {'type': 'wait', 'ms': 300},
            ],
        },
        'packages/web/src/components/mermaid/MermaidToolbar.tsx',
        'packages/raft_ui/lib/src/message_body.dart',
    ),
    (
        'member-actions-menu',
        'Member actions dropdown menu (open)',
        ('desktop',),
        {
            'selector': '[data-testid="wave4b-member-menu"]',
            'metadataSelector': '[data-testid="wave4b-member-menu"]',
            'androidKey': 'wave4b-member-menu',
            'interactions': [
                {'type': 'wait', 'ms': 300},
                {'type': 'click', 'target': '[data-testid="wave4b-member-actions-trigger"]'},
                {'type': 'wait', 'ms': 300},
            ],
            'androidInteractions': [
                {'type': 'wait', 'ms': 300},
                {'type': 'tap', 'key': 'wave4b-member-actions-trigger', 'mouse': True},
                {'type': 'wait', 'ms': 300},
            ],
        },
        'packages/web/src/components/member/HumanDetailPanel.tsx (DropdownMenu)',
        'apps/raft_flutter/lib/features/server_views.dart',
    ),
    (
        'filter-menu-trigger',
        'Filter picker trigger button',
        ('desktop',),
        None,
        'packages/web/src/apps/artifacts/ArtifactDashboardToolbar.tsx (PickerTriggerButton)',
        'apps/raft_flutter/lib/features/resource_view.dart',
    ),
]

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)]

cases = []
for surface, label, forms, cap_override, react_hint, dart_hint in SURFACES:
    for form in forms:
        vp = dict(VIEWPORTS[form])
        for theme_id, parity_theme in (
            ('brutal', 'brutal-light'),
            ('elegant-dark', 'elegant-dark'),
        ):
            case_id = f'{PREFIX}{surface}.{form}.{theme_id}'
            if cap_override is None:
                capture = {
                    'selector': f'[data-visual-case="{case_id}"]',
                    'metadataSelector': f'[data-visual-case="{case_id}"]',
                    'crop': 'element',
                    'contract': 'component-bounds',
                    'androidKey': 'wave4b-frame',
                    'interactions': [{'type': 'wait', 'ms': 100}],
                    'androidInteractions': [],
                }
            else:
                capture = {
                    'crop': 'element',
                    'contract': 'component-bounds',
                    **copy.deepcopy(cap_override),
                }
            cases.append({
                'id': case_id,
                'title': f'{label} ({form}, {parity_theme})',
                'captureType': 'component-fixture',
                'suite': 'raft-flutter-extension',
                'surface': f'legacy-wave4b-{surface}',
                'category': 'extension/legacy-wave4b',
                'theme': parity_theme,
                'locale': 'en',
                'viewport': vp,
                'variants': [{
                    'id': 'default',
                    'name': 'Default',
                    'props': {
                        'extKind': 'legacy-wave4b',
                        'surface': surface,
                        'formFactor': form,
                        'parityTheme': parity_theme,
                    },
                }],
                'capture': capture,
                'tolerance': {
                    'pixelRatio': 0.02,
                    'layoutDp': 1,
                    'ignoreAntialiasing': True,
                },
                'reactPathHint': react_hint,
                'androidCaseHint': dart_hint,
                'notes': 'Extension suite (Wave 4B E5/E6 component parity).',
            })

manifest['cases'].extend(cases)
path.write_text(json.dumps(manifest, indent=1) + '\n')
print(f'{len(cases)} legacy-wave4b cases appended ({len(manifest["cases"])} total)')
