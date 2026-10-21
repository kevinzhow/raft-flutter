#!/usr/bin/env python3
"""Append the account-level announcement modal cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Run after build-cases.py (which regenerates the Computers cases) and
build-live-activity.py; idempotent: every `components.announcements.*` case
is replaced, all other cases are kept.

Derivation (raft-source v1.21.12 packages/web/src, raft-ui 0.5.52):
  components/AnnouncementModal.tsx   (AnnouncementDialog layer=1: label, title,
                                      picture, pages[0] body, Got it / CTA)
  raft-ui/wip announcement-dialog    (slots) + Dialog (overlay, content)
  store/announcementStore.ts         (pending[0] is presented)
Ids: components.announcements.<platform>.<kind>.<theme>. Prop `ann` is a key
of fixtures/announcements.json.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
# kind: (announcement, whole viewport?)
KINDS = {
    'single': ('single', False),
    'cta': ('cta', False),
    'cta-long': ('cta-long', False),
    'image': ('image', False),
    'image-only': ('image-only', False),
    'multi': ('multi', False),
    'rich': ('rich', False),
    'long': ('long', False),
    'long-title': ('long-title', False),
    'overlay': ('image', True),
}
PLATFORMS = {
    'desktop': (DESKTOP, list(KINDS)),
    'mobile': (MOBILE, ['single', 'cta', 'cta-long', 'image', 'rich', 'long', 'overlay']),
}
HINT = 'packages/web/src/components/AnnouncementModal.tsx (+ raft-ui/wip AnnouncementDialog)'

cases = []
for platform, (viewport, kinds) in PLATFORMS.items():
    for kind in kinds:
        ann, whole = KINDS[kind]
        for suffix, theme in THEMES.items():
            cid = f'components.announcements.{platform}.{kind}.{suffix}'
            props = {'extCase': f'{platform}.{kind}', 'extKind': 'announcement', 'parityTheme': theme,
                     'platform': platform, 'ann': ann}
            capture = {
                'selector': 'body' if whole else '[data-testid="announcement-modal"]',
                'crop': 'viewport' if whole else 'element',
                'contract': 'viewport-with-portal' if whole else 'component-bounds',
                'interactions': [],
                'androidInteractions': [],
            }
            if not whole:
                capture['androidKey'] = 'announcement-modal'
            cases.append({
                'id': cid,
                'title': f'Announcement modal {platform} {kind} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'announcements',
                'category': 'extension/announcements',
                'suite': 'raft-flutter-extension',
                'viewport': viewport,
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
                'capture': capture,
                'reactPathHint': HINT,
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_announcements.dart '{platform}.{kind}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.announcements.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} announcement cases appended ({len(manifest["cases"])} total)')
