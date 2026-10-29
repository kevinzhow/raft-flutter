#!/usr/bin/env python3
"""Append the composer attachment cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Run after build-cases.py, build-channel-header.py,
build-announcements.py and build-search-overlay-cases.py; idempotent: every
`components.composerattachments.*` case is replaced, all other cases are kept.

Derivation (raft-source packages/web/src):
  components/message/MessageInput.tsx  SortableAttachment, <ComposerAttachments>,
                                       failed-upload rows, limit Banner, drop
                                       overlay, addFiles / handleDrop
  raft-ui composerAttachment recipe    (chips, overlays, progress, remove)
Ids: components.composerattachments.<platform>.<kind>.<theme>. The state of each
kind (files, route set, progress, drag, hover) is in
fixtures/composer-attachments.json `kinds`; both providers read it.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
# Desktop: the composer in the chat column (a 760px column of the 1280 window).
# Mobile: the 390 phone viewport; `touch` makes the browser report
# `(hover: none)` like a phone, where the remove badge is always visible.
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3, 'touch': True}
WIDTH = {'desktop': 760, 'mobile': 390}
DESKTOP_KINDS = [
    'one-image', 'images', 'file', 'file-long', 'mixed', 'checking', 'uploading',
    'uploading-progress', 'uploading-finishing', 'failed', 'failed-quota',
    'over-size', 'over-count', 'empty-file', 'drag-over', 'hover-remove', 'thread-image',
]
MOBILE_KINDS = [
    'one-image', 'images', 'file', 'mixed', 'checking', 'uploading',
    'uploading-progress', 'failed', 'failed-quota', 'over-size', 'over-count', 'thread-image',
]
HINT = 'packages/web/src/components/message/MessageInput.tsx (+ raft-ui composerAttachment recipe)'

KINDS = json.loads((here / 'fixtures/composer-attachments.json').read_text())['kinds']
cases = []
for platform, viewport, kinds in (('desktop', DESKTOP, DESKTOP_KINDS), ('mobile', MOBILE, MOBILE_KINDS)):
    for kind in kinds:
        for suffix, theme in THEMES.items():
            cid = f'components.composerattachments.{platform}.{kind}.{suffix}'
            props = {'extCase': f'{platform}.{kind}', 'extKind': 'composerattachments', 'parityTheme': theme,
                     'platform': platform, 'kind': kind, 'width': str(WIDTH[platform])}
            if KINDS[kind].get('routeSet'):
                # tool/parity-ext/run answers the fixture `routeSets[props.routeSet]`.
                props['routeSet'] = KINDS[kind]['routeSet']
            capture = {
                'selector': '[data-visual-case]',
                'crop': 'element',
                'contract': 'component-bounds',
                'androidKey': 'composer-attachments-case',
            }
            if kind == 'hover-remove':
                capture['interactions'] = [{'type': 'hover', 'target': '[data-slot="composer-attachment"]'}]
                capture['androidInteractions'] = [{'type': 'hover', 'key': 'composer-attachment-0'}]
            cases.append({
                'id': cid,
                'title': f'Composer attachments {platform} {kind} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'composer-attachments',
                'category': 'extension/composer-attachments',
                'suite': 'raft-flutter-extension',
                'viewport': viewport,
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': capture,
                'reactPathHint': HINT,
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_composer_attachments.dart '{platform}.{kind}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.composerattachments.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} composer attachment cases appended ({len(manifest["cases"])} total)')
