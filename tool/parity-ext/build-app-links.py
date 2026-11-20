#!/usr/bin/env python3
"""Mount app-link cards and authorization states in both visual providers."""

import json

from builders import manifest_path

AREA = 'components.app-links.'
SCENARIOS = {
    'block-chip': '[data-app-link-block]',
    'consent': '[data-app-link-preview-prompt]',
    'consent-failed': '[data-link-preview-prompt-error]',
    'loading': '[data-app-link-preview-pending]',
}
path = manifest_path()
manifest = json.loads(path.read_text())
cases = [case for case in manifest['cases'] if not case['id'].startswith(AREA)]
for platform, viewport, width in [('desktop', 800, 640), ('phone', 390, 390)]:
    for name, ready in SCENARIOS.items():
        for suffix, theme in [('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')]:
            case_id = f'{AREA}{name}.{platform}.{suffix}'
            cases.append({
                'id': case_id,
                'title': f'App links {name} ({platform}, {theme})',
                'captureType': 'component-fixture',
                'surface': 'app-links',
                'category': 'extension/app-links',
                'suite': 'raft-flutter-extension',
                'viewport': {'width': viewport, 'height': 320, 'density': 1},
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': {
                    'platform': platform, 'frameWidth': width, 'parityTheme': theme,
                }}],
                'capture': {
                    'selector': f'[data-visual-case="{case_id}"]:has({ready})',
                    'crop': 'element',
                    'contract': 'component-bounds',
                    'androidKey': 'app-link-parity-frame',
                },
                'reactPathHint': 'packages/web/src/components/message/AppLinkBlockCard.tsx',
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_app_links.dart '{case_id}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
manifest['cases'] = cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} cases, including {4 * len(SCENARIOS)} app-link cases')
