#!/usr/bin/env python3
"""Append the media viewer (lightbox) video cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Ids: components.attachment.viewer.<state>.<theme>. Derivation (raft-source packages/web/src):
  components/message/attachmentPreviewSurfaces.tsx  VideoAttachmentPreviewModal / VideoPreviewBody
  components/message/MediaPreviewHost.tsx           (the host that opens it)
The capture is the 1280x800 viewer (header + black stage + the browser's native video controls).
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
VIEWPORT = {'width': 1280, 'height': 800, 'density': 1}

cases = []
for state, title in [('video-paused', 'Media viewer, video paused on its first frame')]:
    for suffix, theme in THEMES.items():
        cid = f'components.attachment.viewer.{state}.{suffix}'
        props = {'extCase': state, 'extKind': 'video-viewer', 'parityTheme': theme, 'platform': 'desktop'}
        cases.append({
            'id': cid,
            'title': f'{title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'attachment-viewer',
            'category': 'extension/attachment-viewer',
            'suite': 'raft-flutter-extension',
            'viewport': VIEWPORT,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': {'selector': f"[data-visual-case='{cid}']", 'crop': 'element', 'contract': 'component-bounds',
                        'interactions': [{'type': 'wait', 'ms': 1500}], 'androidInteractions': []},
            'reactPathHint': 'packages/web/src/components/message/attachmentPreviewSurfaces.tsx VideoPreviewBody',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_attachment_viewer.dart '{state}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.attachment.viewer.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} media viewer cases appended ({len(manifest["cases"])} total)')
