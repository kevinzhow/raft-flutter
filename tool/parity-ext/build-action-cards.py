#!/usr/bin/env python3
"""Add the v1.24 action card matrix to the extension manifest."""

import json

from builders import manifest_path

PREFIX = 'components.action-card-v124.'
FIXTURES = {
    'agent-create': [],
    'agent-migrate': [],
    'expired-agent': [
        {'type': 'click', 'target': 'button[aria-label="Show or hide details"]'},
        {'type': 'wait', 'ms': 250},
    ],
    'mcp-connect': [],
    'question-single': [],
    'question-single-other': [
        {'type': 'click', 'target': '[data-action-card-form-field] label:has-text("Other")'},
    ],
    'question-single-undo': [
        {'type': 'click', 'target': '[data-action-card-form-field] label:has-text("Tuesday")'},
    ],
    'question-multi': [],
    'question-confirm': [],
    'question-answered': [],
    'channel-done': [],
}

path = manifest_path()
manifest = json.loads(path.read_text())
cases = [case for case in manifest['cases'] if not case['id'].startswith(PREFIX)]
for platform, width in [('desktop', 640), ('phone', 390)]:
    for name, steps in FIXTURES.items():
        for suffix, theme in [('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')]:
            case_id = f'{PREFIX}{name}.{platform}.{suffix}'
            selector = f'[data-visual-case="{case_id}"]'
            cases.append({
                'id': case_id,
                'title': f'In-message {name} ({platform}, {theme})',
                'captureType': 'component-fixture',
                'surface': 'action-card-v124',
                'category': 'extension/action-card-v124',
                'suite': 'raft-flutter-extension',
                'viewport': {'width': width, 'height': 600, 'density': 2},
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': {
                    'platform': platform,
                    'parityTheme': theme,
                }}],
                'capture': {
                    'selector': selector, 'crop': 'element', 'contract': 'component-bounds',
                    'interactions': [
                        {**step, 'target': f"{selector} {step['target']}"}
                        if 'target' in step else step for step in steps
                    ],
                },
                'reactPathHint': 'packages/web/src/components/actions/ActionCard.tsx',
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/action_card.dart '{case_id}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
manifest['cases'] = cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} cases, including {4 * len(FIXTURES)} action card cases')
