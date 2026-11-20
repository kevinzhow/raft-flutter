#!/usr/bin/env python3
"""Mount the Drafts route in the real desktop and phone workspaces."""
import json
from builders import manifest_path

PREFIX = 'components.pages.drafts-v124.'
THEMES = {'brutal': 'brutal-light', 'elegant-dark': 'elegant-dark'}
VIEWPORTS = {
    'desktop': {'width': 1280, 'height': 880, 'density': 1},
    'phone': {'width': 390, 'height': 844, 'density': 1},
}

cases = []
for platform, viewport in VIEWPORTS.items():
    for state in ('empty', 'private'):
        key = f'{platform}.{state}'
        for suffix, theme in THEMES.items():
            cid = f'{PREFIX}{key}.{suffix}'
            content = '[data-draft-row]' if state == 'private' else '[data-testid="drafts-list-scroller"]'
            cases.append({
                'id': cid,
                'title': f'Drafts {platform} {state} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'drafts-v124',
                'category': 'extension/drafts-v124',
                'suite': 'raft-flutter-extension',
                'viewport': viewport,
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': {
                    'extCase': key, 'extKind': 'drafts-v124', 'extFixture': 'drafts-v124',
                    'platform': 'mobile' if platform == 'phone' else 'desktop',
                    'state': state, 'parityTheme': theme,
                }}],
                'capture': {'selector': f'[data-visual-case="{cid}"]:has({content})',
                            'crop': 'element', 'contract': 'component-bounds'},
                'reactPathHint': 'packages/web/src/components/drafts/DraftsPanel.tsx',
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_drafts.dart '{key}'",
            })

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [case for case in manifest['cases'] if not case['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} Drafts cases appended')
